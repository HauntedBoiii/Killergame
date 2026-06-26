-- ============================================================
-- 016: Tester-Regeln
-- • Tester (username = 'Tester') erscheint nicht im
--   Daily Kniffel Scoreboard
-- • Tester kann nach Spielabschluss sofort neu starten
--   (abgeschlossenes Spiel wird bei start_or_resume gelöscht)
-- ============================================================

-- ── kniffel_start_or_resume: Tester darf täglich neu starten ─

CREATE OR REPLACE FUNCTION public.kniffel_start_or_resume()
RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_today     date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_game      public.kniffel_games;
  v_is_tester boolean;
BEGIN
  PERFORM public._process_kniffel_lootboxes();

  v_is_tester := auth.uid() = '461045f1-83b6-44a1-bd5e-1d3214533d8d'::uuid;

  -- Für Tester: abgeschlossenes Spiel löschen → frischer Start möglich
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
    INSERT INTO public.kniffel_games (user_id, game_date)
    VALUES (auth.uid(), v_today)
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_start_or_resume TO authenticated;

-- ── kniffel_daily_leaderboard: Tester ausblenden ─────────────

DROP FUNCTION IF EXISTS public.kniffel_daily_leaderboard(uuid);

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
    AND kg.status    = 'completed'
    AND kg.user_id  != '461045f1-83b6-44a1-bd5e-1d3214533d8d'::uuid
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
