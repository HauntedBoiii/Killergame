-- Tasks are now owned by admin (created_by), not tied to a specific game.
-- game_id on tasks becomes unused for new tasks (kept for backwards compat).

-- Per-game disable list: tasks in this table are excluded from that game's pool
CREATE TABLE public.game_task_disabled (
  game_id uuid NOT NULL REFERENCES public.games(id)  ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.tasks(id)   ON DELETE CASCADE,
  PRIMARY KEY (game_id, task_id)
);

ALTER TABLE public.game_task_disabled ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gtd_select" ON public.game_task_disabled FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.game_players
          WHERE game_id = game_task_disabled.game_id
            AND player_id = auth.uid() AND is_admin = true)
);
CREATE POLICY "gtd_insert" ON public.game_task_disabled FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.game_players
          WHERE game_id = game_task_disabled.game_id
            AND player_id = auth.uid() AND is_admin = true)
);
CREATE POLICY "gtd_delete" ON public.game_task_disabled FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.game_players
          WHERE game_id = game_task_disabled.game_id
            AND player_id = auth.uid() AND is_admin = true)
);

-- Update start_game: use admin-owned tasks + builtins, minus disabled ones
CREATE OR REPLACE FUNCTION public.start_game(game_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tasks_per_player  int;
  v_task_ids          uuid[];
  v_player_ids        uuid[];
  v_n_players         int;
  v_n_tasks           int;
  v_slot              int := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE((settings->>'initial_tasks_per_player')::int, 1)
  INTO v_tasks_per_player
  FROM public.games WHERE id = game_id_param;

  SELECT ARRAY(
    SELECT t.id FROM public.tasks t
    WHERE (
      t.is_builtin = true
      OR t.created_by IN (
        SELECT player_id FROM public.game_players
        WHERE game_id = game_id_param AND is_admin = true
      )
    )
    AND t.id NOT IN (
      SELECT task_id FROM public.game_task_disabled WHERE game_id = game_id_param
    )
    ORDER BY random()
  ) INTO v_task_ids;

  SELECT ARRAY(
    SELECT player_id FROM public.game_players
    WHERE game_id = game_id_param AND is_alive = true
    ORDER BY random()
  ) INTO v_player_ids;

  v_n_players := COALESCE(array_length(v_player_ids, 1), 0);
  v_n_tasks   := COALESCE(array_length(v_task_ids, 1), 0);

  IF v_n_players < 2 THEN
    RAISE EXCEPTION 'Need at least 2 players';
  END IF;
  IF v_n_tasks = 0 THEN
    RAISE EXCEPTION 'No tasks available';
  END IF;

  FOR round IN 1..v_tasks_per_player LOOP
    FOR i IN 1..v_n_players LOOP
      INSERT INTO public.player_tasks (game_id, player_id, task_id)
      VALUES (
        game_id_param,
        v_player_ids[i],
        v_task_ids[(v_slot % v_n_tasks) + 1]
      );
      v_slot := v_slot + 1;
    END LOOP;
  END LOOP;

  UPDATE public.games SET status = 'active', started_at = now() WHERE id = game_id_param;
END;
$$;
