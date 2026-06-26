-- ============================================================
-- 018: Security Hardening + Bug Fixes
-- • SET search_path = public auf allen SECURITY DEFINER-Funktionen
--   (verhindert Schema-Injection-Angriffe)
-- • confirm_kill: FOR UPDATE → verhindert Doppel-Bestätigung (Race Condition)
-- • spend_credits: FOR UPDATE → verhindert TOCTOU bei parallelen Requests
-- • _process_kniffel_lootboxes: Tester von Tages-Lootbox ausgeschlossen
-- • Indizes für Assignment- und Game-Player-Queries
-- ============================================================

-- ── Indizes ───────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_assignments_killer_active
  ON public.assignments (game_id, killer_id)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_assignments_target_active
  ON public.assignments (game_id, target_id)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_game_players_alive
  ON public.game_players (game_id)
  WHERE is_alive = true;

-- ── handle_new_user ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

-- ── is_game_admin ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_game_admin(gid uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = gid AND player_id = auth.uid() AND is_admin = true
  );
$$;

-- ── get_my_game_ids ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_my_game_ids()
RETURNS SETOF uuid LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT game_id FROM public.game_players WHERE player_id = auth.uid();
$$;

-- ── join_game_by_code ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.join_game_by_code(p_code text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game    public.games%ROWTYPE;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Nicht eingeloggt';
  END IF;

  SELECT * INTO v_game
  FROM public.games
  WHERE code = UPPER(p_code) AND status = 'lobby'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Spiel nicht gefunden oder bereits gestartet';
  END IF;

  INSERT INTO public.game_players (game_id, player_id, is_admin, is_ready)
  VALUES (v_game.id, v_user_id, false, false)
  ON CONFLICT (game_id, player_id) DO NOTHING;

  RETURN row_to_json(v_game);
END;
$$;

-- ── start_game ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.start_game(game_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_tasks_per_player  int;
  v_task_ids          uuid[];
  v_player_ids        uuid[];
  v_n_players         int;
  v_n_tasks           int;
  v_slot              int := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE((settings->>'initial_tasks_per_player')::int, 1)
  INTO v_tasks_per_player
  FROM public.games WHERE id = game_id_param;

  -- Builtin tasks + Admin-eigene Tasks, abzüglich manuell deaktivierter
  -- Sortierung: Schwierigkeit 1+2 vor 3, innerhalb zufällig
  SELECT ARRAY(
    SELECT t.id FROM public.tasks t
    WHERE (
      t.is_builtin = true
      OR t.created_by IN (
        SELECT player_id FROM public.game_players
        WHERE game_id = game_id_param AND is_admin = true
      )
    )
    AND t.id NOT IN (
      SELECT task_id FROM public.game_task_disabled WHERE game_id = game_id_param
    )
    ORDER BY CASE WHEN t.difficulty <= 2 THEN 0 ELSE 1 END, random()
  ) INTO v_task_ids;

  SELECT ARRAY(
    SELECT player_id FROM public.game_players
    WHERE game_id = game_id_param AND is_alive = true
    ORDER BY random()
  ) INTO v_player_ids;

  v_n_players := COALESCE(array_length(v_player_ids, 1), 0);
  v_n_tasks   := COALESCE(array_length(v_task_ids, 1), 0);

  IF v_n_players < 2 THEN RAISE EXCEPTION 'Need at least 2 players'; END IF;
  IF v_n_tasks = 0   THEN RAISE EXCEPTION 'No tasks available'; END IF;

  FOR round IN 1..v_tasks_per_player LOOP
    FOR i IN 1..v_n_players LOOP
      INSERT INTO public.player_tasks (game_id, player_id, task_id)
      VALUES (game_id_param, v_player_ids[i], v_task_ids[(v_slot % v_n_tasks) + 1]);
      v_slot := v_slot + 1;
    END LOOP;
  END LOOP;

  -- Assignment-Ring: Spieler 1 → 2 → 3 → … → N → 1
  FOR i IN 1..v_n_players LOOP
    INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
    VALUES (game_id_param, v_player_ids[i], v_player_ids[(i % v_n_players) + 1], true);
  END LOOP;

  UPDATE public.games SET status = 'active', started_at = now() WHERE id = game_id_param;
END;
$$;

-- ── reset_game_to_lobby ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.reset_game_to_lobby(game_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  DELETE FROM public.assignments  WHERE game_id = game_id_param;
  DELETE FROM public.player_tasks WHERE game_id = game_id_param;
  DELETE FROM public.eliminations WHERE game_id = game_id_param;

  UPDATE public.game_players
  SET is_alive = true, kills = 0, is_ready = false
  WHERE game_id = game_id_param;

  UPDATE public.games
  SET status = 'lobby', started_at = null
  WHERE id = game_id_param;
END;
$$;

-- ── confirm_kill ──────────────────────────────────────────────
-- FOR UPDATE auf eliminations → verhindert simultane Doppel-Bestätigung

CREATE OR REPLACE FUNCTION public.confirm_kill(elimination_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  elim          record;
  killer_assign record;
  victim_assign record;
  alive_count   int;
  v_winner_id   uuid;
BEGIN
  SELECT * INTO elim
  FROM public.eliminations
  WHERE id = elimination_id_param
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Elimination not found'; END IF;
  IF elim.status != 'pending' THEN RAISE EXCEPTION 'Elimination already processed'; END IF;

  IF elim.victim_id != auth.uid() THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.game_players
      WHERE game_id = elim.game_id AND player_id = auth.uid() AND is_admin = true
    ) THEN
      RAISE EXCEPTION 'Not authorized to confirm';
    END IF;
  END IF;

  SELECT * INTO killer_assign FROM public.assignments
  WHERE game_id = elim.game_id AND killer_id = elim.killer_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO victim_assign FROM public.assignments
  WHERE game_id = elim.game_id AND killer_id = elim.victim_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  UPDATE public.assignments SET is_active = false WHERE id = killer_assign.id;

  IF victim_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = victim_assign.id;
    IF victim_assign.target_id != elim.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id)
      VALUES (elim.game_id, elim.killer_id, victim_assign.target_id);
    END IF;
  END IF;

  IF elim.task_id IS NOT NULL THEN
    UPDATE public.player_tasks
    SET is_used = true
    WHERE game_id = elim.game_id AND player_id = elim.killer_id AND task_id = elim.task_id;
  END IF;

  UPDATE public.player_tasks
  SET player_id = elim.killer_id, acquired_from = elim.victim_id
  WHERE game_id = elim.game_id AND player_id = elim.victim_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = elim.game_id AND player_id = elim.victim_id;

  UPDATE public.game_players
  SET kills = kills + 1
  WHERE game_id = elim.game_id AND player_id = elim.killer_id;

  UPDATE public.eliminations
  SET status = 'confirmed', confirmed_by = auth.uid(), confirmed_at = now()
  WHERE id = elimination_id_param;

  UPDATE public.profiles SET total_kills = total_kills + 1 WHERE id = elim.killer_id;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players WHERE game_id = elim.game_id AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id FROM public.game_players
    WHERE game_id = elim.game_id AND is_alive = true LIMIT 1;

    UPDATE public.games
    SET status = 'finished', ended_at = now(), winner_id = v_winner_id
    WHERE id = elim.game_id;

    UPDATE public.profiles
    SET total_wins = total_wins + 1, total_games = total_games + 1
    WHERE id = v_winner_id;

    UPDATE public.profiles
    SET total_games = total_games + 1
    WHERE id IN (
      SELECT player_id FROM public.game_players
      WHERE game_id = elim.game_id AND player_id != v_winner_id
    );

    PERFORM public._award_morder_lootbox(elim.game_id, v_winner_id);

    RETURN jsonb_build_object('game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('game_over', false);
END;
$$;

-- ── leave_game ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.leave_game(game_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id       uuid;
  v_game_status   text;
  v_is_admin      boolean;
  v_new_admin     uuid;
  v_my_assign     record;
  v_hunter_assign record;
  alive_count     int;
  v_winner_id     uuid;
BEGIN
  v_user_id := auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not in this game';
  END IF;

  SELECT status INTO v_game_status FROM public.games WHERE id = game_id_param;
  SELECT is_admin INTO v_is_admin FROM public.game_players
  WHERE game_id = game_id_param AND player_id = v_user_id;

  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players WHERE game_id = game_id_param AND player_id = v_user_id;

    IF v_is_admin THEN
      SELECT player_id INTO v_new_admin
      FROM public.game_players WHERE game_id = game_id_param LIMIT 1;
      IF v_new_admin IS NOT NULL THEN
        UPDATE public.game_players SET is_admin = true
        WHERE game_id = game_id_param AND player_id = v_new_admin;
      END IF;
    END IF;

    RETURN jsonb_build_object('left', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN RAISE EXCEPTION 'Game is not active'; END IF;

  SELECT * INTO v_my_assign FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO v_hunter_assign FROM public.assignments
  WHERE game_id = game_id_param AND target_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF v_my_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_my_assign.id;
  END IF;

  IF v_hunter_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_hunter_assign.id;
    IF v_my_assign.id IS NOT NULL AND v_my_assign.target_id != v_hunter_assign.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
      VALUES (game_id_param, v_hunter_assign.killer_id, v_my_assign.target_id, true);
    END IF;
  END IF;

  DELETE FROM public.player_tasks WHERE game_id = game_id_param AND player_id = v_user_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = game_id_param AND player_id = v_user_id;

  IF v_is_admin THEN
    SELECT player_id INTO v_new_admin FROM public.game_players
    WHERE game_id = game_id_param AND player_id != v_user_id AND is_alive = true LIMIT 1;
    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id FROM public.game_players
    WHERE game_id = game_id_param AND is_alive = true LIMIT 1;

    UPDATE public.games
    SET status = 'finished', ended_at = now(), winner_id = v_winner_id
    WHERE id = game_id_param;

    IF v_winner_id IS NOT NULL THEN
      UPDATE public.profiles
      SET total_wins = total_wins + 1, total_games = total_games + 1
      WHERE id = v_winner_id;
    END IF;

    UPDATE public.profiles
    SET total_games = total_games + 1
    WHERE id IN (
      SELECT player_id FROM public.game_players
      WHERE game_id = game_id_param AND player_id != v_winner_id
    );

    IF v_winner_id IS NOT NULL THEN
      PERFORM public._award_morder_lootbox(game_id_param, v_winner_id);
    END IF;

    RETURN jsonb_build_object('left', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('left', true, 'game_over', false);
END;
$$;

-- ── admin_kick_player ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_kick_player(
  game_id_param    uuid,
  target_player_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game_status   text;
  v_target_admin  boolean;
  v_new_admin     uuid;
  v_my_assign     record;
  v_hunter_assign record;
  alive_count     int;
  v_winner_id     uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF target_player_id = auth.uid() THEN
    RAISE EXCEPTION 'Use leave_game to leave the game yourself';
  END IF;

  SELECT status INTO v_game_status FROM public.games WHERE id = game_id_param;
  SELECT is_admin INTO v_target_admin FROM public.game_players
  WHERE game_id = game_id_param AND player_id = target_player_id;

  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players WHERE game_id = game_id_param AND player_id = target_player_id;
    RETURN jsonb_build_object('kicked', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN RAISE EXCEPTION 'Game is not active or in lobby'; END IF;

  SELECT * INTO v_my_assign FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = target_player_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO v_hunter_assign FROM public.assignments
  WHERE game_id = game_id_param AND target_id = target_player_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF v_my_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_my_assign.id;
  END IF;

  IF v_hunter_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_hunter_assign.id;
    IF v_my_assign.id IS NOT NULL AND v_my_assign.target_id != v_hunter_assign.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
      VALUES (game_id_param, v_hunter_assign.killer_id, v_my_assign.target_id, true);
    END IF;
  END IF;

  DELETE FROM public.player_tasks WHERE game_id = game_id_param AND player_id = target_player_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = game_id_param AND player_id = target_player_id;

  IF v_target_admin THEN
    SELECT player_id INTO v_new_admin FROM public.game_players
    WHERE game_id = game_id_param AND player_id != target_player_id AND is_alive = true LIMIT 1;
    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id FROM public.game_players
    WHERE game_id = game_id_param AND is_alive = true LIMIT 1;

    UPDATE public.games
    SET status = 'finished', ended_at = now(), winner_id = v_winner_id
    WHERE id = game_id_param;

    IF v_winner_id IS NOT NULL THEN
      UPDATE public.profiles
      SET total_wins = total_wins + 1, total_games = total_games + 1
      WHERE id = v_winner_id;
    END IF;

    UPDATE public.profiles
    SET total_games = total_games + 1
    WHERE id IN (
      SELECT player_id FROM public.game_players
      WHERE game_id = game_id_param AND player_id != v_winner_id
    );

    IF v_winner_id IS NOT NULL THEN
      PERFORM public._award_morder_lootbox(game_id_param, v_winner_id);
    END IF;

    RETURN jsonb_build_object('kicked', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('kicked', true, 'game_over', false);
END;
$$;

-- ── report_kill ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.report_kill(
  game_id_param   uuid,
  victim_id_param uuid,
  task_id_param   uuid DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id              uuid;
  v_tasks_are_single_use boolean;
BEGIN
  v_user_id := auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.assignments
    WHERE game_id = game_id_param
      AND killer_id = v_user_id
      AND target_id = victim_id_param
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Not your assigned target';
  END IF;

  IF task_id_param IS NOT NULL THEN
    SELECT COALESCE((settings->>'tasks_are_single_use')::boolean, false)
    INTO v_tasks_are_single_use
    FROM public.games WHERE id = game_id_param;

    IF v_tasks_are_single_use THEN
      IF EXISTS (
        SELECT 1 FROM public.player_tasks
        WHERE game_id = game_id_param AND player_id = v_user_id
          AND task_id = task_id_param AND is_used = true
      ) THEN
        RAISE EXCEPTION 'Task already used';
      END IF;
    END IF;
  END IF;

  INSERT INTO public.eliminations (game_id, killer_id, victim_id, task_id, status)
  VALUES (game_id_param, v_user_id, victim_id_param, task_id_param, 'pending');
END;
$$;

-- ── admin_swap_assignments ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_swap_assignments(
  game_id_param uuid,
  player_a_id   uuid,
  player_b_id   uuid
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  target_a    uuid;
  target_b    uuid;
  assign_a_id uuid;
  assign_b_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT id, target_id INTO assign_a_id, target_a
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = player_a_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT id, target_id INTO assign_b_id, target_b
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = player_b_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF assign_a_id IS NULL OR assign_b_id IS NULL THEN
    RAISE EXCEPTION 'One or both players have no active assignment';
  END IF;

  UPDATE public.assignments SET target_id = target_b WHERE id = assign_a_id;
  UPDATE public.assignments SET target_id = target_a WHERE id = assign_b_id;
END;
$$;

-- ── get_broken_assignments ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_broken_assignments(game_id_param uuid)
RETURNS TABLE(killer_id uuid, display_name text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT a.killer_id, p.username::text AS display_name
  FROM public.assignments a
  JOIN public.profiles p ON p.id = a.killer_id
  WHERE a.game_id = game_id_param AND a.is_active = true AND a.target_id = a.killer_id;
END;
$$;

-- ── _ensure_loot_rows ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._ensure_loot_rows(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_credits (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_active_designs (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
END;
$$;

-- ── get_loot_state ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_loot_state()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  PERFORM public._ensure_loot_rows(v_user_id);

  RETURN jsonb_build_object(
    'lootboxes', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id',           id,
        'source',       source,
        'status',       CASE WHEN status = 'pending' AND available_at <= now() THEN 'ready' ELSE status END,
        'available_at', available_at,
        'created_at',   created_at
      ) ORDER BY created_at)
      FROM public.user_lootboxes
      WHERE user_id = v_user_id AND status != 'opened'
    ), '[]'::jsonb),
    'inventory', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'item_id',     ui.item_id,
        'design_key',  li.design_key,
        'item_type',   li.item_type,
        'name',        li.name,
        'rarity',      li.rarity,
        'unlocked_at', ui.unlocked_at
      ) ORDER BY li.item_type, li.sort_order)
      FROM public.user_inventory ui
      JOIN public.loot_items li ON li.id = ui.item_id
      WHERE ui.user_id = v_user_id
    ), '[]'::jsonb),
    'credits', COALESCE((
      SELECT jsonb_build_object('bronze', bronze_credits, 'silver', silver_credits, 'gold', gold_credits)
      FROM public.user_credits WHERE user_id = v_user_id
    ), jsonb_build_object('bronze', 0, 'silver', 0, 'gold', 0)),
    'active_card_key', (
      SELECT li.design_key FROM public.user_active_designs uad
      JOIN public.loot_items li ON li.id = uad.active_card_id
      WHERE uad.user_id = v_user_id
    ),
    'active_dice_key', (
      SELECT li.design_key FROM public.user_active_designs uad
      JOIN public.loot_items li ON li.id = uad.active_dice_id
      WHERE uad.user_id = v_user_id
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_loot_state TO authenticated;

-- ── open_lootbox ──────────────────────────────────────────────
-- Diamond-Tier (013): 0.5 %; bei bereits besitzendem Diamant-Item → 1 Gold-Credit

CREATE OR REPLACE FUNCTION public.open_lootbox(p_lootbox_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id    uuid := auth.uid();
  v_box        public.user_lootboxes;
  v_roll       float;
  v_rarity     text;
  v_credit_rar text;
  v_item       public.loot_items;
BEGIN
  SELECT * INTO v_box
  FROM public.user_lootboxes
  WHERE id = p_lootbox_id AND user_id = v_user_id AND status != 'opened'
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Lootbox nicht gefunden oder bereits geöffnet'; END IF;
  IF v_box.available_at > now() THEN RAISE EXCEPTION 'Lootbox noch nicht verfügbar'; END IF;

  PERFORM public._ensure_loot_rows(v_user_id);

  v_roll   := random();
  v_rarity := CASE
    WHEN v_roll < 0.700 THEN 'bronze'
    WHEN v_roll < 0.900 THEN 'silver'
    WHEN v_roll < 0.995 THEN 'gold'
    ELSE                      'diamond'
  END;

  SELECT li.* INTO v_item
  FROM public.loot_items li
  WHERE li.rarity = v_rarity
    AND NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      WHERE ui.user_id = v_user_id AND ui.item_id = li.id
    )
  ORDER BY random()
  LIMIT 1;

  UPDATE public.user_lootboxes SET status = 'opened', opened_at = now() WHERE id = p_lootbox_id;

  IF v_item.id IS NULL THEN
    -- Diamant hat keine Credits → Trostpreis: 1 Gold-Credit
    v_credit_rar := CASE WHEN v_rarity = 'diamond' THEN 'gold' ELSE v_rarity END;
    IF v_credit_rar = 'bronze' THEN
      UPDATE public.user_credits SET bronze_credits = bronze_credits + 1 WHERE user_id = v_user_id;
    ELSIF v_credit_rar = 'silver' THEN
      UPDATE public.user_credits SET silver_credits = silver_credits + 1 WHERE user_id = v_user_id;
    ELSE
      UPDATE public.user_credits SET gold_credits = gold_credits + 1 WHERE user_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('type', 'credit', 'rarity', v_credit_rar);
  ELSE
    INSERT INTO public.user_inventory (user_id, item_id) VALUES (v_user_id, v_item.id);
    RETURN jsonb_build_object(
      'type', 'item', 'rarity', v_rarity,
      'item', jsonb_build_object(
        'item_id', v_item.id, 'design_key', v_item.design_key,
        'item_type', v_item.item_type, 'name', v_item.name, 'rarity', v_item.rarity
      )
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.open_lootbox TO authenticated;

-- ── trade_credits ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trade_credits(p_rarity text, p_direction text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_c       public.user_credits;
  v_new     public.user_credits;
BEGIN
  SELECT * INTO v_c FROM public.user_credits WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Kein Credits-Eintrag'; END IF;

  IF p_direction = 'up' THEN
    IF p_rarity = 'bronze' THEN
      IF v_c.bronze_credits < 2 THEN RAISE EXCEPTION 'Nicht genug Bronze-Credits'; END IF;
      UPDATE public.user_credits SET bronze_credits = bronze_credits - 2, silver_credits = silver_credits + 1
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSIF p_rarity = 'silver' THEN
      IF v_c.silver_credits < 2 THEN RAISE EXCEPTION 'Nicht genug Silber-Credits'; END IF;
      UPDATE public.user_credits SET silver_credits = silver_credits - 2, gold_credits = gold_credits + 1
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSE
      RAISE EXCEPTION 'Gold kann nicht aufgewertet werden';
    END IF;
  ELSIF p_direction = 'down' THEN
    IF p_rarity = 'gold' THEN
      IF v_c.gold_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Gold-Credits'; END IF;
      UPDATE public.user_credits SET gold_credits = gold_credits - 1, silver_credits = silver_credits + 2
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSIF p_rarity = 'silver' THEN
      IF v_c.silver_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Silber-Credits'; END IF;
      UPDATE public.user_credits SET silver_credits = silver_credits - 1, bronze_credits = bronze_credits + 2
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSE
      RAISE EXCEPTION 'Bronze kann nicht abgewertet werden';
    END IF;
  ELSE
    RAISE EXCEPTION 'Ungültige Richtung (up/down erwartet)';
  END IF;

  RETURN jsonb_build_object('bronze', v_new.bronze_credits, 'silver', v_new.silver_credits, 'gold', v_new.gold_credits);
END;
$$;
GRANT EXECUTE ON FUNCTION public.trade_credits TO authenticated;

-- ── spend_credits ─────────────────────────────────────────────
-- FOR UPDATE verhindert parallele Doppel-Ausgaben (TOCTOU-Fix)

CREATE OR REPLACE FUNCTION public.spend_credits(p_rarity text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_c       public.user_credits;
  v_item    public.loot_items;
BEGIN
  PERFORM public._ensure_loot_rows(v_user_id);

  SELECT * INTO v_c FROM public.user_credits WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Kein Credits-Eintrag'; END IF;

  IF p_rarity = 'bronze' THEN
    IF v_c.bronze_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Bronze-Credits'; END IF;
  ELSIF p_rarity = 'silver' THEN
    IF v_c.silver_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Silber-Credits'; END IF;
  ELSIF p_rarity = 'gold' THEN
    IF v_c.gold_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Gold-Credits'; END IF;
  ELSE
    RAISE EXCEPTION 'Ungültige Seltenheit';
  END IF;

  SELECT li.* INTO v_item
  FROM public.loot_items li
  WHERE li.rarity = p_rarity
    AND NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      WHERE ui.user_id = v_user_id AND ui.item_id = li.id
    )
  ORDER BY random()
  LIMIT 1;

  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'Alle Items dieser Seltenheit bereits freigeschaltet';
  END IF;

  IF p_rarity = 'bronze' THEN
    UPDATE public.user_credits SET bronze_credits = bronze_credits - 1 WHERE user_id = v_user_id;
  ELSIF p_rarity = 'silver' THEN
    UPDATE public.user_credits SET silver_credits = silver_credits - 1 WHERE user_id = v_user_id;
  ELSE
    UPDATE public.user_credits SET gold_credits = gold_credits - 1 WHERE user_id = v_user_id;
  END IF;

  INSERT INTO public.user_inventory (user_id, item_id) VALUES (v_user_id, v_item.id);

  RETURN jsonb_build_object(
    'item', jsonb_build_object(
      'item_id', v_item.id, 'design_key', v_item.design_key,
      'item_type', v_item.item_type, 'name', v_item.name, 'rarity', v_item.rarity
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.spend_credits TO authenticated;

-- ── set_active_design ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_active_design(p_item_id uuid, p_type text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF p_item_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      JOIN public.loot_items li ON li.id = ui.item_id
      WHERE ui.user_id = v_user_id AND ui.item_id = p_item_id AND li.item_type = p_type
    ) THEN
      RAISE EXCEPTION 'Item nicht im Inventar oder falscher Typ';
    END IF;
  END IF;

  INSERT INTO public.user_active_designs (user_id, active_card_id, active_dice_id)
  VALUES (
    v_user_id,
    CASE WHEN p_type = 'card' THEN p_item_id ELSE NULL END,
    CASE WHEN p_type = 'dice' THEN p_item_id ELSE NULL END
  )
  ON CONFLICT (user_id) DO UPDATE SET
    active_card_id = CASE WHEN p_type = 'card' THEN p_item_id ELSE public.user_active_designs.active_card_id END,
    active_dice_id = CASE WHEN p_type = 'dice' THEN p_item_id ELSE public.user_active_designs.active_dice_id END;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_active_design TO authenticated;

-- ── _award_morder_lootbox ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public._award_morder_lootbox(p_game_id uuid, p_winner_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.game_players WHERE game_id = p_game_id;
  IF v_count >= 8 THEN
    INSERT INTO public.user_lootboxes (user_id, source, status, available_at)
    VALUES (p_winner_id, 'morder', 'ready', now());
  END IF;
END;
$$;

-- ── _process_kniffel_lootboxes ────────────────────────────────
-- Tester-Filter: Tester kann kein Tages-Lootbox gewinnen

CREATE OR REPLACE FUNCTION public._process_kniffel_lootboxes()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today  date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_rec    record;
  v_winner uuid;
BEGIN
  FOR v_rec IN
    SELECT DISTINCT kg.game_date
    FROM public.kniffel_games kg
    WHERE kg.game_date < v_today
      AND kg.game_date >= v_today - INTERVAL '30 days'
      AND kg.status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM public.kniffel_lootbox_awards kla
        WHERE kla.game_date = kg.game_date
      )
    ORDER BY kg.game_date
  LOOP
    -- Tester explizit ausgeschlossen: verhindert Blockierung des Tages-Slots
    SELECT kg.user_id INTO v_winner
    FROM public.kniffel_games kg
    WHERE kg.game_date = v_rec.game_date
      AND kg.status    = 'completed'
      AND kg.user_id  != public._tester_uuid()
    ORDER BY kg.final_score DESC, kg.submitted_at ASC
    LIMIT 1;

    IF v_winner IS NOT NULL THEN
      INSERT INTO public.kniffel_lootbox_awards (game_date, winner_id)
      VALUES (v_rec.game_date, v_winner)
      ON CONFLICT DO NOTHING;

      INSERT INTO public.user_lootboxes (user_id, source, status, available_at)
      VALUES (v_winner, 'kniffel', 'ready', now());
    END IF;
  END LOOP;
END;
$$;

-- ── kniffel_roll ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_roll(
  p_game_id uuid,
  p_held    boolean[] DEFAULT '{false,false,false,false,false}'
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game           public.kniffel_games;
  v_new_dice       integer[];
  v_i              integer;
  v_held_count     integer;
  v_held_value     integer;
  v_held_all_same  boolean;
  v_nonheld_value  integer;
  v_has_crown      boolean;
BEGIN
  SELECT * INTO v_game
  FROM public.kniffel_games
  WHERE id = p_game_id AND user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Game not found'; END IF;
  IF v_game.status = 'completed' THEN RAISE EXCEPTION 'Game already completed'; END IF;
  IF v_game.roll_count >= 3 AND NOT v_game.crown_bonus_available THEN
    RAISE EXCEPTION 'No rolls remaining this turn';
  END IF;
  IF v_game.game_date != (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'Not todays game';
  END IF;

  v_new_dice := COALESCE(v_game.current_dice, ARRAY[0,0,0,0,0]);
  FOR v_i IN 1..5 LOOP
    IF v_game.roll_count = 0 OR NOT p_held[v_i] THEN
      v_new_dice[v_i] := floor(random() * 6 + 1)::integer;
    END IF;
  END LOOP;

  UPDATE public.kniffel_games
  SET current_dice = v_new_dice, held_dice = p_held, roll_count = roll_count + 1, updated_at = now()
  WHERE id = p_game_id
  RETURNING * INTO v_game;

  -- Grant crown bonus after roll 3: exactly 4 held identical dice,
  -- 5th die differs, user has crown design active, bonus not yet used.
  IF v_game.roll_count = 3 AND NOT v_game.crown_bonus_used AND NOT v_game.crown_bonus_available THEN
    v_held_count := 0;
    FOR v_i IN 1..5 LOOP
      IF p_held[v_i] THEN v_held_count := v_held_count + 1; END IF;
    END LOOP;

    IF v_held_count = 4 THEN
      SELECT EXISTS (
        SELECT 1 FROM public.user_active_designs uad
        JOIN public.loot_items li ON li.id = uad.active_dice_id
        WHERE uad.user_id = auth.uid() AND li.design_key = 'crown'
      ) INTO v_has_crown;

      IF v_has_crown THEN
        v_held_value := NULL;
        FOR v_i IN 1..5 LOOP
          IF p_held[v_i] THEN v_held_value := v_new_dice[v_i]; EXIT; END IF;
        END LOOP;

        v_held_all_same := true;
        FOR v_i IN 1..5 LOOP
          IF p_held[v_i] AND v_new_dice[v_i] != v_held_value THEN v_held_all_same := false; END IF;
        END LOOP;

        v_nonheld_value := NULL;
        FOR v_i IN 1..5 LOOP
          IF NOT p_held[v_i] THEN v_nonheld_value := v_new_dice[v_i]; EXIT; END IF;
        END LOOP;

        IF v_held_all_same AND v_nonheld_value IS NOT NULL AND v_nonheld_value != v_held_value THEN
          UPDATE public.kniffel_games SET crown_bonus_available = true
          WHERE id = p_game_id RETURNING * INTO v_game;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_game.roll_count = 4 THEN
    UPDATE public.kniffel_games SET crown_bonus_available = false, crown_bonus_used = true
    WHERE id = p_game_id RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_roll TO authenticated;

-- ── kniffel_select_category ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_select_category(
  p_game_id  uuid,
  p_category text,
  p_score    integer
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game          public.kniffel_games;
  v_valid_score   integer;
  v_new_scorecard jsonb;
  v_upper_sum     integer;
  v_final_score   integer;
  v_valid_cats    text[] := ARRAY[
    'ones','twos','threes','fours','fives','sixes',
    'three_of_a_kind','four_of_a_kind','full_house',
    'small_straight','large_straight','yahtzee','chance'
  ];
BEGIN
  SELECT * INTO v_game
  FROM public.kniffel_games
  WHERE id = p_game_id AND user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Game not found'; END IF;
  IF v_game.status = 'completed' THEN RAISE EXCEPTION 'Game already completed'; END IF;
  IF v_game.roll_count = 0 THEN RAISE EXCEPTION 'Must roll at least once before selecting a category'; END IF;
  IF v_game.game_date != (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date THEN RAISE EXCEPTION 'Not todays game'; END IF;
  IF NOT (p_category = ANY(v_valid_cats)) THEN RAISE EXCEPTION 'Invalid category: %', p_category; END IF;
  IF v_game.scorecard ? p_category THEN RAISE EXCEPTION 'Category already used: %', p_category; END IF;

  v_valid_score := public.compute_kniffel_category_score(p_category, v_game.current_dice);
  IF p_score <> 0 AND p_score <> v_valid_score THEN
    RAISE EXCEPTION 'Invalid score % for %, expected 0 or %', p_score, p_category, v_valid_score;
  END IF;

  v_new_scorecard := v_game.scorecard || jsonb_build_object(
    p_category, jsonb_build_object('score', p_score, 'dice', to_jsonb(v_game.current_dice))
  );

  IF (SELECT count(*) FROM jsonb_each(v_new_scorecard)) = 13 THEN
    v_upper_sum := (
      SELECT COALESCE(SUM((value->>'score')::integer), 0)
      FROM jsonb_each(v_new_scorecard)
      WHERE key IN ('ones','twos','threes','fours','fives','sixes')
    );
    v_final_score := (
      SELECT COALESCE(SUM((value->>'score')::integer), 0) FROM jsonb_each(v_new_scorecard)
    ) + CASE WHEN v_upper_sum >= 63 THEN 35 ELSE 0 END;

    UPDATE public.kniffel_games
    SET scorecard = v_new_scorecard, status = 'completed', final_score = v_final_score,
        current_dice = NULL, held_dice = NULL, roll_count = 0, current_turn = current_turn + 1,
        crown_bonus_available = false, submitted_at = now(), updated_at = now()
    WHERE id = p_game_id RETURNING * INTO v_game;
  ELSE
    UPDATE public.kniffel_games
    SET scorecard = v_new_scorecard, current_dice = NULL, held_dice = NULL, roll_count = 0,
        current_turn = current_turn + 1, crown_bonus_available = false, updated_at = now()
    WHERE id = p_game_id RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_select_category TO authenticated;

-- ── notify_kniffel_completed ──────────────────────────────────
-- HINWEIS: <project-ref> und <service_role_key> in schema.sql ersetzen!

CREATE OR REPLACE FUNCTION public.notify_kniffel_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status = 'in_progress' THEN
    PERFORM net.http_post(
      url     := 'https://<project-ref>.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
                   'Content-Type',  'application/json',
                   'Authorization', 'Bearer <service_role_key>'
                 ),
      body    := jsonb_build_object(
                   'type',       TG_OP,
                   'table',      TG_TABLE_NAME,
                   'record',     row_to_json(NEW),
                   'old_record', row_to_json(OLD)
                 )
    );
  END IF;
  RETURN NEW;
END;
$$;
