-- ============================================================
-- 022: RPS Deadlines, Timeouts & Push-Notifications
--
-- A) rps_matches: deadline-Spalte
-- B) _rps_send_push: Hilfsfunktion für Push-Calls
-- C) _rps_advance_bracket: Bronze Credit + Push für Sieger
-- D) rps_start_tournament: deadline beim Bracket-Aufbau
-- E) rps_submit_choice: opponent_chose Push
-- F) rps_process_timeouts: Timeout-Logik + Warnungen
-- G) pg_cron: alle 5 Minuten rps_process_timeouts aufrufen
-- ============================================================

-- ── A: deadline-Spalte ───────────────────────────────────────

ALTER TABLE public.rps_matches
  ADD COLUMN IF NOT EXISTS deadline timestamptz;

-- ── B: _rps_send_push ────────────────────────────────────────
-- Schickt eine Push-Notification an einen einzelnen User.

CREATE OR REPLACE FUNCTION public._rps_send_push(
  p_user_id   uuid,
  p_event     text,
  p_payload   jsonb DEFAULT '{}'::jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  BEGIN
    PERFORM net.http_post(
      url     := 'https://<project-ref>.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
                   'Content-Type',  'application/json',
                   'Authorization', 'Bearer <service_role_key>'
                 ),
      body    := jsonb_build_object(
                   'type',    'rps',
                   'event',   p_event,
                   'user_id', p_user_id,
                   'payload', p_payload
                 )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

-- ── C: _rps_advance_bracket (neu) ────────────────────────────
-- Wie vorher, aber:
--   • deadline bei neuen Matches wenn nach 12:00 UTC
--   • Bronze Credit + rps_bonus_available beim Turniersieg
--   • Push: match_started, tournament_won

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
  v_new_match_id   uuid;
  v_deadline       timestamptz;
  v_utc_hour       integer;
BEGIN
  SELECT MAX(round) INTO v_current_round
  FROM public.rps_matches
  WHERE tournament_id = p_tournament_id;

  SELECT COUNT(*) INTO v_pending_count
  FROM public.rps_matches
  WHERE tournament_id = p_tournament_id
    AND round         = v_current_round
    AND winner_id     IS NULL;

  IF v_pending_count > 0 THEN RETURN; END IF;

  SELECT array_agg(winner_id ORDER BY match_slot) INTO v_winners
  FROM public.rps_matches
  WHERE tournament_id = p_tournament_id
    AND round         = v_current_round;

  v_winner_count := array_length(v_winners, 1);

  -- Deadline für neue Matches: 2h wenn nach 12:00 UTC, sonst NULL
  v_utc_hour := EXTRACT(HOUR FROM NOW() AT TIME ZONE 'UTC');
  v_deadline := CASE WHEN v_utc_hour >= 12 THEN NOW() + interval '2 hours' ELSE NULL END;

  IF v_winner_count = 1 THEN
    -- ── Turniersieg ──────────────────────────────────────────
    UPDATE public.rps_tournaments
    SET status    = 'completed',
        winner_id = v_winners[1]
    WHERE id = p_tournament_id;

    -- Bonus-Kniffel freischalten
    UPDATE public.profiles
    SET rps_bonus_available = true
    WHERE id = v_winners[1];

    -- Bronze Credit für den Sieger
    INSERT INTO public.user_credits (user_id, bronze_credits)
    VALUES (v_winners[1], 1)
    ON CONFLICT (user_id) DO UPDATE
      SET bronze_credits = public.user_credits.bronze_credits + 1;

    -- Push: Turniersieg
    PERFORM public._rps_send_push(
      v_winners[1], 'tournament_won',
      jsonb_build_object('tournament_id', p_tournament_id)
    );

  ELSE
    -- ── Nächste Runde ────────────────────────────────────────
    FOR v_i IN 1..CEIL(v_winner_count::numeric / 2)::integer LOOP
      INSERT INTO public.rps_matches (
        tournament_id, round, match_slot,
        player_a_id, player_b_id,
        winner_id, is_bye, deadline
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
        CASE
          WHEN v_winner_count <= (v_i - 1) * 2 + 1
          THEN v_winners[(v_i - 1) * 2 + 1]
          ELSE NULL
        END,
        v_winner_count <= (v_i - 1) * 2 + 1,
        CASE WHEN v_winner_count <= (v_i - 1) * 2 + 1 THEN NULL ELSE v_deadline END
      )
      RETURNING id INTO v_new_match_id;

      -- Push: match_started an beide Spieler (wenn kein Freilos)
      IF v_winner_count > (v_i - 1) * 2 + 1 THEN
        PERFORM public._rps_send_push(
          v_winners[(v_i - 1) * 2 + 1], 'match_started',
          jsonb_build_object('match_id', v_new_match_id, 'tournament_id', p_tournament_id)
        );
        PERFORM public._rps_send_push(
          v_winners[(v_i - 1) * 2 + 2], 'match_started',
          jsonb_build_object('match_id', v_new_match_id, 'tournament_id', p_tournament_id)
        );
      END IF;
    END LOOP;
  END IF;
END;
$$;

-- ── D: rps_start_tournament (neu: deadline beim Start) ───────

DROP FUNCTION IF EXISTS public.rps_start_tournament(uuid);
DROP FUNCTION IF EXISTS public.rps_start_tournament();

CREATE OR REPLACE FUNCTION public.rps_start_tournament()
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today      date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_tournament uuid;
  v_player_cnt integer;
  v_deadline   timestamptz;
  v_utc_hour   integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT id INTO v_tournament
  FROM public.rps_tournaments
  WHERE (created_at AT TIME ZONE 'UTC')::date = v_today;
  IF FOUND THEN RETURN v_tournament; END IF;

  SELECT COUNT(DISTINCT gp.player_id) INTO v_player_cnt
  FROM public.game_players gp
  JOIN public.games g ON g.id = gp.game_id
  WHERE g.status = 'active'
    AND gp.player_id != public._tester_uuid();

  IF v_player_cnt < 2 THEN RAISE EXCEPTION 'At least 2 players required'; END IF;

  INSERT INTO public.rps_tournaments (created_by)
  VALUES (auth.uid())
  RETURNING id INTO v_tournament;

  v_utc_hour := EXTRACT(HOUR FROM NOW() AT TIME ZONE 'UTC');
  v_deadline := CASE WHEN v_utc_hour >= 12 THEN NOW() + interval '2 hours' ELSE NULL END;

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
    player_a_id, player_b_id, winner_id, is_bye, deadline
  )
  SELECT
    v_tournament, 1, a.idx / 2,
    a.player_id,
    b.player_id,
    CASE WHEN b.player_id IS NULL THEN a.player_id ELSE NULL END,
    b.player_id IS NULL,
    CASE WHEN b.player_id IS NULL THEN NULL ELSE v_deadline END
  FROM shuffled a
  LEFT JOIN shuffled b ON b.idx = a.idx + 1
  WHERE a.idx % 2 = 0;

  PERFORM public._rps_advance_bracket(v_tournament);
  RETURN v_tournament;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rps_start_tournament TO authenticated;

-- ── E: rps_submit_choice (neu: opponent_chose Push) ──────────

DROP FUNCTION IF EXISTS public.rps_submit_choice(uuid, text);

CREATE OR REPLACE FUNCTION public.rps_submit_choice(
  p_match_id uuid,
  p_choice   text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_match     public.rps_matches;
  v_opponent  uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  IF p_choice NOT IN ('rock', 'paper', 'scissors') THEN
    RAISE EXCEPTION 'Invalid choice: %', p_choice;
  END IF;

  SELECT * INTO v_match
  FROM public.rps_matches
  WHERE id           = p_match_id
    AND (player_a_id = auth.uid() OR player_b_id = auth.uid())
    AND winner_id    IS NULL
    AND NOT is_bye
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found or already decided';
  END IF;

  IF v_match.player_a_id = auth.uid() THEN
    UPDATE public.rps_matches SET choice_a = p_choice
    WHERE id = p_match_id RETURNING * INTO v_match;
    v_opponent := v_match.player_b_id;
  ELSE
    UPDATE public.rps_matches SET choice_b = p_choice
    WHERE id = p_match_id RETURNING * INTO v_match;
    v_opponent := v_match.player_a_id;
  END IF;

  -- Gegner benachrichtigen (nur wenn er noch nicht gewählt hat)
  IF v_opponent IS NOT NULL THEN
    IF (v_match.player_a_id = auth.uid() AND v_match.choice_b IS NULL)
    OR (v_match.player_b_id = auth.uid() AND v_match.choice_a IS NULL) THEN
      PERFORM public._rps_send_push(
        v_opponent, 'opponent_chose',
        jsonb_build_object('match_id', p_match_id, 'tournament_id', v_match.tournament_id)
      );
    END IF;
  END IF;

  IF v_match.choice_a IS NOT NULL AND v_match.choice_b IS NOT NULL THEN
    IF v_match.choice_a = v_match.choice_b THEN
      -- Unentschieden: Rematch, deadline zurücksetzen
      UPDATE public.rps_matches
      SET choice_a = NULL,
          choice_b = NULL,
          deadline = CASE
            WHEN EXTRACT(HOUR FROM NOW() AT TIME ZONE 'UTC') >= 12
            THEN NOW() + interval '2 hours'
            ELSE NULL
          END
      WHERE id = p_match_id;

      -- Beide über Rematch informieren
      PERFORM public._rps_send_push(
        v_match.player_a_id, 'match_draw',
        jsonb_build_object('match_id', p_match_id, 'tournament_id', v_match.tournament_id)
      );
      PERFORM public._rps_send_push(
        v_match.player_b_id, 'match_draw',
        jsonb_build_object('match_id', p_match_id, 'tournament_id', v_match.tournament_id)
      );
    ELSE
      DECLARE
        v_winner uuid;
        v_loser  uuid;
      BEGIN
        v_winner := CASE
          WHEN (v_match.choice_a = 'rock'     AND v_match.choice_b = 'scissors')
            OR (v_match.choice_a = 'scissors' AND v_match.choice_b = 'paper')
            OR (v_match.choice_a = 'paper'    AND v_match.choice_b = 'rock')
          THEN v_match.player_a_id
          ELSE v_match.player_b_id
        END;
        v_loser := CASE WHEN v_winner = v_match.player_a_id
                        THEN v_match.player_b_id
                        ELSE v_match.player_a_id END;

        UPDATE public.rps_matches SET winner_id = v_winner WHERE id = p_match_id;

        PERFORM public._rps_send_push(
          v_winner, 'match_won',
          jsonb_build_object('match_id', p_match_id, 'tournament_id', v_match.tournament_id)
        );
        PERFORM public._rps_send_push(
          v_loser, 'match_lost',
          jsonb_build_object('match_id', p_match_id, 'tournament_id', v_match.tournament_id)
        );

        PERFORM public._rps_advance_bracket(v_match.tournament_id);
      END;
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rps_submit_choice TO authenticated;

-- ── F: rps_process_timeouts ──────────────────────────────────
-- Wird per pg_cron alle 5 Minuten aufgerufen.
-- 1) Matches ohne deadline nach 12 UTC → deadline setzen
-- 2) Abgelaufene Matches → Timeout-Sieger ermitteln + Bracket
-- 3) Warnungen: 1h und 15min vor Ablauf

CREATE OR REPLACE FUNCTION public.rps_process_timeouts()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_match     public.rps_matches;
  v_winner    uuid;
  v_loser     uuid;
  v_utc_hour  integer;
BEGIN
  v_utc_hour := EXTRACT(HOUR FROM NOW() AT TIME ZONE 'UTC');

  -- 1) Matches aktivieren: nach 12 UTC, noch kein deadline, noch kein winner
  IF v_utc_hour >= 12 THEN
    UPDATE public.rps_matches
    SET deadline = NOW() + interval '2 hours'
    WHERE deadline  IS NULL
      AND winner_id IS NULL
      AND NOT is_bye
      AND EXISTS (
        SELECT 1 FROM public.rps_tournaments t
        WHERE t.id = tournament_id AND t.status = 'in_progress'
      );
  END IF;

  -- 2) Abgelaufene Matches abarbeiten
  FOR v_match IN
    SELECT * FROM public.rps_matches
    WHERE deadline  < NOW()
      AND winner_id IS NULL
      AND NOT is_bye
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Sieger: wer gewählt hat; bei keinem → zufällig
    v_winner := CASE
      WHEN v_match.choice_a IS NOT NULL AND v_match.choice_b IS NULL THEN v_match.player_a_id
      WHEN v_match.choice_b IS NOT NULL AND v_match.choice_a IS NULL THEN v_match.player_b_id
      ELSE CASE WHEN random() < 0.5 THEN v_match.player_a_id ELSE v_match.player_b_id END
    END;
    v_loser := CASE WHEN v_winner = v_match.player_a_id
                    THEN v_match.player_b_id
                    ELSE v_match.player_a_id END;

    UPDATE public.rps_matches SET winner_id = v_winner WHERE id = v_match.id;

    PERFORM public._rps_send_push(
      v_winner, 'match_won',
      jsonb_build_object('match_id', v_match.id, 'timeout', true,
                         'tournament_id', v_match.tournament_id)
    );
    PERFORM public._rps_send_push(
      v_loser, 'match_lost',
      jsonb_build_object('match_id', v_match.id, 'timeout', true,
                         'tournament_id', v_match.tournament_id)
    );

    PERFORM public._rps_advance_bracket(v_match.tournament_id);
  END LOOP;

  -- 3a) 1-Stunden-Warnung: deadline zwischen 55min und 65min entfernt
  FOR v_match IN
    SELECT * FROM public.rps_matches
    WHERE deadline  BETWEEN NOW() + interval '55 minutes'
                        AND NOW() + interval '65 minutes'
      AND winner_id IS NULL
      AND NOT is_bye
  LOOP
    IF v_match.choice_a IS NULL THEN
      PERFORM public._rps_send_push(
        v_match.player_a_id, 'match_warning_1h',
        jsonb_build_object('match_id', v_match.id, 'tournament_id', v_match.tournament_id)
      );
    END IF;
    IF v_match.choice_b IS NULL AND v_match.player_b_id IS NOT NULL THEN
      PERFORM public._rps_send_push(
        v_match.player_b_id, 'match_warning_1h',
        jsonb_build_object('match_id', v_match.id, 'tournament_id', v_match.tournament_id)
      );
    END IF;
  END LOOP;

  -- 3b) 15-Minuten-Warnung: deadline zwischen 10min und 20min entfernt
  FOR v_match IN
    SELECT * FROM public.rps_matches
    WHERE deadline  BETWEEN NOW() + interval '10 minutes'
                        AND NOW() + interval '20 minutes'
      AND winner_id IS NULL
      AND NOT is_bye
  LOOP
    IF v_match.choice_a IS NULL THEN
      PERFORM public._rps_send_push(
        v_match.player_a_id, 'match_warning_15m',
        jsonb_build_object('match_id', v_match.id, 'tournament_id', v_match.tournament_id)
      );
    END IF;
    IF v_match.choice_b IS NULL AND v_match.player_b_id IS NOT NULL THEN
      PERFORM public._rps_send_push(
        v_match.player_b_id, 'match_warning_15m',
        jsonb_build_object('match_id', v_match.id, 'tournament_id', v_match.tournament_id)
      );
    END IF;
  END LOOP;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rps_process_timeouts TO authenticated;

-- ── G: pg_cron ───────────────────────────────────────────────

SELECT cron.schedule(
  'rps-process-timeouts',
  '*/5 * * * *',
  $$SELECT public.rps_process_timeouts();$$
);
