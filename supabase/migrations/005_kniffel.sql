-- ============================================================
-- Mörderspiel – Migration 005
-- Kniffel (Yahtzee) Mini-Game
-- ============================================================

-- ── Tabelle ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.kniffel_games (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL,
  game_date    date        NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date,
  status       text        NOT NULL DEFAULT 'in_progress'
                           CHECK (status IN ('in_progress', 'completed')),
  final_score  integer,
  current_dice integer[],
  held_dice    boolean[],
  roll_count   integer     NOT NULL DEFAULT 0,
  current_turn integer     NOT NULL DEFAULT 0,
  scorecard    jsonb       NOT NULL DEFAULT '{}',
  submitted_at timestamp with time zone,
  created_at   timestamp with time zone NOT NULL DEFAULT now(),
  updated_at   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT kniffel_games_pkey   PRIMARY KEY (id),
  CONSTRAINT kniffel_games_unique UNIQUE (user_id, game_date),
  CONSTRAINT kniffel_games_user_fkey FOREIGN KEY (user_id)
             REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.kniffel_games ENABLE ROW LEVEL SECURITY;

-- ── RLS Policies ─────────────────────────────────────────────

-- Abgeschlossene Spiele für alle lesbar (Rangliste);
-- eigenes Spiel immer lesbar/schreibbar.

DROP POLICY IF EXISTS "kniffel_select" ON public.kniffel_games;
CREATE POLICY "kniffel_select" ON public.kniffel_games
  FOR SELECT USING (status = 'completed' OR user_id = auth.uid());

DROP POLICY IF EXISTS "kniffel_insert" ON public.kniffel_games;
CREATE POLICY "kniffel_insert" ON public.kniffel_games
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "kniffel_update" ON public.kniffel_games;
CREATE POLICY "kniffel_update" ON public.kniffel_games
  FOR UPDATE USING (user_id = auth.uid() AND status = 'in_progress');

GRANT ALL ON public.kniffel_games TO authenticated;
GRANT ALL ON public.kniffel_games TO service_role;

-- ── Helper: Kategorie-Score serverseitig berechnen ───────────

CREATE OR REPLACE FUNCTION public.compute_kniffel_category_score(
  p_category text,
  p_dice     integer[]
) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
  v_sum    integer := 0;
  v_counts integer[] := ARRAY[0,0,0,0,0,0];
  v_i      integer;
  v_is_yahtzee         boolean;
  v_has_three          boolean;
  v_has_four           boolean;
  v_has_full_house     boolean;
  v_has_small_straight boolean;
  v_has_large_straight boolean;
BEGIN
  FOR v_i IN 1..5 LOOP
    v_sum := v_sum + p_dice[v_i];
    v_counts[p_dice[v_i]] := v_counts[p_dice[v_i]] + 1;
  END LOOP;

  v_is_yahtzee         := EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c = 5);
  v_has_three          := EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c >= 3);
  v_has_four           := EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c >= 4);
  -- Full House: 3+2, kein Kniffel
  v_has_full_house     := NOT v_is_yahtzee
                          AND EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c = 2)
                          AND EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c = 3);
  v_has_small_straight := (v_counts[1]>0 AND v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0)
                       OR (v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0)
                       OR (v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0 AND v_counts[6]>0);
  v_has_large_straight := (v_counts[1]>0 AND v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0)
                       OR (v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0 AND v_counts[6]>0);

  RETURN CASE p_category
    WHEN 'ones'            THEN v_counts[1]
    WHEN 'twos'            THEN v_counts[2] * 2
    WHEN 'threes'          THEN v_counts[3] * 3
    WHEN 'fours'           THEN v_counts[4] * 4
    WHEN 'fives'           THEN v_counts[5] * 5
    WHEN 'sixes'           THEN v_counts[6] * 6
    WHEN 'three_of_a_kind' THEN CASE WHEN v_has_three      THEN v_sum ELSE 0 END
    WHEN 'four_of_a_kind'  THEN CASE WHEN v_has_four       THEN v_sum ELSE 0 END
    WHEN 'full_house'      THEN CASE WHEN v_has_full_house  THEN 25    ELSE 0 END
    WHEN 'small_straight'  THEN CASE WHEN v_has_small_straight THEN 30 ELSE 0 END
    WHEN 'large_straight'  THEN CASE WHEN v_has_large_straight THEN 40 ELSE 0 END
    WHEN 'yahtzee'         THEN CASE WHEN v_is_yahtzee     THEN 50    ELSE 0 END
    WHEN 'chance'          THEN v_sum
    ELSE 0
  END;
END;
$$;

-- ── Spiel starten oder fortsetzen (idempotent) ────────────────

CREATE OR REPLACE FUNCTION public.kniffel_start_or_resume()
RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_game  public.kniffel_games;
BEGIN
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

-- ── Würfeln (serverseitig → manipulationssicher) ─────────────

CREATE OR REPLACE FUNCTION public.kniffel_roll(
  p_game_id uuid,
  p_held    boolean[] DEFAULT '{false,false,false,false,false}'
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_game     public.kniffel_games;
  v_new_dice integer[];
  v_i        integer;
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
  IF v_game.roll_count >= 3 THEN
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

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_roll TO authenticated;

-- ── Kategorie auswählen (serverseitige Score-Validierung) ─────

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

  -- Server berechnet validen Score; eingereicht muss 0 (scratchen) oder exakt sein
  v_valid_score := public.compute_kniffel_category_score(p_category, v_game.current_dice);
  IF p_score <> 0 AND p_score <> v_valid_score THEN
    RAISE EXCEPTION 'Invalid score % for %, expected 0 or %',
      p_score, p_category, v_valid_score;
  END IF;

  -- Kategorie speichern inkl. Würfel-Snapshot (Auditierbarkeit)
  v_new_scorecard := v_game.scorecard || jsonb_build_object(
    p_category, jsonb_build_object(
      'score', p_score,
      'dice',  to_jsonb(v_game.current_dice)
    )
  );

  -- Spiel abgeschlossen wenn alle 13 Kategorien gefüllt
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
    SET scorecard     = v_new_scorecard,
        status        = 'completed',
        final_score   = v_final_score,
        current_dice  = NULL,
        held_dice     = NULL,
        roll_count    = 0,
        current_turn  = current_turn + 1,
        submitted_at  = now(),
        updated_at    = now()
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  ELSE
    UPDATE public.kniffel_games
    SET scorecard    = v_new_scorecard,
        current_dice = NULL,
        held_dice    = NULL,
        roll_count   = 0,
        current_turn = current_turn + 1,
        updated_at   = now()
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_select_category TO authenticated;

-- ── Tagesrangliste (global oder auf eine Spielgruppe gefiltert) ─

CREATE OR REPLACE FUNCTION public.kniffel_daily_leaderboard(
  p_game_id uuid DEFAULT NULL
) RETURNS TABLE(
  user_id      uuid,
  username     text,
  avatar_url   text,
  final_score  integer,
  submitted_at timestamp with time zone,
  rank         bigint
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
  RETURN QUERY
  SELECT
    kg.user_id,
    p.username::text,
    p.avatar_url::text,
    kg.final_score,
    kg.submitted_at,
    RANK() OVER (ORDER BY kg.final_score DESC)::bigint
  FROM public.kniffel_games kg
  JOIN public.profiles p ON p.id = kg.user_id
  WHERE kg.game_date = v_today
    AND kg.status = 'completed'
    AND (
      p_game_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.game_id = p_game_id AND gp.player_id = kg.user_id
      )
    )
  ORDER BY kg.final_score DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_daily_leaderboard TO authenticated;

-- ── Allzeit-Rangliste ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_alltime_leaderboard(
  p_game_id uuid DEFAULT NULL
) RETURNS TABLE(
  user_id     uuid,
  username    text,
  avatar_url  text,
  total_score bigint,
  avg_score   numeric,
  days_played bigint,
  best_score  integer,
  daily_wins  bigint
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH daily_winners AS (
    -- Pro Tag den Spieler mit dem höchsten Score ermitteln
    SELECT DISTINCT ON (kg.game_date) kg.user_id, kg.game_date
    FROM public.kniffel_games kg
    WHERE kg.status = 'completed'
      AND (
        p_game_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.game_players gp
          WHERE gp.game_id = p_game_id AND gp.player_id = kg.user_id
        )
      )
    ORDER BY kg.game_date, kg.final_score DESC
  )
  SELECT
    p.id                                      AS user_id,
    p.username::text,
    p.avatar_url::text,
    COALESCE(SUM(kg.final_score)::bigint, 0)  AS total_score,
    COALESCE(AVG(kg.final_score::numeric), 0) AS avg_score,
    COUNT(DISTINCT kg.game_date)              AS days_played,
    COALESCE(MAX(kg.final_score), 0)          AS best_score,
    COUNT(DISTINCT dw.game_date)              AS daily_wins
  FROM public.profiles p
  JOIN public.kniffel_games kg
    ON kg.user_id = p.id AND kg.status = 'completed'
    AND (
      p_game_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.game_id = p_game_id AND gp.player_id = p.id
      )
    )
  LEFT JOIN daily_winners dw ON dw.user_id = p.id
  GROUP BY p.id, p.username, p.avatar_url
  ORDER BY total_score DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_alltime_leaderboard TO authenticated;

-- ── Push-Trigger: Benachrichtigung bei Spielende ──────────────
-- HINWEIS: <project-ref> und <service_role_key> ersetzen!

CREATE OR REPLACE FUNCTION public.notify_kniffel_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
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

DROP TRIGGER IF EXISTS on_kniffel_completed ON public.kniffel_games;
CREATE TRIGGER on_kniffel_completed
  AFTER UPDATE ON public.kniffel_games
  FOR EACH ROW EXECUTE FUNCTION public.notify_kniffel_completed();
