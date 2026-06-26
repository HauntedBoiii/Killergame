-- ============================================================
-- 014: game_id in kniffel_daily_leaderboard
-- Fügt game_id zur Rückgabe hinzu, damit das Scoreboard im
-- Daily-Leaderboard angeklickt und geladen werden kann.
-- ============================================================

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
) LANGUAGE plpgsql SECURITY DEFINER AS $$
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
