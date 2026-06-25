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
  daily_wins  bigint,
  daily_losses bigint
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH daily_winners AS (
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
  ),
  daily_losers AS (
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
      AND (
        SELECT COUNT(*) FROM public.kniffel_games kg2
        WHERE kg2.status = 'completed'
          AND kg2.game_date = kg.game_date
          AND kg2.user_id != kg.user_id
          AND (
            p_game_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.game_players gp2
              WHERE gp2.game_id = p_game_id AND gp2.player_id = kg2.user_id
            )
          )
      ) > 0
    ORDER BY kg.game_date, kg.final_score ASC
  )
  SELECT
    p.id                                                   AS user_id,
    p.username::text,
    p.avatar_url::text,
    COALESCE(SUM(kg.final_score)::bigint, 0)               AS total_score,
    COALESCE(AVG(kg.final_score::numeric), 0)              AS avg_score,
    COUNT(DISTINCT kg.game_date)                           AS days_played,
    COALESCE(MAX(kg.final_score), 0)                       AS best_score,
    COUNT(DISTINCT dw.game_date)                           AS daily_wins,
    COUNT(DISTINCT dl.game_date)                           AS daily_losses
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
  LEFT JOIN daily_losers  dl ON dl.user_id = p.id
  GROUP BY p.id, p.username, p.avatar_url
  ORDER BY total_score DESC;
END;
$$;
