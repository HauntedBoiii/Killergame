-- ============================================================
-- Moerderspiel – Complete Schema (Single Source of Truth)
-- Quellen: Schema-Dump aus Supabase + Function-Bodies aus Chat
--          + Fixes aus 003_fixes.sql + 004_security_fixes.sql
-- Fuer ein frisches Supabase-Projekt komplett ausfuehren.
-- ============================================================

-- ── Tables (aus Supabase Schema-Dump) ────────────────────────

CREATE TABLE public.profiles (
  id           uuid NOT NULL,
  username     text NOT NULL UNIQUE,
  avatar_url   text,
  total_kills  integer DEFAULT 0,
  total_games  integer DEFAULT 0,
  total_wins   integer DEFAULT 0,
  created_at   timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

CREATE TABLE public.games (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE,
  name        text NOT NULL,
  creator_id  uuid,
  status      text NOT NULL DEFAULT 'lobby',
  mode        text NOT NULL DEFAULT 'task',
  settings    jsonb NOT NULL DEFAULT '{}',
  started_at  timestamp with time zone,
  ended_at    timestamp with time zone,
  winner_id   uuid,
  created_at  timestamp with time zone DEFAULT now(),
  CONSTRAINT games_pkey PRIMARY KEY (id),
  CONSTRAINT games_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.profiles(id),
  CONSTRAINT games_winner_id_fkey  FOREIGN KEY (winner_id)  REFERENCES public.profiles(id)
);

CREATE TABLE public.game_players (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  game_id       uuid NOT NULL,
  player_id     uuid NOT NULL,
  is_admin      boolean DEFAULT false,
  is_ready      boolean DEFAULT false,
  is_alive      boolean DEFAULT true,
  kills         integer DEFAULT 0,
  joined_at     timestamp with time zone DEFAULT now(),
  eliminated_at timestamp with time zone,
  CONSTRAINT game_players_pkey      PRIMARY KEY (id),
  CONSTRAINT game_players_unique    UNIQUE (game_id, player_id),
  CONSTRAINT game_players_game_fkey FOREIGN KEY (game_id)   REFERENCES public.games(id),
  CONSTRAINT game_players_user_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id)
);

CREATE TABLE public.tasks (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  description text NOT NULL,
  category    text DEFAULT 'custom',
  difficulty  integer DEFAULT 1 CHECK (difficulty >= 1 AND difficulty <= 3),
  is_builtin  boolean DEFAULT false,
  created_by  uuid,
  created_at  timestamp with time zone DEFAULT now(),
  game_id     uuid,
  CONSTRAINT tasks_pkey           PRIMARY KEY (id),
  CONSTRAINT tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
  CONSTRAINT tasks_game_id_fkey   FOREIGN KEY (game_id)     REFERENCES public.games(id)
);

CREATE TABLE public.assignments (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  game_id     uuid NOT NULL,
  killer_id   uuid NOT NULL,
  target_id   uuid NOT NULL,
  is_active   boolean DEFAULT true,
  assigned_at timestamp with time zone DEFAULT now(),
  CONSTRAINT assignments_pkey          PRIMARY KEY (id),
  CONSTRAINT assignments_game_id_fkey  FOREIGN KEY (game_id)   REFERENCES public.games(id),
  CONSTRAINT assignments_killer_id_fkey FOREIGN KEY (killer_id) REFERENCES public.profiles(id),
  CONSTRAINT assignments_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.profiles(id)
);

CREATE TABLE public.player_tasks (
  id             uuid NOT NULL DEFAULT gen_random_uuid(),
  game_id        uuid NOT NULL,
  player_id      uuid NOT NULL,
  task_id        uuid NOT NULL,
  is_used        boolean DEFAULT false,
  acquired_from  uuid,
  created_at     timestamp with time zone DEFAULT now(),
  CONSTRAINT player_tasks_pkey               PRIMARY KEY (id),
  CONSTRAINT player_tasks_game_id_fkey       FOREIGN KEY (game_id)       REFERENCES public.games(id),
  CONSTRAINT player_tasks_player_id_fkey     FOREIGN KEY (player_id)     REFERENCES public.profiles(id),
  CONSTRAINT player_tasks_task_id_fkey       FOREIGN KEY (task_id)       REFERENCES public.tasks(id),
  CONSTRAINT player_tasks_acquired_from_fkey FOREIGN KEY (acquired_from) REFERENCES public.profiles(id)
);

CREATE TABLE public.eliminations (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  game_id       uuid NOT NULL,
  killer_id     uuid NOT NULL,
  victim_id     uuid NOT NULL,
  task_id       uuid,
  status        text DEFAULT 'pending',
  confirmed_by  uuid,
  created_at    timestamp with time zone DEFAULT now(),
  confirmed_at  timestamp with time zone,
  CONSTRAINT eliminations_pkey              PRIMARY KEY (id),
  CONSTRAINT eliminations_game_id_fkey      FOREIGN KEY (game_id)      REFERENCES public.games(id),
  CONSTRAINT eliminations_killer_id_fkey    FOREIGN KEY (killer_id)    REFERENCES public.profiles(id),
  CONSTRAINT eliminations_victim_id_fkey    FOREIGN KEY (victim_id)    REFERENCES public.profiles(id),
  CONSTRAINT eliminations_task_id_fkey      FOREIGN KEY (task_id)      REFERENCES public.tasks(id),
  CONSTRAINT eliminations_confirmed_by_fkey FOREIGN KEY (confirmed_by) REFERENCES public.profiles(id)
);

CREATE TABLE public.achievements (
  id               uuid NOT NULL DEFAULT gen_random_uuid(),
  name             text NOT NULL,
  description      text,
  icon             text,
  condition_type   text,
  condition_value  integer DEFAULT 1,
  CONSTRAINT achievements_pkey PRIMARY KEY (id)
);

CREATE TABLE public.player_achievements (
  id             uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id      uuid,
  achievement_id uuid,
  game_id        uuid,
  earned_at      timestamp with time zone DEFAULT now(),
  CONSTRAINT player_achievements_pkey               PRIMARY KEY (id),
  CONSTRAINT player_achievements_player_id_fkey     FOREIGN KEY (player_id)      REFERENCES public.profiles(id),
  CONSTRAINT player_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.achievements(id),
  CONSTRAINT player_achievements_game_id_fkey       FOREIGN KEY (game_id)        REFERENCES public.games(id)
);

CREATE TABLE public.push_subscriptions (
  id           uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL,
  subscription text NOT NULL,
  endpoint     text NOT NULL UNIQUE,
  created_at   timestamp with time zone DEFAULT now(),
  CONSTRAINT push_subscriptions_pkey        PRIMARY KEY (id),
  CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);

-- game_task_disabled (Migration 007): Admin kann Tasks pro Spiel deaktivieren
CREATE TABLE public.game_task_disabled (
  game_id    uuid NOT NULL REFERENCES public.games(id)  ON DELETE CASCADE,
  task_id    uuid NOT NULL REFERENCES public.tasks(id)  ON DELETE CASCADE,
  disabled_at timestamp with time zone DEFAULT now(),
  PRIMARY KEY (game_id, task_id)
);

-- ── Row Level Security ────────────────────────────────────────

ALTER TABLE public.profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_players        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_tasks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eliminations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "games_select" ON public.games FOR SELECT USING (
  creator_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = id AND player_id = auth.uid())
);
CREATE POLICY "games_insert" ON public.games FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "games_update" ON public.games FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = id AND player_id = auth.uid() AND is_admin = true)
);

CREATE POLICY "gp_select" ON public.game_players FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.game_players gp2 WHERE gp2.game_id = game_id AND gp2.player_id = auth.uid())
);
CREATE POLICY "gp_insert" ON public.game_players FOR INSERT WITH CHECK (player_id = auth.uid());
CREATE POLICY "gp_update" ON public.game_players FOR UPDATE USING (
  player_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = game_players.game_id AND player_id = auth.uid() AND is_admin = true)
);
CREATE POLICY "gp_delete" ON public.game_players FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.game_players admin_check
    JOIN public.games g ON g.id = admin_check.game_id
    WHERE admin_check.game_id = game_players.game_id
      AND admin_check.player_id = auth.uid()
      AND admin_check.is_admin = true
      AND g.status = 'lobby'
  )
);

CREATE POLICY "tasks_select" ON public.tasks FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "tasks_insert" ON public.tasks FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "assignments_select" ON public.assignments FOR SELECT USING (killer_id = auth.uid() AND is_active = true);
CREATE POLICY "assignments_insert" ON public.assignments FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = assignments.game_id AND player_id = auth.uid() AND is_admin = true)
);

CREATE POLICY "ptasks_select" ON public.player_tasks FOR SELECT USING (player_id = auth.uid());
CREATE POLICY "ptasks_insert" ON public.player_tasks FOR INSERT WITH CHECK (
  player_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = player_tasks.game_id AND player_id = auth.uid() AND is_admin = true)
);
CREATE POLICY "ptasks_update" ON public.player_tasks FOR UPDATE USING (player_id = auth.uid());

CREATE POLICY "elim_select" ON public.eliminations FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = eliminations.game_id AND player_id = auth.uid())
);
CREATE POLICY "elim_insert" ON public.eliminations FOR INSERT WITH CHECK (killer_id = auth.uid());
CREATE POLICY "elim_update" ON public.eliminations FOR UPDATE USING (
  victim_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = eliminations.game_id AND player_id = auth.uid() AND is_admin = true)
);

CREATE POLICY "ach_select"  ON public.achievements        FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "pach_select" ON public.player_achievements FOR SELECT USING (player_id = auth.uid());
CREATE POLICY "pach_insert" ON public.player_achievements FOR INSERT WITH CHECK (player_id = auth.uid());

CREATE POLICY "push_sub_insert" ON public.push_subscriptions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "push_sub_update" ON public.push_subscriptions FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "push_sub_select" ON public.push_subscriptions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "push_sub_delete" ON public.push_subscriptions FOR DELETE USING (user_id = auth.uid());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_subscriptions TO service_role;

ALTER TABLE public.game_task_disabled ENABLE ROW LEVEL SECURITY;
CREATE POLICY "gtd_select" ON public.game_task_disabled FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = game_task_disabled.game_id AND player_id = auth.uid())
);
CREATE POLICY "gtd_admin_write" ON public.game_task_disabled FOR ALL USING (
  EXISTS (SELECT 1 FROM public.game_players WHERE game_id = game_task_disabled.game_id AND player_id = auth.uid() AND is_admin = true)
);

-- ── Functions (Bodies aus Chat-Nachrichten + 003 Fixes) ───────

-- generate_game_code (aus Chat)
CREATE OR REPLACE FUNCTION public.generate_game_code()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result_code text := '';
  i int;
BEGIN
  FOR i IN 1..6 LOOP
    result_code := result_code || substr(chars, floor(random() * length(chars))::int + 1, 1);
  END LOOP;
  IF EXISTS (SELECT 1 FROM public.games WHERE games.code = result_code) THEN
    RETURN generate_game_code();
  END IF;
  RETURN result_code;
END;
$$;

-- handle_new_user (aus Chat)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

-- is_game_admin (aus Chat)
CREATE OR REPLACE FUNCTION public.is_game_admin(gid uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = gid AND player_id = auth.uid() AND is_admin = true
  );
$$;

-- get_my_game_ids (aus Chat)
CREATE OR REPLACE FUNCTION public.get_my_game_ids()
RETURNS SETOF uuid LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT game_id FROM public.game_players WHERE player_id = auth.uid();
$$;

-- join_game_by_code (aus Chat)
CREATE OR REPLACE FUNCTION public.join_game_by_code(p_code text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game    public.games%ROWTYPE;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Nicht eingeloggt';
  END IF;

  SELECT * INTO v_game
  FROM public.games
  WHERE code = UPPER(p_code) AND status = 'lobby'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Spiel nicht gefunden oder bereits gestartet';
  END IF;

  INSERT INTO public.game_players (game_id, player_id, is_admin, is_ready)
  VALUES (v_game.id, v_user_id, false, false)
  ON CONFLICT (game_id, player_id) DO NOTHING;

  RETURN row_to_json(v_game);
END;
$$;

-- start_game (011: Admin-Pool + game_task_disabled + Schwierigkeits-Sortierung + search_path)
CREATE OR REPLACE FUNCTION public.start_game(game_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
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

  -- Builtin tasks + Admin-eigene Tasks, abzüglich manuell deaktivierter
  -- Sortierung: Schwierigkeit 1+2 vor 3, innerhalb zufällig
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
    ORDER BY CASE WHEN t.difficulty <= 2 THEN 0 ELSE 1 END, random()
  ) INTO v_task_ids;

  SELECT ARRAY(
    SELECT player_id FROM public.game_players
    WHERE game_id = game_id_param AND is_alive = true
    ORDER BY random()
  ) INTO v_player_ids;

  v_n_players := COALESCE(array_length(v_player_ids, 1), 0);
  v_n_tasks   := COALESCE(array_length(v_task_ids, 1), 0);

  IF v_n_players < 2 THEN RAISE EXCEPTION 'Need at least 2 players'; END IF;
  IF v_n_tasks = 0   THEN RAISE EXCEPTION 'No tasks available'; END IF;

  FOR round IN 1..v_tasks_per_player LOOP
    FOR i IN 1..v_n_players LOOP
      INSERT INTO public.player_tasks (game_id, player_id, task_id)
      VALUES (game_id_param, v_player_ids[i], v_task_ids[(v_slot % v_n_tasks) + 1]);
      v_slot := v_slot + 1;
    END LOOP;
  END LOOP;

  -- Assignment-Ring: Spieler 1 → 2 → 3 → … → N → 1
  FOR i IN 1..v_n_players LOOP
    INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
    VALUES (game_id_param, v_player_ids[i], v_player_ids[(i % v_n_players) + 1], true);
  END LOOP;

  UPDATE public.games SET status = 'active', started_at = now() WHERE id = game_id_param;
END;
$$;

-- confirm_kill (012: _award_morder_lootbox + 018: FOR UPDATE race-fix + search_path)
CREATE OR REPLACE FUNCTION public.confirm_kill(elimination_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  elim          record;
  killer_assign record;
  victim_assign record;
  alive_count   int;
  v_winner_id   uuid;
BEGIN
  SELECT * INTO elim
  FROM public.eliminations
  WHERE id = elimination_id_param
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Elimination not found'; END IF;
  IF elim.status != 'pending' THEN RAISE EXCEPTION 'Elimination already processed'; END IF;

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

  IF elim.task_id IS NOT NULL THEN
    UPDATE public.player_tasks
    SET is_used = true
    WHERE game_id = elim.game_id AND player_id = elim.killer_id AND task_id = elim.task_id;
  END IF;

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
  FROM public.game_players WHERE game_id = elim.game_id AND is_alive = true;

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

    PERFORM public._award_morder_lootbox(elim.game_id, v_winner_id);

    RETURN jsonb_build_object('game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('game_over', false);
END;
$$;

-- leave_game (012: _award_morder_lootbox + search_path)
CREATE OR REPLACE FUNCTION public.leave_game(game_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id       uuid;
  v_game_status   text;
  v_is_admin      boolean;
  v_new_admin     uuid;
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

  SELECT is_admin INTO v_is_admin FROM public.game_players
  WHERE game_id = game_id_param AND player_id = v_user_id;

  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = v_user_id;

    IF v_is_admin THEN
      SELECT player_id INTO v_new_admin
      FROM public.game_players
      WHERE game_id = game_id_param
      LIMIT 1;

      IF v_new_admin IS NOT NULL THEN
        UPDATE public.game_players SET is_admin = true
        WHERE game_id = game_id_param AND player_id = v_new_admin;
      END IF;
    END IF;

    RETURN jsonb_build_object('left', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN
    RAISE EXCEPTION 'Game is not active';
  END IF;

  SELECT * INTO v_my_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO v_hunter_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND target_id = v_user_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF v_my_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_my_assign.id;
  END IF;

  IF v_hunter_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_hunter_assign.id;
    IF v_my_assign.id IS NOT NULL AND v_my_assign.target_id != v_hunter_assign.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
      VALUES (game_id_param, v_hunter_assign.killer_id, v_my_assign.target_id, true);
    END IF;
  END IF;

  DELETE FROM public.player_tasks WHERE game_id = game_id_param AND player_id = v_user_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = game_id_param AND player_id = v_user_id;

  IF v_is_admin THEN
    SELECT player_id INTO v_new_admin
    FROM public.game_players
    WHERE game_id = game_id_param AND player_id != v_user_id AND is_alive = true
    LIMIT 1;

    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

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

    IF v_winner_id IS NOT NULL THEN
      PERFORM public._award_morder_lootbox(game_id_param, v_winner_id);
    END IF;

    RETURN jsonb_build_object('left', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('left', true, 'game_over', false);
END;
$$;

-- admin_kick_player (012: _award_morder_lootbox + search_path)
CREATE OR REPLACE FUNCTION public.admin_kick_player(
  game_id_param    uuid,
  target_player_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game_status   text;
  v_target_admin  boolean;
  v_new_admin     uuid;
  v_my_assign     record;
  v_hunter_assign record;
  alive_count     int;
  v_winner_id     uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF target_player_id = auth.uid() THEN
    RAISE EXCEPTION 'Use leave_game to leave the game yourself';
  END IF;

  SELECT status INTO v_game_status FROM public.games WHERE id = game_id_param;

  SELECT is_admin INTO v_target_admin FROM public.game_players
  WHERE game_id = game_id_param AND player_id = target_player_id;

  IF v_game_status = 'lobby' THEN
    DELETE FROM public.game_players
    WHERE game_id = game_id_param AND player_id = target_player_id;
    RETURN jsonb_build_object('kicked', true, 'game_over', false);
  END IF;

  IF v_game_status != 'active' THEN
    RAISE EXCEPTION 'Game is not active or in lobby';
  END IF;

  SELECT * INTO v_my_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = target_player_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT * INTO v_hunter_assign
  FROM public.assignments
  WHERE game_id = game_id_param AND target_id = target_player_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF v_my_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_my_assign.id;
  END IF;

  IF v_hunter_assign.id IS NOT NULL THEN
    UPDATE public.assignments SET is_active = false WHERE id = v_hunter_assign.id;
    IF v_my_assign.id IS NOT NULL AND v_my_assign.target_id != v_hunter_assign.killer_id THEN
      INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
      VALUES (game_id_param, v_hunter_assign.killer_id, v_my_assign.target_id, true);
    END IF;
  END IF;

  DELETE FROM public.player_tasks WHERE game_id = game_id_param AND player_id = target_player_id;

  UPDATE public.game_players
  SET is_alive = false, eliminated_at = now()
  WHERE game_id = game_id_param AND player_id = target_player_id;

  IF v_target_admin THEN
    SELECT player_id INTO v_new_admin
    FROM public.game_players
    WHERE game_id = game_id_param AND player_id != target_player_id AND is_alive = true
    LIMIT 1;

    IF v_new_admin IS NOT NULL THEN
      UPDATE public.game_players SET is_admin = true
      WHERE game_id = game_id_param AND player_id = v_new_admin;
    END IF;
  END IF;

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

    IF v_winner_id IS NOT NULL THEN
      PERFORM public._award_morder_lootbox(game_id_param, v_winner_id);
    END IF;

    RETURN jsonb_build_object('kicked', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('kicked', true, 'game_over', false);
END;
$$;

-- report_kill (neu aus 004)
CREATE OR REPLACE FUNCTION public.report_kill(
  game_id_param   uuid,
  victim_id_param uuid,
  task_id_param   uuid DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id              uuid;
  v_tasks_are_single_use boolean;
BEGIN
  v_user_id := auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.assignments
    WHERE game_id = game_id_param
      AND killer_id = v_user_id
      AND target_id = victim_id_param
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Not your assigned target';
  END IF;

  IF task_id_param IS NOT NULL THEN
    SELECT COALESCE((settings->>'tasks_are_single_use')::boolean, false)
    INTO v_tasks_are_single_use
    FROM public.games WHERE id = game_id_param;

    IF v_tasks_are_single_use THEN
      IF EXISTS (
        SELECT 1 FROM public.player_tasks
        WHERE game_id = game_id_param
          AND player_id = v_user_id
          AND task_id = task_id_param
          AND is_used = true
      ) THEN
        RAISE EXCEPTION 'Task already used';
      END IF;
    END IF;
  END IF;

  INSERT INTO public.eliminations (game_id, killer_id, victim_id, task_id, status)
  VALUES (game_id_param, v_user_id, victim_id_param, task_id_param, 'pending');
END;
$$;

-- admin_swap_assignments (aus Chat)
CREATE OR REPLACE FUNCTION public.admin_swap_assignments(
  game_id_param uuid,
  player_a_id   uuid,
  player_b_id   uuid
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  target_a    uuid;
  target_b    uuid;
  assign_a_id uuid;
  assign_b_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT id, target_id INTO assign_a_id, target_a
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = player_a_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  SELECT id, target_id INTO assign_b_id, target_b
  FROM public.assignments
  WHERE game_id = game_id_param AND killer_id = player_b_id AND is_active = true
  ORDER BY assigned_at DESC LIMIT 1;

  IF assign_a_id IS NULL OR assign_b_id IS NULL THEN
    RAISE EXCEPTION 'One or both players have no active assignment';
  END IF;

  UPDATE public.assignments SET target_id = target_b WHERE id = assign_a_id;
  UPDATE public.assignments SET target_id = target_a WHERE id = assign_b_id;
END;
$$;

-- get_broken_assignments (aus Chat)
CREATE OR REPLACE FUNCTION public.get_broken_assignments(game_id_param uuid)
RETURNS TABLE(killer_id uuid, display_name text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = game_id_param AND player_id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT a.killer_id, p.username::text AS display_name
  FROM public.assignments a
  JOIN public.profiles p ON p.id = a.killer_id
  WHERE a.game_id = game_id_param
    AND a.is_active = true
    AND a.target_id = a.killer_id;
END;
$$;

-- reset_game_to_lobby (Migration 008)
CREATE OR REPLACE FUNCTION public.reset_game_to_lobby(game_id_param uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
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

-- ── Trigger ───────────────────────────────────────────────────

-- Neuen Auth-User automatisch als Profil anlegen
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- update_player_stats-Trigger wurde entfernt (003_fixes):
-- zaehlt kills doppelt, Logik liegt in confirm_kill

-- Push-Notification Trigger (ruft Edge Function send-push via pg_net auf)
CREATE OR REPLACE FUNCTION public.trigger_push_notification()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer <service_role_key>'
    ),
    body    := jsonb_build_object(
      'type',       TG_OP,
      'table',      TG_TABLE_NAME,
      'record',     row_to_json(NEW),
      'old_record', row_to_json(OLD)
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_eliminations ON public.eliminations;
CREATE TRIGGER push_eliminations
  AFTER INSERT OR UPDATE ON public.eliminations
  FOR EACH ROW EXECUTE FUNCTION public.trigger_push_notification();

DROP TRIGGER IF EXISTS push_games ON public.games;
CREATE TRIGGER push_games
  AFTER UPDATE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.trigger_push_notification();

-- ── Realtime ──────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.game_players;
ALTER PUBLICATION supabase_realtime ADD TABLE public.assignments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.eliminations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.player_tasks;

-- ── Kniffel (Yahtzee) Mini-Game ───────────────────────────────

CREATE TABLE public.kniffel_games (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL,
  game_date    date        NOT NULL DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date,
  status       text        NOT NULL DEFAULT 'in_progress'
                           CHECK (status IN ('in_progress', 'completed')),
  final_score  integer,
  current_dice integer[],
  held_dice    boolean[],
  roll_count            integer     NOT NULL DEFAULT 0,
  current_turn          integer     NOT NULL DEFAULT 0,
  scorecard             jsonb       NOT NULL DEFAULT '{}',
  crown_bonus_available boolean     NOT NULL DEFAULT false,
  crown_bonus_used      boolean     NOT NULL DEFAULT false,
  submitted_at timestamp with time zone,
  created_at   timestamp with time zone NOT NULL DEFAULT now(),
  updated_at   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT kniffel_games_pkey   PRIMARY KEY (id),
  CONSTRAINT kniffel_games_unique UNIQUE (user_id, game_date),
  CONSTRAINT kniffel_games_user_fkey FOREIGN KEY (user_id)
             REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.kniffel_games ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read completed games (for leaderboards);
-- each user can also always read/write their own games.
CREATE POLICY "kniffel_select" ON public.kniffel_games
  FOR SELECT USING (status = 'completed' OR user_id = auth.uid());

CREATE POLICY "kniffel_insert" ON public.kniffel_games
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "kniffel_update" ON public.kniffel_games
  FOR UPDATE USING (user_id = auth.uid() AND status = 'in_progress');

GRANT ALL ON public.kniffel_games TO authenticated;
GRANT ALL ON public.kniffel_games TO service_role;

CREATE INDEX IF NOT EXISTS idx_kniffel_completed_date_user
  ON public.kniffel_games (game_date, user_id, final_score DESC)
  WHERE status = 'completed';

-- Indizes (Migration 018): häufige Assignment- und Game-Player-Queries
CREATE INDEX IF NOT EXISTS idx_assignments_killer_active
  ON public.assignments (game_id, killer_id) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_assignments_target_active
  ON public.assignments (game_id, target_id) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_game_players_alive
  ON public.game_players (game_id) WHERE is_alive = true;

-- ── Tester-UUID: zentrale Helper-Funktion (017) ───────────────

CREATE OR REPLACE FUNCTION public._tester_uuid()
RETURNS uuid LANGUAGE sql IMMUTABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT '461045f1-83b6-44a1-bd5e-1d3214533d8d'::uuid
$$;

-- ── Helper: score a category given the dice ────────────────────

CREATE OR REPLACE FUNCTION public.compute_kniffel_category_score(
  p_category text,
  p_dice     integer[]
) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
  v_sum    integer := 0;
  v_counts integer[] := ARRAY[0,0,0,0,0,0];
  v_i      integer;
  v_is_yahtzee         boolean;
  v_has_three          boolean;
  v_has_four           boolean;
  v_has_full_house     boolean;
  v_has_small_straight boolean;
  v_has_large_straight boolean;
BEGIN
  FOR v_i IN 1..5 LOOP
    v_sum := v_sum + p_dice[v_i];
    v_counts[p_dice[v_i]] := v_counts[p_dice[v_i]] + 1;
  END LOOP;

  v_is_yahtzee         := EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c = 5);
  v_has_three          := EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c >= 3);
  v_has_four           := EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c >= 4);
  v_has_full_house     := NOT v_is_yahtzee
                          AND EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c = 2)
                          AND EXISTS (SELECT 1 FROM unnest(v_counts) c WHERE c = 3);
  v_has_small_straight := (v_counts[1]>0 AND v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0)
                       OR (v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0)
                       OR (v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0 AND v_counts[6]>0);
  v_has_large_straight := (v_counts[1]>0 AND v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0)
                       OR (v_counts[2]>0 AND v_counts[3]>0 AND v_counts[4]>0 AND v_counts[5]>0 AND v_counts[6]>0);

  RETURN CASE p_category
    WHEN 'ones'            THEN v_counts[1]
    WHEN 'twos'            THEN v_counts[2] * 2
    WHEN 'threes'          THEN v_counts[3] * 3
    WHEN 'fours'           THEN v_counts[4] * 4
    WHEN 'fives'           THEN v_counts[5] * 5
    WHEN 'sixes'           THEN v_counts[6] * 6
    WHEN 'three_of_a_kind' THEN CASE WHEN v_has_three      THEN v_sum ELSE 0 END
    WHEN 'four_of_a_kind'  THEN CASE WHEN v_has_four       THEN v_sum ELSE 0 END
    WHEN 'full_house'      THEN CASE WHEN v_has_full_house  THEN 25    ELSE 0 END
    WHEN 'small_straight'  THEN CASE WHEN v_has_small_straight THEN 30 ELSE 0 END
    WHEN 'large_straight'  THEN CASE WHEN v_has_large_straight THEN 40 ELSE 0 END
    WHEN 'yahtzee'         THEN CASE WHEN v_is_yahtzee     THEN 50    ELSE 0 END
    WHEN 'chance'          THEN v_sum
    ELSE 0
  END;
END;
$$;

-- ── Start or resume today's game (idempotent) ──────────────────
-- Tester kann täglich neu starten (017: auth-Guard + ON CONFLICT race-fix).

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

-- ── Roll dice (server-side randomness = tamper-proof) ──────────
-- Supports crown bonus 4th roll (Migration 015).

CREATE OR REPLACE FUNCTION public.kniffel_roll(
  p_game_id uuid,
  p_held    boolean[] DEFAULT '{false,false,false,false,false}'
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game           public.kniffel_games;
  v_new_dice       integer[];
  v_i              integer;
  v_held_count     integer;
  v_held_value     integer;
  v_held_all_same  boolean;
  v_nonheld_value  integer;
  v_has_crown      boolean;
BEGIN
  SELECT * INTO v_game
  FROM public.kniffel_games
  WHERE id = p_game_id AND user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game not found';
  END IF;
  IF v_game.status = 'completed' THEN
    RAISE EXCEPTION 'Game already completed';
  END IF;
  IF v_game.roll_count >= 3 AND NOT v_game.crown_bonus_available THEN
    RAISE EXCEPTION 'No rolls remaining this turn';
  END IF;
  IF v_game.game_date != (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'Not todays game';
  END IF;

  v_new_dice := COALESCE(v_game.current_dice, ARRAY[0,0,0,0,0]);
  FOR v_i IN 1..5 LOOP
    IF v_game.roll_count = 0 OR NOT p_held[v_i] THEN
      v_new_dice[v_i] := floor(random() * 6 + 1)::integer;
    END IF;
  END LOOP;

  UPDATE public.kniffel_games
  SET current_dice = v_new_dice,
      held_dice    = p_held,
      roll_count   = roll_count + 1,
      updated_at   = now()
  WHERE id = p_game_id
  RETURNING * INTO v_game;

  -- Grant crown bonus after roll 3: exactly 4 held identical dice,
  -- 5th die differs, user has crown design active, bonus not yet used.
  IF v_game.roll_count = 3
     AND NOT v_game.crown_bonus_used
     AND NOT v_game.crown_bonus_available
  THEN
    v_held_count := 0;
    FOR v_i IN 1..5 LOOP
      IF p_held[v_i] THEN v_held_count := v_held_count + 1; END IF;
    END LOOP;

    IF v_held_count = 4 THEN
      SELECT EXISTS (
        SELECT 1 FROM public.user_active_designs uad
        JOIN public.loot_items li ON li.id = uad.active_dice_id
        WHERE uad.user_id = auth.uid()
          AND li.design_key = 'crown'
      ) INTO v_has_crown;

      IF v_has_crown THEN
        v_held_value := NULL;
        FOR v_i IN 1..5 LOOP
          IF p_held[v_i] THEN
            v_held_value := v_new_dice[v_i];
            EXIT;
          END IF;
        END LOOP;

        v_held_all_same := true;
        FOR v_i IN 1..5 LOOP
          IF p_held[v_i] AND v_new_dice[v_i] != v_held_value THEN
            v_held_all_same := false;
          END IF;
        END LOOP;

        v_nonheld_value := NULL;
        FOR v_i IN 1..5 LOOP
          IF NOT p_held[v_i] THEN
            v_nonheld_value := v_new_dice[v_i];
            EXIT;
          END IF;
        END LOOP;

        IF v_held_all_same
           AND v_nonheld_value IS NOT NULL
           AND v_nonheld_value != v_held_value
        THEN
          UPDATE public.kniffel_games
          SET crown_bonus_available = true
          WHERE id = p_game_id
          RETURNING * INTO v_game;
        END IF;
      END IF;
    END IF;
  END IF;

  -- Consume crown bonus on roll 4
  IF v_game.roll_count = 4 THEN
    UPDATE public.kniffel_games
    SET crown_bonus_available = false,
        crown_bonus_used      = true
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_roll TO authenticated;

-- ── Select a category (validates score server-side) ────────────

CREATE OR REPLACE FUNCTION public.kniffel_select_category(
  p_game_id  uuid,
  p_category text,
  p_score    integer
) RETURNS public.kniffel_games LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_game          public.kniffel_games;
  v_valid_score   integer;
  v_new_scorecard jsonb;
  v_upper_sum     integer;
  v_final_score   integer;
  v_valid_cats    text[] := ARRAY[
    'ones','twos','threes','fours','fives','sixes',
    'three_of_a_kind','four_of_a_kind','full_house',
    'small_straight','large_straight','yahtzee','chance'
  ];
BEGIN
  SELECT * INTO v_game
  FROM public.kniffel_games
  WHERE id = p_game_id AND user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Game not found'; END IF;
  IF v_game.status = 'completed' THEN RAISE EXCEPTION 'Game already completed'; END IF;
  IF v_game.roll_count = 0 THEN
    RAISE EXCEPTION 'Must roll at least once before selecting a category';
  END IF;
  IF v_game.game_date != (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'Not todays game';
  END IF;
  IF NOT (p_category = ANY(v_valid_cats)) THEN
    RAISE EXCEPTION 'Invalid category: %', p_category;
  END IF;
  IF v_game.scorecard ? p_category THEN
    RAISE EXCEPTION 'Category already used: %', p_category;
  END IF;

  -- Server recomputes valid score; submitted score must be 0 (scratch) or exact
  v_valid_score := public.compute_kniffel_category_score(p_category, v_game.current_dice);
  IF p_score <> 0 AND p_score <> v_valid_score THEN
    RAISE EXCEPTION 'Invalid score % for %, expected 0 or %',
      p_score, p_category, v_valid_score;
  END IF;

  -- Store category entry with dice snapshot for auditability
  v_new_scorecard := v_game.scorecard || jsonb_build_object(
    p_category, jsonb_build_object(
      'score', p_score,
      'dice',  to_jsonb(v_game.current_dice)
    )
  );

  -- Game complete when all 13 categories are filled
  IF (SELECT count(*) FROM jsonb_each(v_new_scorecard)) = 13 THEN
    v_upper_sum := (
      SELECT COALESCE(SUM((value->>'score')::integer), 0)
      FROM jsonb_each(v_new_scorecard)
      WHERE key IN ('ones','twos','threes','fours','fives','sixes')
    );
    v_final_score := (
      SELECT COALESCE(SUM((value->>'score')::integer), 0)
      FROM jsonb_each(v_new_scorecard)
    ) + CASE WHEN v_upper_sum >= 63 THEN 35 ELSE 0 END;

    UPDATE public.kniffel_games
    SET scorecard             = v_new_scorecard,
        status                = 'completed',
        final_score           = v_final_score,
        current_dice          = NULL,
        held_dice             = NULL,
        roll_count            = 0,
        current_turn          = current_turn + 1,
        crown_bonus_available = false,
        submitted_at          = now(),
        updated_at            = now()
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  ELSE
    UPDATE public.kniffel_games
    SET scorecard             = v_new_scorecard,
        current_dice          = NULL,
        held_dice             = NULL,
        roll_count            = 0,
        current_turn          = current_turn + 1,
        crown_bonus_available = false,
        updated_at            = now()
    WHERE id = p_game_id
    RETURNING * INTO v_game;
  END IF;

  RETURN v_game;
END;
$$;
GRANT EXECUTE ON FUNCTION public.kniffel_select_category TO authenticated;

-- ── Daily leaderboard (global or filtered to one game group) ───
-- game_id added (014). Tester excluded (016). DENSE_RANK + search_path (017).

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

-- ── All-time leaderboard ───────────────────────────────────────
-- daily_losses added (009). Tester excluded (016).
-- 017: filtered_games CTE eliminiert O(n²)-Subquery + 4× Duplikat-Filter.

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

-- ── Push-Trigger: Benachrichtigung bei Kniffel-Spielende ──────
-- HINWEIS: <project-ref> und <service_role_key> ersetzen!

CREATE OR REPLACE FUNCTION public.notify_kniffel_completed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status = 'in_progress' THEN
    PERFORM net.http_post(
      url     := 'https://<project-ref>.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
                   'Content-Type',  'application/json',
                   'Authorization', 'Bearer <service_role_key>'
                 ),
      body    := jsonb_build_object(
                   'type',       TG_OP,
                   'table',      TG_TABLE_NAME,
                   'record',     row_to_json(NEW),
                   'old_record', row_to_json(OLD)
                 )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_kniffel_completed ON public.kniffel_games;
CREATE TRIGGER on_kniffel_completed
  AFTER UPDATE ON public.kniffel_games
  FOR EACH ROW EXECUTE FUNCTION public.notify_kniffel_completed();

-- ══════════════════════════════════════════════════════════════
-- LOOTBOX SYSTEM (Migration 012)
-- ══════════════════════════════════════════════════════════════

-- Seltenheiten: bronze (70%) / silver (20%) / gold (10%)
-- Karten Bronze: smoke, accent
-- Karten Silber: glass, neon, wanted
-- Karten Gold:   bond, sparks
-- Würfel Bronze: wood, neon, vegas, blood, app_red, digital, crystal

CREATE TABLE public.loot_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type  text NOT NULL CHECK (item_type IN ('card', 'dice')),
  design_key text NOT NULL,
  name       text NOT NULL,
  rarity     text NOT NULL CHECK (rarity IN ('bronze', 'silver', 'gold', 'diamond')),
  sort_order int  NOT NULL DEFAULT 0,
  UNIQUE(item_type, design_key)
);

-- Inventar: welche Items ein User besitzt
CREATE TABLE public.user_inventory (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id     uuid NOT NULL REFERENCES public.loot_items(id) ON DELETE CASCADE,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, item_id)
);

-- Credits: Bronze / Silber / Gold pro User
CREATE TABLE public.user_credits (
  user_id        uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  bronze_credits int NOT NULL DEFAULT 0 CHECK (bronze_credits >= 0),
  silver_credits int NOT NULL DEFAULT 0 CHECK (silver_credits >= 0),
  gold_credits   int NOT NULL DEFAULT 0 CHECK (gold_credits >= 0)
);

-- Ausstehende Lootboxen
-- source: 'kniffel' (available_at = nächster UTC-Mitternacht) | 'morder' (sofort)
-- status: 'pending' | 'ready' | 'opened'
CREATE TABLE public.user_lootboxes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source       text NOT NULL CHECK (source IN ('kniffel', 'morder')),
  status       text NOT NULL DEFAULT 'ready' CHECK (status IN ('pending', 'ready', 'opened')),
  available_at timestamptz NOT NULL DEFAULT now(),
  opened_at    timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Aktives Card- und Dice-Design pro User (NULL = Standard)
CREATE TABLE public.user_active_designs (
  user_id        uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active_card_id uuid REFERENCES public.loot_items(id) ON DELETE SET NULL,
  active_dice_id uuid REFERENCES public.loot_items(id) ON DELETE SET NULL
);

-- Tracking: verhindert Doppelvergabe von Kniffel-Lootboxen
CREATE TABLE public.kniffel_lootbox_awards (
  game_date  date PRIMARY KEY,
  winner_id  uuid REFERENCES auth.users(id),
  awarded_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.kniffel_lootbox_awards ENABLE ROW LEVEL SECURITY;
-- Kein direkter Client-Zugriff; Schreiben nur über SECURITY DEFINER-Funktionen.

-- ── RLS Lootbox-Tabellen ──────────────────────────────────────

ALTER TABLE public.loot_items         ENABLE ROW LEVEL SECURITY;
CREATE POLICY "loot_items_read" ON public.loot_items
  FOR SELECT TO authenticated USING (true);

ALTER TABLE public.user_inventory     ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_inventory_own" ON public.user_inventory
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.user_credits       ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_credits_own" ON public.user_credits
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.user_lootboxes     ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_lootboxes_own" ON public.user_lootboxes
  FOR SELECT TO authenticated USING (user_id = auth.uid());

ALTER TABLE public.user_active_designs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_active_designs_own" ON public.user_active_designs
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- kniffel_lootbox_awards: kein direkter Client-Zugriff (SECURITY DEFINER only)

-- ── Seed: Loot-Items (012 + 013 Kronenmesser) ─────────────────

INSERT INTO public.loot_items (item_type, design_key, name, rarity, sort_order) VALUES
  ('card', 'smoke',   'Dark Smoke',       'bronze',  10),
  ('card', 'accent',  'Farbwechsel',      'bronze',  20),
  ('card', 'glass',   'Glas mit Shimmer', 'silver',  30),
  ('card', 'neon',    'Neon Rand',        'silver',  40),
  ('card', 'wanted',  'Steckbrief',       'silver',  50),
  ('card', 'bond',    'Agent 007',        'gold',    60),
  ('card', 'sparks',  'Funken',           'gold',    70),
  ('dice', 'wood',    'Holz',             'bronze',  10),
  ('dice', 'neon',    'Neon',             'bronze',  20),
  ('dice', 'vegas',   'Vegas',            'bronze',  30),
  ('dice', 'blood',   'Blut',             'bronze',  40),
  ('dice', 'app_red', 'App-Rot',          'bronze',  50),
  ('dice', 'digital', 'Digital',          'bronze',  60),
  ('dice', 'crystal', 'Kristall',         'bronze',  70),
  ('dice', 'crown',   'Kronenmesser',     'diamond', 100);

-- ── Lootbox-Funktionen (012 + 018: search_path + FOR UPDATE-Fixes) ───

CREATE OR REPLACE FUNCTION public._ensure_loot_rows(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_credits (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_active_designs (user_id) VALUES (p_user_id) ON CONFLICT DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_loot_state()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  PERFORM public._ensure_loot_rows(v_user_id);

  RETURN jsonb_build_object(
    'lootboxes', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id',           id,
        'source',       source,
        'status',       CASE WHEN status = 'pending' AND available_at <= now() THEN 'ready' ELSE status END,
        'available_at', available_at,
        'created_at',   created_at
      ) ORDER BY created_at)
      FROM public.user_lootboxes
      WHERE user_id = v_user_id AND status != 'opened'
    ), '[]'::jsonb),
    'inventory', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'item_id',     ui.item_id,
        'design_key',  li.design_key,
        'item_type',   li.item_type,
        'name',        li.name,
        'rarity',      li.rarity,
        'unlocked_at', ui.unlocked_at
      ) ORDER BY li.item_type, li.sort_order)
      FROM public.user_inventory ui
      JOIN public.loot_items li ON li.id = ui.item_id
      WHERE ui.user_id = v_user_id
    ), '[]'::jsonb),
    'credits', COALESCE((
      SELECT jsonb_build_object('bronze', bronze_credits, 'silver', silver_credits, 'gold', gold_credits)
      FROM public.user_credits WHERE user_id = v_user_id
    ), jsonb_build_object('bronze', 0, 'silver', 0, 'gold', 0)),
    'active_card_key', (
      SELECT li.design_key FROM public.user_active_designs uad
      JOIN public.loot_items li ON li.id = uad.active_card_id
      WHERE uad.user_id = v_user_id
    ),
    'active_dice_key', (
      SELECT li.design_key FROM public.user_active_designs uad
      JOIN public.loot_items li ON li.id = uad.active_dice_id
      WHERE uad.user_id = v_user_id
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_loot_state TO authenticated;

-- open_lootbox (013: Diamond 0.5 %, Trostpreis Gold-Credit bei bereits besessen)
CREATE OR REPLACE FUNCTION public.open_lootbox(p_lootbox_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id    uuid := auth.uid();
  v_box        public.user_lootboxes;
  v_roll       float;
  v_rarity     text;
  v_credit_rar text;
  v_item       public.loot_items;
BEGIN
  SELECT * INTO v_box
  FROM public.user_lootboxes
  WHERE id = p_lootbox_id AND user_id = v_user_id AND status != 'opened'
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Lootbox nicht gefunden oder bereits geöffnet'; END IF;
  IF v_box.available_at > now() THEN RAISE EXCEPTION 'Lootbox noch nicht verfügbar'; END IF;

  PERFORM public._ensure_loot_rows(v_user_id);

  v_roll   := random();
  v_rarity := CASE
    WHEN v_roll < 0.700 THEN 'bronze'
    WHEN v_roll < 0.900 THEN 'silver'
    WHEN v_roll < 0.995 THEN 'gold'
    ELSE                      'diamond'
  END;

  SELECT li.* INTO v_item
  FROM public.loot_items li
  WHERE li.rarity = v_rarity
    AND NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      WHERE ui.user_id = v_user_id AND ui.item_id = li.id
    )
  ORDER BY random()
  LIMIT 1;

  UPDATE public.user_lootboxes SET status = 'opened', opened_at = now() WHERE id = p_lootbox_id;

  IF v_item.id IS NULL THEN
    v_credit_rar := CASE WHEN v_rarity = 'diamond' THEN 'gold' ELSE v_rarity END;
    IF v_credit_rar = 'bronze' THEN
      UPDATE public.user_credits SET bronze_credits = bronze_credits + 1 WHERE user_id = v_user_id;
    ELSIF v_credit_rar = 'silver' THEN
      UPDATE public.user_credits SET silver_credits = silver_credits + 1 WHERE user_id = v_user_id;
    ELSE
      UPDATE public.user_credits SET gold_credits = gold_credits + 1 WHERE user_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('type', 'credit', 'rarity', v_credit_rar);
  ELSE
    INSERT INTO public.user_inventory (user_id, item_id) VALUES (v_user_id, v_item.id);
    RETURN jsonb_build_object(
      'type', 'item', 'rarity', v_rarity,
      'item', jsonb_build_object(
        'item_id', v_item.id, 'design_key', v_item.design_key,
        'item_type', v_item.item_type, 'name', v_item.name, 'rarity', v_item.rarity
      )
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.open_lootbox TO authenticated;

CREATE OR REPLACE FUNCTION public.trade_credits(p_rarity text, p_direction text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_c       public.user_credits;
  v_new     public.user_credits;
BEGIN
  SELECT * INTO v_c FROM public.user_credits WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Kein Credits-Eintrag'; END IF;

  IF p_direction = 'up' THEN
    IF p_rarity = 'bronze' THEN
      IF v_c.bronze_credits < 2 THEN RAISE EXCEPTION 'Nicht genug Bronze-Credits'; END IF;
      UPDATE public.user_credits SET bronze_credits = bronze_credits - 2, silver_credits = silver_credits + 1
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSIF p_rarity = 'silver' THEN
      IF v_c.silver_credits < 2 THEN RAISE EXCEPTION 'Nicht genug Silber-Credits'; END IF;
      UPDATE public.user_credits SET silver_credits = silver_credits - 2, gold_credits = gold_credits + 1
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSE
      RAISE EXCEPTION 'Gold kann nicht aufgewertet werden';
    END IF;
  ELSIF p_direction = 'down' THEN
    IF p_rarity = 'gold' THEN
      IF v_c.gold_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Gold-Credits'; END IF;
      UPDATE public.user_credits SET gold_credits = gold_credits - 1, silver_credits = silver_credits + 2
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSIF p_rarity = 'silver' THEN
      IF v_c.silver_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Silber-Credits'; END IF;
      UPDATE public.user_credits SET silver_credits = silver_credits - 1, bronze_credits = bronze_credits + 2
      WHERE user_id = v_user_id RETURNING * INTO v_new;
    ELSE
      RAISE EXCEPTION 'Bronze kann nicht abgewertet werden';
    END IF;
  ELSE
    RAISE EXCEPTION 'Ungültige Richtung (up/down erwartet)';
  END IF;

  RETURN jsonb_build_object('bronze', v_new.bronze_credits, 'silver', v_new.silver_credits, 'gold', v_new.gold_credits);
END;
$$;
GRANT EXECUTE ON FUNCTION public.trade_credits TO authenticated;

-- spend_credits (018: FOR UPDATE → verhindert TOCTOU bei parallelen Requests)
CREATE OR REPLACE FUNCTION public.spend_credits(p_rarity text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_c       public.user_credits;
  v_item    public.loot_items;
BEGIN
  PERFORM public._ensure_loot_rows(v_user_id);

  SELECT * INTO v_c FROM public.user_credits WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Kein Credits-Eintrag'; END IF;

  IF p_rarity = 'bronze' THEN
    IF v_c.bronze_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Bronze-Credits'; END IF;
  ELSIF p_rarity = 'silver' THEN
    IF v_c.silver_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Silber-Credits'; END IF;
  ELSIF p_rarity = 'gold' THEN
    IF v_c.gold_credits < 1 THEN RAISE EXCEPTION 'Nicht genug Gold-Credits'; END IF;
  ELSE
    RAISE EXCEPTION 'Ungültige Seltenheit';
  END IF;

  SELECT li.* INTO v_item
  FROM public.loot_items li
  WHERE li.rarity = p_rarity
    AND NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      WHERE ui.user_id = v_user_id AND ui.item_id = li.id
    )
  ORDER BY random()
  LIMIT 1;

  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'Alle Items dieser Seltenheit bereits freigeschaltet';
  END IF;

  IF p_rarity = 'bronze' THEN
    UPDATE public.user_credits SET bronze_credits = bronze_credits - 1 WHERE user_id = v_user_id;
  ELSIF p_rarity = 'silver' THEN
    UPDATE public.user_credits SET silver_credits = silver_credits - 1 WHERE user_id = v_user_id;
  ELSE
    UPDATE public.user_credits SET gold_credits = gold_credits - 1 WHERE user_id = v_user_id;
  END IF;

  INSERT INTO public.user_inventory (user_id, item_id) VALUES (v_user_id, v_item.id);

  RETURN jsonb_build_object(
    'item', jsonb_build_object(
      'item_id', v_item.id, 'design_key', v_item.design_key,
      'item_type', v_item.item_type, 'name', v_item.name, 'rarity', v_item.rarity
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.spend_credits TO authenticated;

CREATE OR REPLACE FUNCTION public.set_active_design(p_item_id uuid, p_type text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF p_item_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      JOIN public.loot_items li ON li.id = ui.item_id
      WHERE ui.user_id = v_user_id AND ui.item_id = p_item_id AND li.item_type = p_type
    ) THEN
      RAISE EXCEPTION 'Item nicht im Inventar oder falscher Typ';
    END IF;
  END IF;

  INSERT INTO public.user_active_designs (user_id, active_card_id, active_dice_id)
  VALUES (
    v_user_id,
    CASE WHEN p_type = 'card' THEN p_item_id ELSE NULL END,
    CASE WHEN p_type = 'dice' THEN p_item_id ELSE NULL END
  )
  ON CONFLICT (user_id) DO UPDATE SET
    active_card_id = CASE WHEN p_type = 'card' THEN p_item_id ELSE public.user_active_designs.active_card_id END,
    active_dice_id = CASE WHEN p_type = 'dice' THEN p_item_id ELSE public.user_active_designs.active_dice_id END;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_active_design TO authenticated;

CREATE OR REPLACE FUNCTION public._award_morder_lootbox(p_game_id uuid, p_winner_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.game_players WHERE game_id = p_game_id;
  IF v_count >= 8 THEN
    INSERT INTO public.user_lootboxes (user_id, source, status, available_at)
    VALUES (p_winner_id, 'morder', 'ready', now());
  END IF;
END;
$$;

-- _process_kniffel_lootboxes (018: Tester-Filter → kein Tages-Lootbox für Tester)
CREATE OR REPLACE FUNCTION public._process_kniffel_lootboxes()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_today  date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_rec    record;
  v_winner uuid;
BEGIN
  FOR v_rec IN
    SELECT DISTINCT kg.game_date
    FROM public.kniffel_games kg
    WHERE kg.game_date < v_today
      AND kg.game_date >= v_today - INTERVAL '30 days'
      AND kg.status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM public.kniffel_lootbox_awards kla
        WHERE kla.game_date = kg.game_date
      )
    ORDER BY kg.game_date
  LOOP
    SELECT kg.user_id INTO v_winner
    FROM public.kniffel_games kg
    WHERE kg.game_date = v_rec.game_date
      AND kg.status    = 'completed'
      AND kg.user_id  != public._tester_uuid()
    ORDER BY kg.final_score DESC, kg.submitted_at ASC
    LIMIT 1;

    IF v_winner IS NOT NULL THEN
      INSERT INTO public.kniffel_lootbox_awards (game_date, winner_id)
      VALUES (v_rec.game_date, v_winner)
      ON CONFLICT DO NOTHING;

      INSERT INTO public.user_lootboxes (user_id, source, status, available_at)
      VALUES (v_winner, 'kniffel', 'ready', now());
    END IF;
  END LOOP;
END;
$$;
