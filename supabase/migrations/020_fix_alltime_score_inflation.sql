-- ============================================================
-- 020: Fix kniffel_alltime_leaderboard total_score inflation
-- • JOIN filtered_games × daily_winners × daily_losers (alle auf user_id)
--   erzeugte kartesisches Produkt: N×W×L Zeilen pro Spieler
--   → SUM(final_score) wurde W×L-fach zu hoch
-- • Fix: Score-Aggregation in eigene CTEs ausgelagert (user_scores,
--   user_wins, user_losses), JOIN nur noch 1:1 pro user_id
-- ============================================================

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
  -- Alle abgeschlossenen Spiele: kein Tester, optional nach game_id gefiltert.
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
  -- Tage mit > 1 Teilnehmer: Voraussetzung für eindeutigen Tagesverlierer
  multi_player_days AS (
    SELECT game_date
    FROM filtered_games
    GROUP BY game_date
    HAVING COUNT(*) > 1
  ),
  -- Tagessieger: höchster Score pro Tag
  daily_winners AS (
    SELECT DISTINCT ON (fg.game_date) fg.user_id, fg.game_date
    FROM filtered_games fg
    ORDER BY fg.game_date, fg.final_score DESC
  ),
  -- Tagesverlierer: niedrigster Score, nur an Mehrspielertagen
  daily_losers AS (
    SELECT DISTINCT ON (fg.game_date) fg.user_id, fg.game_date
    FROM filtered_games fg
    JOIN multi_player_days mpd ON mpd.game_date = fg.game_date
    ORDER BY fg.game_date, fg.final_score ASC
  ),
  -- Score-Aggregation pro Spieler – VOR dem Join mit wins/losses.
  -- Verhindert kartesisches Produkt N×W×L bei SUM/AVG.
  user_scores AS (
    SELECT
      fg.user_id,
      SUM(fg.final_score)::bigint      AS total_score,
      AVG(fg.final_score::numeric)     AS avg_score,
      COUNT(DISTINCT fg.game_date)     AS days_played,
      MAX(fg.final_score)              AS best_score
    FROM filtered_games fg
    GROUP BY fg.user_id
  ),
  -- Gewinn- und Verlustzählungen pro Spieler (1:1 joinfähig)
  user_wins AS (
    SELECT dw.user_id, COUNT(*) AS daily_wins
    FROM daily_winners dw
    GROUP BY dw.user_id
  ),
  user_losses AS (
    SELECT dl.user_id, COUNT(*) AS daily_losses
    FROM daily_losers dl
    GROUP BY dl.user_id
  )
  SELECT
    p.id                                        AS user_id,
    p.username::text,
    p.avatar_url::text,
    us.total_score,
    us.avg_score,
    us.days_played,
    us.best_score::integer                      AS best_score,
    COALESCE(uw.daily_wins,   0)::bigint        AS daily_wins,
    COALESCE(ul.daily_losses, 0)::bigint        AS daily_losses
  FROM public.profiles p
  JOIN user_scores us   ON us.user_id   = p.id
  LEFT JOIN user_wins   uw ON uw.user_id = p.id
  LEFT JOIN user_losses ul ON ul.user_id = p.id
  WHERE p.id != public._tester_uuid()
  ORDER BY us.total_score DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_alltime_leaderboard TO authenticated;
