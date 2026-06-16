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
CREATE POLICY "push_sub_select" ON public.push_subscriptions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "push_sub_delete" ON public.push_subscriptions FOR DELETE USING (user_id = auth.uid());

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
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
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
RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.game_players
    WHERE game_id = gid AND player_id = auth.uid() AND is_admin = true
  );
$$;

-- get_my_game_ids (aus Chat)
CREATE OR REPLACE FUNCTION public.get_my_game_ids()
RETURNS SETOF uuid LANGUAGE sql SECURITY DEFINER AS $$
  SELECT game_id FROM public.game_players WHERE player_id = auth.uid();
$$;

-- join_game_by_code (aus Chat)
CREATE OR REPLACE FUNCTION public.join_game_by_code(p_code text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_game    games%ROWTYPE;
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

-- start_game (aus Chat)
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
    SELECT id FROM public.tasks
    WHERE game_id = game_id_param OR is_builtin = true
    ORDER BY random()
  ) INTO v_task_ids;

  SELECT ARRAY(
    SELECT player_id FROM public.game_players
    WHERE game_id = game_id_param
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

  FOR i IN 1..v_n_players LOOP
    INSERT INTO public.assignments (game_id, killer_id, target_id, is_active)
    VALUES (
      game_id_param,
      v_player_ids[i],
      v_player_ids[(i % v_n_players) + 1],
      true
    );
  END LOOP;

  UPDATE public.games
  SET status = 'active', started_at = now()
  WHERE id = game_id_param;
END;
$$;

-- confirm_kill (003_fixes + 004: Task als is_used markieren)
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

-- leave_game (003_fixes + 004: Admin-Transfer)
CREATE OR REPLACE FUNCTION public.leave_game(game_id_param uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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

    RETURN jsonb_build_object('left', true, 'game_over', true, 'winner_id', v_winner_id);
  END IF;

  RETURN jsonb_build_object('left', true, 'game_over', false);
END;
$$;

-- admin_kick_player (neu aus 004)
CREATE OR REPLACE FUNCTION public.admin_kick_player(
  game_id_param    uuid,
  target_player_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
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
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
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
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
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
LANGUAGE plpgsql SECURITY DEFINER AS $$
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

-- ── Trigger ───────────────────────────────────────────────────

-- Neuen Auth-User automatisch als Profil anlegen
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- update_player_stats-Trigger wurde entfernt (003_fixes):
-- zaehlt kills doppelt, Logik liegt in confirm_kill

-- ── Realtime ──────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.game_players;
ALTER PUBLICATION supabase_realtime ADD TABLE public.assignments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.eliminations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.player_tasks;
