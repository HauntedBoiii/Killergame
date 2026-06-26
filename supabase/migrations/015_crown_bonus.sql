-- ============================================================
-- 015: Kronenmesser Superkraft (Crown Bonus Roll)
-- Adds crown_bonus_available + crown_bonus_used to
-- kniffel_games. Updates kniffel_roll to:
--   • Allow a 4th roll when crown_bonus_available = true
--   • Auto-grant the bonus after roll 3 when user has
--     Kronenmesser active + holds exactly 4 identical dice
--     + the 5th die doesn't complete the Kniffel
--   • Consume the bonus on roll 4
-- Updates kniffel_select_category to reset
-- crown_bonus_available when moving to the next turn.
-- ============================================================

ALTER TABLE public.kniffel_games
  ADD COLUMN IF NOT EXISTS crown_bonus_available boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS crown_bonus_used      boolean NOT NULL DEFAULT false;

-- ── Updated kniffel_roll ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_roll(
  p_game_id uuid,
  p_held    boolean[] DEFAULT '{false,false,false,false,false}'
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER AS $$
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

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game not found';
  END IF;
  IF v_game.status = 'completed' THEN
    RAISE EXCEPTION 'Game already completed';
  END IF;
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
  SET current_dice = v_new_dice,
      held_dice    = p_held,
      roll_count   = roll_count + 1,
      updated_at   = now()
  WHERE id = p_game_id
  RETURNING * INTO v_game;

  -- ── Grant crown bonus after roll 3 if conditions met ──────
  IF v_game.roll_count = 3
     AND NOT v_game.crown_bonus_used
     AND NOT v_game.crown_bonus_available
  THEN
    v_held_count := 0;
    FOR v_i IN 1..5 LOOP
      IF p_held[v_i] THEN v_held_count := v_held_count + 1; END IF;
    END LOOP;

    IF v_held_count = 4 THEN
      SELECT EXISTS (
        SELECT 1 FROM public.user_active_designs uad
        JOIN public.loot_items li ON li.id = uad.item_id
        WHERE uad.user_id = auth.uid()
          AND li.design_key = 'crown'
          AND li.item_type = 'dice'
      ) INTO v_has_crown;

      IF v_has_crown THEN
        v_held_value := NULL;
        FOR v_i IN 1..5 LOOP
          IF p_held[v_i] THEN
            v_held_value := v_new_dice[v_i];
            EXIT;
          END IF;
        END LOOP;

        v_held_all_same := true;
        FOR v_i IN 1..5 LOOP
          IF p_held[v_i] AND v_new_dice[v_i] != v_held_value THEN
            v_held_all_same := false;
          END IF;
        END LOOP;

        v_nonheld_value := NULL;
        FOR v_i IN 1..5 LOOP
          IF NOT p_held[v_i] THEN
            v_nonheld_value := v_new_dice[v_i];
            EXIT;
          END IF;
        END LOOP;

        IF v_held_all_same
           AND v_nonheld_value IS NOT NULL
           AND v_nonheld_value != v_held_value
        THEN
          UPDATE public.kniffel_games
          SET crown_bonus_available = true
          WHERE id = p_game_id
          RETURNING * INTO v_game;
        END IF;
      END IF;
    END IF;
  END IF;

  -- ── Consume crown bonus on roll 4 ─────────────────────────
  IF v_game.roll_count = 4 THEN
    UPDATE public.kniffel_games
    SET crown_bonus_available = false,
        crown_bonus_used      = true
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_roll TO authenticated;

-- ── Updated kniffel_select_category ──────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_select_category(
  p_game_id  uuid,
  p_category text,
  p_score    integer
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER AS $$
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

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game not found';
  END IF;
  IF v_game.status = 'completed' THEN
    RAISE EXCEPTION 'Game already completed';
  END IF;
  IF v_game.roll_count = 0 THEN
    RAISE EXCEPTION 'Must roll at least once before selecting a category';
  END IF;
  IF v_game.game_date != (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'Not todays game';
  END IF;
  IF NOT (p_category = ANY(v_valid_cats)) THEN
    RAISE EXCEPTION 'Invalid category: %', p_category;
  END IF;
  IF v_game.scorecard ? p_category THEN
    RAISE EXCEPTION 'Category already used: %', p_category;
  END IF;

  v_valid_score := public.compute_kniffel_category_score(p_category, v_game.current_dice);
  IF p_score <> 0 AND p_score <> v_valid_score THEN
    RAISE EXCEPTION 'Invalid score % for %, expected 0 or %',
      p_score, p_category, v_valid_score;
  END IF;

  v_new_scorecard := v_game.scorecard || jsonb_build_object(
    p_category, jsonb_build_object(
      'score', p_score,
      'dice',  to_jsonb(v_game.current_dice)
    )
  );

  IF (SELECT count(*) FROM jsonb_each(v_new_scorecard)) = 13 THEN
    v_upper_sum := (
      SELECT COALESCE(SUM((value->>'score')::integer), 0)
      FROM jsonb_each(v_new_scorecard)
      WHERE key IN ('ones','twos','threes','fours','fives','sixes')
    );
    v_final_score := (
      SELECT COALESCE(SUM((value->>'score')::integer), 0)
      FROM jsonb_each(v_new_scorecard)
    ) + CASE WHEN v_upper_sum >= 63 THEN 35 ELSE 0 END;

    UPDATE public.kniffel_games
    SET scorecard             = v_new_scorecard,
        status                = 'completed',
        final_score           = v_final_score,
        current_dice          = NULL,
        held_dice             = NULL,
        roll_count            = 0,
        current_turn          = current_turn + 1,
        crown_bonus_available = false,
        submitted_at          = now(),
        updated_at            = now()
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  ELSE
    UPDATE public.kniffel_games
    SET scorecard             = v_new_scorecard,
        current_dice          = NULL,
        held_dice             = NULL,
        roll_count            = 0,
        current_turn          = current_turn + 1,
        crown_bonus_available = false,
        updated_at            = now()
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_select_category TO authenticated;
