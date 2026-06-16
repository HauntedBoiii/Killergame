-- ============================================================
-- Mörderspiel – Migration 004
-- Fix 1: leave_game + admin_kick_player → Admin-Transfer
-- Fix 2: RLS gp_delete → kein direktes DELETE in aktiven Spielen
-- Fix 3: report_kill → Ziel-Validierung + Einweg-Task-Check
-- Fix 4: confirm_kill → Task als is_used markieren
-- ============================================================

-- ── Fix 2: RLS gp_delete einschränken ────────────────────────
-- Direktes DELETE nur noch für Admins in Lobby.
-- Aktive Spiele: nur über leave_game / admin_kick_player (SECURITY DEFINER)

DROP POLICY IF EXISTS "gp_delete" ON public.game_players;

CREATE POLICY "gp_delete" ON public.game_players FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.game_players admin_check
    JOIN public.games g ON g.id = admin_check.game_id
    WHERE admin_check.game_id = game_players.game_id
      AND admin_check.player_id = auth.uid()
      AND admin_check.is_admin = true
      AND g.status = 'lobby'
  )
);

-- ── Fix 1a: leave_game – Admin-Transfer ──────────────────────

CREATE OR REPLACE FUNCTION public.leave_game(game_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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

  -- ── Lobby: einfaches Entfernen + Admin-Transfer ──
  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = v_user_id;

    IF v_is_admin THEN
      SELECT player_id INTO v_new_admin
      FROM public.game_players
      WHERE game_id = game_id_param
      LIMIT 1;

      IF v_new_admin IS NOT NULL THEN
        UPDATE public.game_players
        SET is_admin = true
        WHERE game_id = game_id_param AND player_id = v_new_admin;
      END IF;
    END IF;

    RETURN jsonb_build_object('left', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN
    RAISE EXCEPTION 'Game is not active';
  END IF;

  -- ── Aktives Spiel: Chain-Repair ──
  SELECT * INTO v_my_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO v_hunter_assign
  FROM public.assignments
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

  -- ── Admin-Transfer ──
  IF v_is_admin THEN
    SELECT player_id INTO v_new_admin
    FROM public.game_players
    WHERE game_id = game_id_param AND player_id != v_user_id AND is_alive = true
    LIMIT 1;

    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

  -- ── Spielende prüfen ──
  SELECT COUNT(*) INTO alive_count
  FROM public.game_players
  WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id
    FROM public.game_players
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

    RETURN jsonb_build_object('left', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('left', true, 'game_over', false);
END;
$$;

-- ── Fix 1b: admin_kick_player ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_kick_player(
  game_id_param    uuid,
  target_player_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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

  -- ── Lobby: direktes Entfernen ──
  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = target_player_id;
    RETURN jsonb_build_object('kicked', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN
    RAISE EXCEPTION 'Game is not active or in lobby';
  END IF;

  -- ── Aktives Spiel: Chain-Repair ──
  SELECT * INTO v_my_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = target_player_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO v_hunter_assign
  FROM public.assignments
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

  -- ── Admin-Transfer falls Gekickter Admin war ──
  IF v_target_admin THEN
    SELECT player_id INTO v_new_admin
    FROM public.game_players
    WHERE game_id = game_id_param AND player_id != target_player_id AND is_alive = true
    LIMIT 1;

    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

  -- ── Spielende prüfen ──
  SELECT COUNT(*) INTO alive_count
  FROM public.game_players
  WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id
    FROM public.game_players
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

    RETURN jsonb_build_object('kicked', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('kicked', true, 'game_over', false);
END;
$$;

-- ── Fix 3: report_kill ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.report_kill(
  game_id_param  uuid,
  victim_id_param uuid,
  task_id_param  uuid DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id               uuid;
  v_tasks_are_single_use  boolean;
BEGIN
  v_user_id := auth.uid();

  -- Opfer muss die aktiv zugewiesene Zielperson sein
  IF NOT EXISTS (
    SELECT 1 FROM public.assignments
    WHERE game_id = game_id_param
      AND killer_id = v_user_id
      AND target_id = victim_id_param
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Not your assigned target';
  END IF;

  -- Einweg-Task-Check
  IF task_id_param IS NOT NULL THEN
    SELECT COALESCE((settings->>'tasks_are_single_use')::boolean, false)
    INTO v_tasks_are_single_use
    FROM public.games WHERE id = game_id_param;

    IF v_tasks_are_single_use THEN
      IF EXISTS (
        SELECT 1 FROM public.player_tasks
        WHERE game_id = game_id_param
          AND player_id = v_user_id
          AND task_id = task_id_param
          AND is_used = true
      ) THEN
        RAISE EXCEPTION 'Task already used';
      END IF;
    END IF;
  END IF;

  INSERT INTO public.eliminations (game_id, killer_id, victim_id, task_id, status)
  VALUES (game_id_param, v_user_id, victim_id_param, task_id_param, 'pending');
END;
$$;

-- ── Fix 4: confirm_kill – Task als is_used markieren ──────────

CREATE OR REPLACE FUNCTION public.confirm_kill(elimination_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  elim          record;
  killer_assign record;
  victim_assign record;
  alive_count   int;
  v_winner_id   uuid;
BEGIN
  SELECT * INTO elim FROM public.eliminations WHERE id = elimination_id_param;

  IF elim IS NULL THEN
    RAISE EXCEPTION 'Elimination not found';
  END IF;

  IF elim.status != 'pending' THEN
    RAISE EXCEPTION 'Elimination already processed';
  END IF;

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

  -- Task als verbraucht markieren (Fix 4)
  IF elim.task_id IS NOT NULL THEN
    UPDATE public.player_tasks
    SET is_used = true
    WHERE game_id = elim.game_id AND player_id = elim.killer_id AND task_id = elim.task_id;
  END IF;

  -- Alle Tasks des Opfers übertragen (is_used bleibt erhalten)
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
  FROM public.game_players
  WHERE game_id = elim.game_id AND is_alive = true;

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

    RETURN jsonb_build_object('game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('game_over', false);
END;
$$;
