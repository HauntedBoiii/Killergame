-- ============================================================
-- 017: Leaderboard-Refactor
-- • _tester_uuid(): UUID-Literal durch zentrale Helper-Funktion ersetzt
-- • SET search_path = public: SECURITY DEFINER-Funktionen gehärtet
-- • kniffel_start_or_resume: Auth-Guard + ON CONFLICT race-fix
-- • kniffel_daily_leaderboard: DENSE_RANK() statt RANK()
-- • kniffel_alltime_leaderboard: O(n²) korrelierte Subquery →
--   filtered_games + multi_player_days CTEs eliminieren Duplikate
-- • Partial-Index für Leaderboard-Queries
-- ============================================================

-- ── Zentrale Tester-UUID (bisher 5× als Literal) ─────────────

CREATE OR REPLACE FUNCTION public._tester_uuid()
RETURNS uuid LANGUAGE sql IMMUTABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT '461045f1-83b6-44a1-bd5e-1d3214533d8d'::uuid
$$;

-- ── Partial-Index: Leaderboard filtert immer auf status = completed ──

CREATE INDEX IF NOT EXISTS idx_kniffel_completed_date_user
  ON public.kniffel_games (game_date, user_id, final_score DESC)
  WHERE status = 'completed';

-- ── kniffel_start_or_resume ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_start_or_resume()
RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today     date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_game      public.kniffel_games;
  v_is_tester boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public._process_kniffel_lootboxes();

  v_is_tester := auth.uid() = public._tester_uuid();

  -- Tester darf täglich neu starten: abgeschlossenes Spiel löschen
  IF v_is_tester THEN
    DELETE FROM public.kniffel_games
    WHERE user_id  = auth.uid()
      AND game_date = v_today
      AND status   = 'completed';
  END IF;

  SELECT * INTO v_game
  FROM public.kniffel_games
  WHERE user_id = auth.uid() AND game_date = v_today;

  IF NOT FOUND THEN
    -- ON CONFLICT DO NOTHING fängt parallele Requests desselben Users ab
    INSERT INTO public.kniffel_games (user_id, game_date)
    VALUES (auth.uid(), v_today)
    ON CONFLICT (user_id, game_date) DO NOTHING
    RETURNING * INTO v_game;

    -- Falls INSERT keinen Row zurückgegeben hat (Concurrent-Session gewann)
    IF NOT FOUND THEN
      SELECT * INTO v_game
      FROM public.kniffel_games
      WHERE user_id = auth.uid() AND game_date = v_today;
    END IF;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_start_or_resume TO authenticated;

-- ── kniffel_daily_leaderboard ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.kniffel_daily_leaderboard(
  p_game_id uuid DEFAULT NULL
) RETURNS TABLE(
  game_id      uuid,
  user_id      uuid,
  username     text,
  avatar_url   text,
  final_score  integer,
  submitted_at timestamp with time zone,
  rank         bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
  RETURN QUERY
  SELECT
    kg.id           AS game_id,
    kg.user_id,
    p.username::text,
    p.avatar_url::text,
    kg.final_score,
    kg.submitted_at,
    -- DENSE_RANK: kein Rang-Lücke bei Gleichstand (1,2,2,3 statt 1,2,2,4)
    -- Berechnet nach Tester-Filter → Tester beeinflusst keine Platzierung
    DENSE_RANK() OVER (ORDER BY kg.final_score DESC)::bigint
  FROM public.kniffel_games kg
  JOIN public.profiles p ON p.id = kg.user_id
  WHERE kg.game_date = v_today
    AND kg.status    = 'completed'
    AND kg.user_id  != public._tester_uuid()
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

-- ── kniffel_alltime_leaderboard ───────────────────────────────

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
  -- Alle relevanten Spiele: abgeschlossen, kein Tester, optional nach game_id gefiltert.
  -- Einziger Ort der game_players-Membership-Prüfung – kein Copy-Paste mehr.
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
  -- Tage mit > 1 Teilnehmer: Voraussetzung für einen eindeutigen Tagesverlierer
  multi_player_days AS (
    SELECT game_date
    FROM filtered_games
    GROUP BY game_date
    HAVING COUNT(*) > 1
  ),
  -- Tagessieger: höchster Score pro Tag
  daily_winners AS (
    SELECT DISTINCT ON (game_date) user_id, game_date
    FROM filtered_games
    ORDER BY game_date, final_score DESC
  ),
  -- Tagesverlierer: niedrigster Score, nur an Mehrspielertagen
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
