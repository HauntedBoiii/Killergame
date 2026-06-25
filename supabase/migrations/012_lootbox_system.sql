-- ============================================================
-- 012: Lootbox System
-- Neue Tabellen: loot_items, user_inventory, user_credits,
--   user_lootboxes, user_active_designs, kniffel_lootbox_awards
-- Neue Funktionen: get_loot_state, open_lootbox, trade_credits,
--   spend_credits, set_active_design, _award_morder_lootbox,
--   _process_kniffel_lootboxes
-- Modifizierte Funktionen: confirm_kill, leave_game,
--   admin_kick_player, kniffel_start_or_resume
-- ============================================================

-- -- Tabellen ----------------------------------------------

CREATE TABLE public.loot_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type  text NOT NULL CHECK (item_type IN ('card', 'dice')),
  design_key text NOT NULL,
  name       text NOT NULL,
  rarity     text NOT NULL CHECK (rarity IN ('bronze', 'silver', 'gold')),
  sort_order int  NOT NULL DEFAULT 0,
  UNIQUE(item_type, design_key)
);

CREATE TABLE public.user_inventory (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id     uuid NOT NULL REFERENCES public.loot_items(id) ON DELETE CASCADE,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, item_id)
);

CREATE TABLE public.user_credits (
  user_id        uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  bronze_credits int NOT NULL DEFAULT 0 CHECK (bronze_credits >= 0),
  silver_credits int NOT NULL DEFAULT 0 CHECK (silver_credits >= 0),
  gold_credits   int NOT NULL DEFAULT 0 CHECK (gold_credits >= 0)
);

CREATE TABLE public.user_lootboxes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source       text NOT NULL CHECK (source IN ('kniffel', 'morder')),
  status       text NOT NULL DEFAULT 'ready' CHECK (status IN ('pending', 'ready', 'opened')),
  available_at timestamptz NOT NULL DEFAULT now(),
  opened_at    timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_active_designs (
  user_id        uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active_card_id uuid REFERENCES public.loot_items(id) ON DELETE SET NULL,
  active_dice_id uuid REFERENCES public.loot_items(id) ON DELETE SET NULL
);

-- Tracking: welcher Tag wurde bereits mit Lootbox bedacht
CREATE TABLE public.kniffel_lootbox_awards (
  game_date  date PRIMARY KEY,
  winner_id  uuid REFERENCES auth.users(id),
  awarded_at timestamptz NOT NULL DEFAULT now()
);
-- Kein direkter Client-Zugriff; RLS sperrt anon/authenticated aus.
-- Schreiben nur ueber SECURITY DEFINER-Funktionen.
ALTER TABLE public.kniffel_lootbox_awards ENABLE ROW LEVEL SECURITY;

-- -- Seed: Loot-Items --------------------------------------

INSERT INTO public.loot_items (item_type, design_key, name, rarity, sort_order) VALUES
  ('card', 'smoke',   'Dark Smoke',       'bronze', 10),
  ('card', 'accent',  'Farbwechsel',      'bronze', 20),
  ('card', 'glass',   'Glas mit Shimmer', 'silver', 30),
  ('card', 'neon',    'Neon Rand',        'silver', 40),
  ('card', 'wanted',  'Steckbrief',       'silver', 50),
  ('card', 'bond',    'Agent 007',        'gold',   60),
  ('card', 'sparks',  'Funken',           'gold',   70),
  ('dice', 'wood',    'Holz',             'bronze', 10),
  ('dice', 'neon',    'Neon',             'bronze', 20),
  ('dice', 'vegas',   'Vegas',            'bronze', 30),
  ('dice', 'blood',   'Blut',             'bronze', 40),
  ('dice', 'app_red', 'App-Rot',          'bronze', 50),
  ('dice', 'digital', 'Digital',          'bronze', 60),
  ('dice', 'crystal', 'Kristall',         'bronze', 70);

-- -- RLS ---------------------------------------------------

ALTER TABLE public.loot_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "loot_items_read" ON public.loot_items
  FOR SELECT TO authenticated USING (true);

ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_inventory_own" ON public.user_inventory
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_credits_own" ON public.user_credits
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.user_lootboxes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_lootboxes_own" ON public.user_lootboxes
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.user_active_designs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_active_designs_own" ON public.user_active_designs
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- kniffel_lootbox_awards: kein direkter Client-Zugriff

-- -- Hilfsfunktion: Zeilen anlegen falls noch nicht vorhanden -

CREATE OR REPLACE FUNCTION public._ensure_loot_rows(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.user_credits (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_active_designs (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
END;
$$;

-- -- get_loot_state ----------------------------------------

CREATE OR REPLACE FUNCTION public.get_loot_state()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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
      SELECT jsonb_build_object(
        'bronze', bronze_credits,
        'silver', silver_credits,
        'gold',   gold_credits
      )
      FROM public.user_credits
      WHERE user_id = v_user_id
    ), jsonb_build_object('bronze', 0, 'silver', 0, 'gold', 0)),
    'active_card_key', (
      SELECT li.design_key
      FROM public.user_active_designs uad
      JOIN public.loot_items li ON li.id = uad.active_card_id
      WHERE uad.user_id = v_user_id
    ),
    'active_dice_key', (
      SELECT li.design_key
      FROM public.user_active_designs uad
      JOIN public.loot_items li ON li.id = uad.active_dice_id
      WHERE uad.user_id = v_user_id
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_loot_state TO authenticated;

-- -- open_lootbox ------------------------------------------

CREATE OR REPLACE FUNCTION public.open_lootbox(p_lootbox_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_box     public.user_lootboxes;
  v_roll    float;
  v_rarity  text;
  v_item    public.loot_items;
BEGIN
  SELECT * INTO v_box
  FROM public.user_lootboxes
  WHERE id = p_lootbox_id AND user_id = v_user_id AND status != 'opened'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lootbox nicht gefunden oder bereits geöffnet';
  END IF;

  IF v_box.available_at > now() THEN
    RAISE EXCEPTION 'Lootbox noch nicht verfügbar';
  END IF;

  PERFORM public._ensure_loot_rows(v_user_id);

  v_roll   := random();
  v_rarity := CASE
    WHEN v_roll < 0.70 THEN 'bronze'
    WHEN v_roll < 0.90 THEN 'silver'
    ELSE 'gold'
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

  UPDATE public.user_lootboxes
  SET status = 'opened', opened_at = now()
  WHERE id = p_lootbox_id;

  IF v_item.id IS NULL THEN
    IF v_rarity = 'bronze' THEN
      UPDATE public.user_credits SET bronze_credits = bronze_credits + 1 WHERE user_id = v_user_id;
    ELSIF v_rarity = 'silver' THEN
      UPDATE public.user_credits SET silver_credits = silver_credits + 1 WHERE user_id = v_user_id;
    ELSE
      UPDATE public.user_credits SET gold_credits = gold_credits + 1 WHERE user_id = v_user_id;
    END IF;

    RETURN jsonb_build_object('type', 'credit', 'rarity', v_rarity);
  ELSE
    INSERT INTO public.user_inventory (user_id, item_id) VALUES (v_user_id, v_item.id);

    RETURN jsonb_build_object(
      'type',   'item',
      'rarity', v_rarity,
      'item',   jsonb_build_object(
        'item_id',    v_item.id,
        'design_key', v_item.design_key,
        'item_type',  v_item.item_type,
        'name',       v_item.name,
        'rarity',     v_item.rarity
      )
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.open_lootbox TO authenticated;

-- -- trade_credits -----------------------------------------
-- direction='up':   2 aktuelle -> 1 naechsthoehere
-- direction='down': 1 aktuelle -> 2 naechstniedrigere

CREATE OR REPLACE FUNCTION public.trade_credits(p_rarity text, p_direction text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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

-- -- spend_credits -----------------------------------------

CREATE OR REPLACE FUNCTION public.spend_credits(p_rarity text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_item    public.loot_items;
BEGIN
  PERFORM public._ensure_loot_rows(v_user_id);

  IF p_rarity = 'bronze' THEN
    IF (SELECT bronze_credits FROM public.user_credits WHERE user_id = v_user_id) < 1 THEN
      RAISE EXCEPTION 'Nicht genug Bronze-Credits';
    END IF;
  ELSIF p_rarity = 'silver' THEN
    IF (SELECT silver_credits FROM public.user_credits WHERE user_id = v_user_id) < 1 THEN
      RAISE EXCEPTION 'Nicht genug Silber-Credits';
    END IF;
  ELSIF p_rarity = 'gold' THEN
    IF (SELECT gold_credits FROM public.user_credits WHERE user_id = v_user_id) < 1 THEN
      RAISE EXCEPTION 'Nicht genug Gold-Credits';
    END IF;
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
      'item_id',    v_item.id,
      'design_key', v_item.design_key,
      'item_type',  v_item.item_type,
      'name',       v_item.name,
      'rarity',     v_item.rarity
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.spend_credits TO authenticated;

-- -- set_active_design -------------------------------------
-- p_item_id = NULL -> setzt Design auf Standard zurueck

CREATE OR REPLACE FUNCTION public.set_active_design(p_item_id uuid, p_type text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
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

-- -- _award_morder_lootbox (intern, kein GRANT) ------------

CREATE OR REPLACE FUNCTION public._award_morder_lootbox(p_game_id uuid, p_winner_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
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

-- -- _process_kniffel_lootboxes (intern, kein GRANT) -------

CREATE OR REPLACE FUNCTION public._process_kniffel_lootboxes()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
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
    SELECT kg.user_id INTO v_winner
    FROM public.kniffel_games kg
    WHERE kg.game_date = v_rec.game_date AND kg.status = 'completed'
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

-- -- confirm_kill (mit Lootbox-Award) ---------------------

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

  IF elim IS NULL THEN RAISE EXCEPTION 'Elimination not found'; END IF;
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

    PERFORM public._award_morder_lootbox(elim.game_id, v_winner_id);

    RETURN jsonb_build_object('game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('game_over', false);
END;
$$;

-- -- leave_game (mit Lootbox-Award) -----------------------

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

  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = v_user_id;

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
    SELECT player_id INTO v_new_admin
    FROM public.game_players
    WHERE game_id = game_id_param AND player_id != v_user_id AND is_alive = true LIMIT 1;
    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id
    FROM public.game_players WHERE game_id = game_id_param AND is_alive = true LIMIT 1;

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

-- -- admin_kick_player (mit Lootbox-Award) ----------------

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

  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = target_player_id;
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
    SELECT player_id INTO v_new_admin
    FROM public.game_players
    WHERE game_id = game_id_param AND player_id != target_player_id AND is_alive = true LIMIT 1;
    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id
    FROM public.game_players WHERE game_id = game_id_param AND is_alive = true LIMIT 1;

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

-- -- kniffel_start_or_resume (mit Lootbox-Processing) -----

CREATE OR REPLACE FUNCTION public.kniffel_start_or_resume()
RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_game  public.kniffel_games;
BEGIN
  PERFORM public._process_kniffel_lootboxes();

  SELECT * INTO v_game
  FROM public.kniffel_games
  WHERE user_id = auth.uid() AND game_date = v_today;

  IF NOT FOUND THEN
    INSERT INTO public.kniffel_games (user_id, game_date)
    VALUES (auth.uid(), v_today)
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_start_or_resume TO authenticated;
