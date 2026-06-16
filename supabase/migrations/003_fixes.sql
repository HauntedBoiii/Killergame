-- ============================================================
-- Mörderspiel – Migration 003
-- - Entfernt doppelten update_player_stats-Trigger (B1)
-- - Fixiert confirm_kill: Status-Check, Null-Check (B1/B2)
-- - Fügt leave_game-Function hinzu (F3)
-- ============================================================

-- ── Trigger entfernen (zählt kills doppelt) ──────────────────
DROP TRIGGER IF EXISTS update_player_stats_trigger ON public.eliminations;
DROP FUNCTION IF EXISTS public.update_player_stats();

-- ── confirm_kill: Status-Check + Null-Check ──────────────────
CREATE OR REPLACE FUNCTION public.confirm_kill(elimination_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  elim          record;
  killer_assign record;
  victim_assign record;
  alive_count   int;
  v_winner_id   uuid;
BEGIN
  SELECT * INTO elim FROM public.eliminations WHERE id = elimination_id_param;

  IF elim IS NULL THEN
    RAISE EXCEPTION 'Elimination not found';
  END IF;

  IF elim.status != 'pending' THEN
    RAISE EXCEPTION 'Elimination already processed';
  END IF;

  IF elim.victim_id != auth.uid() THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.game_players
      WHERE game_id = elim.game_id AND player_id = auth.uid() AND is_admin = true
    ) THEN
      RAISE EXCEPTION 'Not authorized to confirm';
    END IF;
  END IF;

  SELECT * INTO killer_assign FROM public.assignments
  WHERE game_id = elim.game_id AND killer_id = elim.killer_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO victim_assign FROM public.assignments
  WHERE game_id = elim.game_id AND killer_id = elim.victim_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  UPDATE public.assignments SET is_active = false WHERE id = killer_assign.id;

  IF victim_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = victim_assign.id;
    IF victim_assign.target_id != elim.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id)
      VALUES (elim.game_id, elim.killer_id, victim_assign.target_id);
    END IF;
  END IF;

  -- Alle Tasks übertragen (is_used bleibt erhalten → ausgegraut bei single-use)
  UPDATE public.player_tasks
  SET player_id = elim.killer_id, acquired_from = elim.victim_id
  WHERE game_id = elim.game_id AND player_id = elim.victim_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = elim.game_id AND player_id = elim.victim_id;

  UPDATE public.game_players
  SET kills = kills + 1
  WHERE game_id = elim.game_id AND player_id = elim.killer_id;

  UPDATE public.eliminations
  SET status = 'confirmed', confirmed_by = auth.uid(), confirmed_at = now()
  WHERE id = elimination_id_param;

  UPDATE public.profiles SET total_kills = total_kills + 1 WHERE id = elim.killer_id;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players
  WHERE game_id = elim.game_id AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id FROM public.game_players
    WHERE game_id = elim.game_id AND is_alive = true LIMIT 1;

    UPDATE public.games
    SET status = 'finished', ended_at = now(), winner_id = v_winner_id
    WHERE id = elim.game_id;

    UPDATE public.profiles
    SET total_wins = total_wins + 1, total_games = total_games + 1
    WHERE id = v_winner_id;

    UPDATE public.profiles
    SET total_games = total_games + 1
    WHERE id IN (
      SELECT player_id FROM public.game_players
      WHERE game_id = elim.game_id AND player_id != v_winner_id
    );

    RETURN jsonb_build_object('game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('game_over', false);
END;
$$;

-- ── leave_game: Chain-Repair beim Verlassen eines aktiven Spiels ──
CREATE OR REPLACE FUNCTION public.leave_game(game_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id       uuid;
  v_game_status   text;
  v_my_assign     record;
  v_hunter_assign record;
  alive_count     int;
  v_winner_id     uuid;
BEGIN
  v_user_id := auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not in this game';
  END IF;

  SELECT status INTO v_game_status FROM public.games WHERE id = game_id_param;

  -- Lobby: einfaches Entfernen
  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = v_user_id;
    RETURN jsonb_build_object('left', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN
    RAISE EXCEPTION 'Game is not active';
  END IF;

  -- Mein ausgehendes Assignment (wen jage ich?)
  SELECT * INTO v_my_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  -- Wer jagt mich?
  SELECT * INTO v_hunter_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND target_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF v_my_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_my_assign.id;
  END IF;

  IF v_hunter_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_hunter_assign.id;
    -- Jäger bekommt mein Ziel, außer das würde Self-Target erzeugen (2-Spieler-Fall)
    IF v_my_assign.id IS NOT NULL AND v_my_assign.target_id != v_hunter_assign.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
      VALUES (game_id_param, v_hunter_assign.killer_id, v_my_assign.target_id, true);
    END IF;
  END IF;

  -- Tasks löschen (kein Transfer beim freiwilligen Verlassen)
  DELETE FROM public.player_tasks WHERE game_id = game_id_param AND player_id = v_user_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = game_id_param AND player_id = v_user_id;

  SELECT COUNT(*) INTO alive_count
  FROM public.game_players
  WHERE game_id = game_id_param AND is_alive = true;

  IF alive_count <= 1 THEN
    SELECT player_id INTO v_winner_id
    FROM public.game_players
    WHERE game_id = game_id_param AND is_alive = true LIMIT 1;

    UPDATE public.games
    SET status = 'finished', ended_at = now(), winner_id = v_winner_id
    WHERE id = game_id_param;

    IF v_winner_id IS NOT NULL THEN
      UPDATE public.profiles
      SET total_wins = total_wins + 1, total_games = total_games + 1
      WHERE id = v_winner_id;
    END IF;

    UPDATE public.profiles
    SET total_games = total_games + 1
    WHERE id IN (
      SELECT player_id FROM public.game_players
      WHERE game_id = game_id_param AND player_id != v_winner_id
    );

    RETURN jsonb_build_object('left', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('left', true, 'game_over', false);
END;
$$;
