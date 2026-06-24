CREATE OR REPLACE FUNCTION public.reset_game_to_lobby(game_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  DELETE FROM public.assignments  WHERE game_id = game_id_param;
  DELETE FROM public.player_tasks WHERE game_id = game_id_param;
  DELETE FROM public.eliminations WHERE game_id = game_id_param;

  UPDATE public.game_players
  SET is_alive = true, kills = 0, is_ready = false
  WHERE game_id = game_id_param;

  UPDATE public.games
  SET status = 'lobby', started_at = null
  WHERE id = game_id_param;
END;
$$;
