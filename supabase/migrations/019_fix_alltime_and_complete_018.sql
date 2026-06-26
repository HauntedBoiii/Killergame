-- ============================================================
-- 019: Fix kniffel_alltime_leaderboard + Complete Migration 018
-- • kniffel_alltime_leaderboard: unqualified "user_id" in daily_winners
--   CTE was ambiguous with RETURNS TABLE(user_id uuid) OUT-variable
--   → error 42702 on every home screen load (BadgedAvatarWidget)
-- • Completes migration 018 from get_broken_assignments onwards
--   (those statements never ran because migration 018 failed there)
-- ============================================================

-- ── FIX: kniffel_alltime_leaderboard ─────────────────────────
-- daily_winners CTE: add alias "fg" to qualify all column refs,
-- removing the user_id ambiguity vs. the RETURNS TABLE OUT-variable.

CREATE OR REPLACE FUNCTION public.kniffel_alltime_leaderboard(
  p_game_id uuid DEFAULT NULL
) RETURNS TABLE(
  user_id      uuid,
  username     text,
  avatar_url   text,
  total_score  bigint,
  avg_score    numeric,
  days_played  bigint,
  best_score   integer,
  daily_wins   bigint,
  daily_losses bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  RETURN QUERY
  WITH
  filtered_games AS (
    SELECT kg.user_id, kg.game_date, kg.final_score
    FROM public.kniffel_games kg
    WHERE kg.status  = 'completed'
      AND kg.user_id != public._tester_uuid()
      AND (
        p_game_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.game_players gp
          WHERE gp.game_id = p_game_id AND gp.player_id = kg.user_id
        )
      )
  ),
  multi_player_days AS (
    SELECT fg.game_date
    FROM filtered_games fg
    GROUP BY fg.game_date
    HAVING COUNT(*) > 1
  ),
  -- FIX: alias "fg" added so "user_id" is table-qualified (fg.user_id),
  -- resolving the ambiguity with the RETURNS TABLE OUT-variable.
  daily_winners AS (
    SELECT DISTINCT ON (fg.game_date) fg.user_id, fg.game_date
    FROM filtered_games fg
    ORDER BY fg.game_date, fg.final_score DESC
  ),
  daily_losers AS (
    SELECT DISTINCT ON (fg.game_date) fg.user_id, fg.game_date
    FROM filtered_games fg
    JOIN multi_player_days mpd ON mpd.game_date = fg.game_date
    ORDER BY fg.game_date, fg.final_score ASC
  )
  SELECT
    p.id                                      AS user_id,
    p.username::text,
    p.avatar_url::text,
    COALESCE(SUM(fg.final_score)::bigint, 0)  AS total_score,
    COALESCE(AVG(fg.final_score::numeric), 0) AS avg_score,
    COUNT(DISTINCT fg.game_date)              AS days_played,
    COALESCE(MAX(fg.final_score), 0)          AS best_score,
    COUNT(DISTINCT dw.game_date)              AS daily_wins,
    COUNT(DISTINCT dl.game_date)              AS daily_losses
  FROM public.profiles p
  JOIN filtered_games fg ON fg.user_id = p.id
  LEFT JOIN daily_winners dw ON dw.user_id = p.id
  LEFT JOIN daily_losers  dl ON dl.user_id = p.id
  WHERE p.id != public._tester_uuid()
  GROUP BY p.id, p.username, p.avatar_url
  ORDER BY total_score DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_alltime_leaderboard TO authenticated;

-- ── COMPLETE 018: get_broken_assignments ──────────────────────
-- Migration 018 stopped here due to RETURNS TABLE type conflict.
-- DROP + CREATE resolves the error.

DROP FUNCTION IF EXISTS public.get_broken_assignments(uuid);
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

-- ── COMPLETE 018: _ensure_loot_rows ──────────────────────────

CREATE OR REPLACE FUNCTION public._ensure_loot_rows(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_credits (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_active_designs (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
END;
$$;

-- ── COMPLETE 018: get_loot_state ─────────────────────────────

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

-- ── COMPLETE 018: open_lootbox ────────────────────────────────
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

-- ── COMPLETE 018: trade_credits ───────────────────────────────

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

-- ── COMPLETE 018: spend_credits ───────────────────────────────
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

-- ── COMPLETE 018: set_active_design ──────────────────────────

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

-- ── COMPLETE 018: _award_morder_lootbox ──────────────────────

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

-- ── COMPLETE 018: _process_kniffel_lootboxes ─────────────────
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

-- ── COMPLETE 018: kniffel_roll ────────────────────────────────

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

-- ── COMPLETE 018: kniffel_select_category ────────────────────

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

-- ── COMPLETE 018: notify_kniffel_completed ────────────────────
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
