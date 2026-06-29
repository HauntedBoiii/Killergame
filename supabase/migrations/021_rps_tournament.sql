-- ============================================================
-- 021: Schnick-Schnack-Schnuck-Turnier + Bonus-Kniffel
--
-- A) kniffel_games: is_bonus-Spalte + neue UNIQUE-Constraint
--    → ermöglicht je 1 Normal- + 1 Bonus-Spiel pro User pro Tag
-- B) profiles: rps_bonus_available-Flag
-- C) kniffel_start_or_resume: p_is_bonus-Parameter
-- D) kniffel_daily_leaderboard: zeigt nur den besten Score pro User
-- E) kniffel_alltime_leaderboard: aggregiert auf Tages-Best-Score
-- F) rps_tournaments + rps_matches Tabellen
-- G) RLS-Policies für RPS-Tabellen
-- H) rps_start_tournament / rps_submit_choice / _rps_advance_bracket
-- ============================================================

-- ── A: kniffel_games: is_bonus + neue UNIQUE-Constraint ──────

ALTER TABLE public.kniffel_games
  ADD COLUMN IF NOT EXISTS is_bonus boolean NOT NULL DEFAULT false;

-- Alte Constraint (user_id, game_date) → (user_id, game_date, is_bonus)
-- Ermöglicht Normal- + Bonus-Spiel am selben Tag.
ALTER TABLE public.kniffel_games
  DROP CONSTRAINT IF EXISTS kniffel_games_user_id_game_date_key;

ALTER TABLE public.kniffel_games
  DROP CONSTRAINT IF EXISTS kniffel_games_user_id_game_date_is_bonus_key;

ALTER TABLE public.kniffel_games
  ADD CONSTRAINT kniffel_games_user_id_game_date_is_bonus_key
  UNIQUE (user_id, game_date, is_bonus);

-- ── B: profiles: rps_bonus_available ─────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS rps_bonus_available boolean NOT NULL DEFAULT false;

-- ── C: kniffel_start_or_resume (mit p_is_bonus) ──────────────
-- Bestehende Signatur hatte kein p_is_bonus. DROP + CREATE wegen
-- Signatur-Änderung (PostgreSQL erlaubt kein OR REPLACE bei neuen Parametern
-- wenn der Old-Overload noch existiert).

DROP FUNCTION IF EXISTS public.kniffel_start_or_resume();

CREATE OR REPLACE FUNCTION public.kniffel_start_or_resume(
  p_is_bonus boolean DEFAULT false
)
RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today       date    := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_game        public.kniffel_games;
  v_is_tester   boolean;
  v_bonus_avail boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public._process_kniffel_lootboxes();

  v_is_tester := auth.uid() = public._tester_uuid();

  IF p_is_bonus THEN
    -- ── Bonus-Spiel: Berechtigung prüfen ──────────────────────
    SELECT rps_bonus_available INTO v_bonus_avail
    FROM public.profiles
    WHERE id = auth.uid();

    IF NOT v_bonus_avail THEN
      RAISE EXCEPTION 'No RPS bonus available';
    END IF;

    -- Normales Spiel muss heute abgeschlossen sein
    IF NOT EXISTS (
      SELECT 1 FROM public.kniffel_games
      WHERE user_id  = auth.uid()
        AND game_date = v_today
        AND is_bonus  = false
        AND status    = 'completed'
    ) THEN
      RAISE EXCEPTION 'Complete normal game first';
    END IF;

    -- Bonus einlösen (verhindert Doppel-Bonus)
    UPDATE public.profiles
    SET rps_bonus_available = false
    WHERE id = auth.uid();

    -- Bonus-Spiel holen oder anlegen
    SELECT * INTO v_game
    FROM public.kniffel_games
    WHERE user_id  = auth.uid()
      AND game_date = v_today
      AND is_bonus  = true;

    IF NOT FOUND THEN
      INSERT INTO public.kniffel_games (user_id, game_date, is_bonus)
      VALUES (auth.uid(), v_today, true)
      ON CONFLICT (user_id, game_date, is_bonus) DO NOTHING
      RETURNING * INTO v_game;

      IF NOT FOUND THEN
        SELECT * INTO v_game
        FROM public.kniffel_games
        WHERE user_id  = auth.uid()
          AND game_date = v_today
          AND is_bonus  = true;
      END IF;
    END IF;

  ELSE
    -- ── Normales Spiel (Bestehende Logik) ─────────────────────
    IF v_is_tester THEN
      DELETE FROM public.kniffel_games
      WHERE user_id  = auth.uid()
        AND game_date = v_today
        AND is_bonus  = false
        AND status    = 'completed';
    END IF;

    SELECT * INTO v_game
    FROM public.kniffel_games
    WHERE user_id  = auth.uid()
      AND game_date = v_today
      AND is_bonus  = false;

    IF NOT FOUND THEN
      INSERT INTO public.kniffel_games (user_id, game_date, is_bonus)
      VALUES (auth.uid(), v_today, false)
      ON CONFLICT (user_id, game_date, is_bonus) DO NOTHING
      RETURNING * INTO v_game;

      IF NOT FOUND THEN
        SELECT * INTO v_game
        FROM public.kniffel_games
        WHERE user_id  = auth.uid()
          AND game_date = v_today
          AND is_bonus  = false;
      END IF;
    END IF;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_start_or_resume(boolean) TO authenticated;

-- ── D: kniffel_daily_leaderboard (bester Score pro User) ─────
-- 021: DISTINCT ON user_id, sortiert nach final_score DESC → zeigt
--      nur den besten der beiden Versuche (Normal / Bonus).

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
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
  RETURN QUERY
  WITH best_today AS (
    -- Bestes abgeschlossenes Spiel pro User heute (ignoriert is_bonus)
    SELECT DISTINCT ON (kg.user_id)
      kg.id           AS game_id,
      kg.user_id,
      kg.final_score,
      kg.submitted_at
    FROM public.kniffel_games kg
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
    ORDER BY kg.user_id, kg.final_score DESC, kg.submitted_at ASC
  )
  SELECT
    bt.game_id,
    bt.user_id,
    p.username::text,
    p.avatar_url::text,
    bt.final_score,
    bt.submitted_at,
    DENSE_RANK() OVER (ORDER BY bt.final_score DESC)::bigint
  FROM best_today bt
  JOIN public.profiles p ON p.id = bt.user_id
  ORDER BY bt.final_score DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_daily_leaderboard TO authenticated;

-- ── E: kniffel_alltime_leaderboard (Tages-Best statt Summe aller) ─
-- 021: filtered_games aggregiert auf MAX(final_score) pro (user_id, game_date)
--      → Bonus-Spiele fließen nur ein wenn sie besser sind.

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
  -- Bester Score pro (user_id, game_date) — Bonus zählt nur wenn besser.
  filtered_games AS (
    SELECT kg.user_id, kg.game_date, MAX(kg.final_score) AS final_score
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
    GROUP BY kg.user_id, kg.game_date
  ),
  multi_player_days AS (
    SELECT game_date
    FROM filtered_games
    GROUP BY game_date
    HAVING COUNT(*) > 1
  ),
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
  ),
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
  JOIN user_scores us        ON us.user_id   = p.id
  LEFT JOIN user_wins   uw   ON uw.user_id   = p.id
  LEFT JOIN user_losses ul   ON ul.user_id   = p.id
  WHERE p.id != public._tester_uuid()
  ORDER BY us.total_score DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_alltime_leaderboard TO authenticated;

-- ── F: RPS-Tabellen ───────────────────────────────────────────

-- Alte game_id-Spalte entfernen falls noch vorhanden (aus früherem Lauf)
ALTER TABLE public.rps_tournaments DROP COLUMN IF EXISTS game_id;

CREATE TABLE IF NOT EXISTS public.rps_tournaments (
  id          uuid                     NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by  uuid                     NOT NULL REFERENCES public.profiles(id),
  status      text                     NOT NULL DEFAULT 'in_progress',
  winner_id   uuid                              REFERENCES public.profiles(id),
  created_at  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT rps_tournaments_status_check CHECK (status IN ('in_progress', 'completed'))
);

-- Nur ein globales Turnier pro Kalendertag (UTC)
CREATE UNIQUE INDEX IF NOT EXISTS rps_tournaments_date_key
  ON public.rps_tournaments (CAST(created_at AT TIME ZONE 'UTC' AS date));

CREATE TABLE IF NOT EXISTS public.rps_matches (
  id            uuid                     NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id uuid                     NOT NULL REFERENCES public.rps_tournaments(id) ON DELETE CASCADE,
  round         integer                  NOT NULL,
  match_slot    integer                  NOT NULL,
  player_a_id   uuid                     NOT NULL REFERENCES public.profiles(id),
  player_b_id   uuid                              REFERENCES public.profiles(id),
  choice_a      text,
  choice_b      text,
  winner_id     uuid                              REFERENCES public.profiles(id),
  is_bye        boolean                  NOT NULL DEFAULT false,
  created_at    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT rps_matches_unique      UNIQUE (tournament_id, round, match_slot),
  CONSTRAINT rps_matches_choice_a_ck CHECK (choice_a IN ('rock','paper','scissors') OR choice_a IS NULL),
  CONSTRAINT rps_matches_choice_b_ck CHECK (choice_b IN ('rock','paper','scissors') OR choice_b IS NULL)
);

-- ── G: RLS-Policies ──────────────────────────────────────────

ALTER TABLE public.rps_tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rps_matches     ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.rps_tournaments TO authenticated;
GRANT SELECT ON public.rps_matches TO authenticated;

DROP POLICY IF EXISTS "rps_tournaments_select" ON public.rps_tournaments;
CREATE POLICY "rps_tournaments_select"
  ON public.rps_tournaments FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "rps_matches_select" ON public.rps_matches;
CREATE POLICY "rps_matches_select"
  ON public.rps_matches FOR SELECT TO authenticated
  USING (true);

-- ── H: Funktionen ─────────────────────────────────────────────

-- ── _rps_advance_bracket (intern) ────────────────────────────
-- Prüft ob alle Matches der aktuellen Runde abgeschlossen sind.
-- Wenn ja: nächste Runde erzeugen oder Turnier beenden + Bonus vergeben.

CREATE OR REPLACE FUNCTION public._rps_advance_bracket(
  p_tournament_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_current_round  integer;
  v_pending_count  integer;
  v_winners        uuid[];
  v_winner_count   integer;
  v_i              integer;
BEGIN
  -- Höchste laufende Runde ermitteln
  SELECT MAX(round) INTO v_current_round
  FROM public.rps_matches
  WHERE tournament_id = p_tournament_id;

  -- Alle Matches der Runde abgeschlossen?
  SELECT COUNT(*) INTO v_pending_count
  FROM public.rps_matches
  WHERE tournament_id = p_tournament_id
    AND round         = v_current_round
    AND winner_id     IS NULL;

  IF v_pending_count > 0 THEN RETURN; END IF;

  -- Gewinner der Runde in Slot-Reihenfolge sammeln
  SELECT array_agg(winner_id ORDER BY match_slot) INTO v_winners
  FROM public.rps_matches
  WHERE tournament_id = p_tournament_id
    AND round         = v_current_round;

  v_winner_count := array_length(v_winners, 1);

  IF v_winner_count = 1 THEN
    -- ── Turnier abgeschlossen ─────────────────────────────────
    UPDATE public.rps_tournaments
    SET status    = 'completed',
        winner_id = v_winners[1]
    WHERE id = p_tournament_id;

    -- Bonus-Kniffel für den Sieger freischalten
    UPDATE public.profiles
    SET rps_bonus_available = true
    WHERE id = v_winners[1];

  ELSE
    -- ── Nächste Runde erzeugen ────────────────────────────────
    -- Jeweils zwei aufeinanderfolgende Gewinner bilden ein Match.
    -- Bei ungerade Anzahl: letzter Spieler bekommt Freilos.
    FOR v_i IN 1..CEIL(v_winner_count::numeric / 2)::integer LOOP
      INSERT INTO public.rps_matches (
        tournament_id,
        round,
        match_slot,
        player_a_id,
        player_b_id,
        winner_id,
        is_bye
      ) VALUES (
        p_tournament_id,
        v_current_round + 1,
        v_i - 1,
        v_winners[(v_i - 1) * 2 + 1],
        CASE
          WHEN v_winner_count > (v_i - 1) * 2 + 1
          THEN v_winners[(v_i - 1) * 2 + 2]
          ELSE NULL
        END,
        -- Freilos: nur ein Spieler → sofortige Weiterqualifikation
        CASE
          WHEN v_winner_count <= (v_i - 1) * 2 + 1
          THEN v_winners[(v_i - 1) * 2 + 1]
          ELSE NULL
        END,
        v_winner_count <= (v_i - 1) * 2 + 1
      );
    END LOOP;
  END IF;
END;
$$;

-- ── rps_start_tournament ─────────────────────────────────────
-- Erzeugt ein neues RPS-Turnier für game_id (oder gibt das heutige zurück).
-- Caller muss Spielteilnehmer sein.

DROP FUNCTION IF EXISTS public.rps_start_tournament(uuid);
DROP FUNCTION IF EXISTS public.rps_start_tournament();

CREATE OR REPLACE FUNCTION public.rps_start_tournament()
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today      date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_tournament uuid;
  v_player_cnt integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Bereits vorhandenes Turnier heute zurückgeben (idempotent)
  SELECT id INTO v_tournament
  FROM public.rps_tournaments
  WHERE (created_at AT TIME ZONE 'UTC')::date = v_today;

  IF FOUND THEN RETURN v_tournament; END IF;

  -- Spieler: alle in mindestens einem aktiven Spiel (Tester ausgeschlossen)
  SELECT COUNT(DISTINCT gp.player_id) INTO v_player_cnt
  FROM public.game_players gp
  JOIN public.games g ON g.id = gp.game_id
  WHERE g.status = 'active'
    AND gp.player_id != public._tester_uuid();

  IF v_player_cnt < 2 THEN
    RAISE EXCEPTION 'At least 2 players required';
  END IF;

  INSERT INTO public.rps_tournaments (created_by)
  VALUES (auth.uid())
  RETURNING id INTO v_tournament;

  WITH shuffled AS (
    SELECT DISTINCT ON (gp.player_id) gp.player_id,
           (ROW_NUMBER() OVER (ORDER BY random())) - 1 AS idx
    FROM public.game_players gp
    JOIN public.games g ON g.id = gp.game_id
    WHERE g.status = 'active'
      AND gp.player_id != public._tester_uuid()
  )
  INSERT INTO public.rps_matches (
    tournament_id, round, match_slot,
    player_a_id, player_b_id, winner_id, is_bye
  )
  SELECT
    v_tournament,
    1,
    a.idx / 2,
    a.player_id,
    b.player_id,
    CASE WHEN b.player_id IS NULL THEN a.player_id ELSE NULL END,
    b.player_id IS NULL
  FROM shuffled a
  LEFT JOIN shuffled b ON b.idx = a.idx + 1
  WHERE a.idx % 2 = 0;

  PERFORM public._rps_advance_bracket(v_tournament);

  RETURN v_tournament;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rps_start_tournament TO authenticated;

-- ── rps_submit_choice ─────────────────────────────────────────
-- Spieler gibt Rock/Paper/Scissors für sein laufendes Match ab.
-- Bei Unentschieden: Choices zurücksetzen → Rematch.
-- Bei Sieg: winner_id setzen + Bracket vorantreiben.

DROP FUNCTION IF EXISTS public.rps_submit_choice(uuid, text);

CREATE OR REPLACE FUNCTION public.rps_submit_choice(
  p_match_id uuid,
  p_choice   text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_match  public.rps_matches;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_choice NOT IN ('rock', 'paper', 'scissors') THEN
    RAISE EXCEPTION 'Invalid choice: %', p_choice;
  END IF;

  SELECT * INTO v_match
  FROM public.rps_matches
  WHERE id          = p_match_id
    AND (player_a_id = auth.uid() OR player_b_id = auth.uid())
    AND winner_id   IS NULL
    AND NOT is_bye
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found or already decided';
  END IF;

  -- Choice speichern
  IF v_match.player_a_id = auth.uid() THEN
    UPDATE public.rps_matches SET choice_a = p_choice
    WHERE id = p_match_id
    RETURNING * INTO v_match;
  ELSE
    UPDATE public.rps_matches SET choice_b = p_choice
    WHERE id = p_match_id
    RETURNING * INTO v_match;
  END IF;

  -- Beide Choices vorhanden → Ergebnis berechnen
  IF v_match.choice_a IS NOT NULL AND v_match.choice_b IS NOT NULL THEN
    IF v_match.choice_a = v_match.choice_b THEN
      -- Unentschieden: Rematch
      UPDATE public.rps_matches
      SET choice_a = NULL, choice_b = NULL
      WHERE id = p_match_id;
    ELSE
      -- Sieger: Rock > Scissors, Scissors > Paper, Paper > Rock
      UPDATE public.rps_matches
      SET winner_id = CASE
        WHEN (v_match.choice_a = 'rock'     AND v_match.choice_b = 'scissors')
          OR (v_match.choice_a = 'scissors' AND v_match.choice_b = 'paper')
          OR (v_match.choice_a = 'paper'    AND v_match.choice_b = 'rock')
        THEN v_match.player_a_id
        ELSE v_match.player_b_id
      END
      WHERE id = p_match_id;

      PERFORM public._rps_advance_bracket(v_match.tournament_id);
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rps_submit_choice TO authenticated;
