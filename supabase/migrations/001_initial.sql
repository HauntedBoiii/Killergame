-- ============================================================
-- Mörderspiel – Supabase Migration 001
-- Führe dieses SQL im Supabase SQL-Editor aus.
-- ============================================================

-- ── Profiles (extends auth.users) ───────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  avatar_url    text,
  total_kills   int  default 0,
  total_games   int  default 0,
  total_wins    int  default 0,
  created_at    timestamptz default now()
);

-- ── Games ────────────────────────────────────────────────────
create table if not exists public.games (
  id            uuid primary key default gen_random_uuid(),
  code          text unique not null,          -- 6-char join code
  name          text not null,
  creator_id    uuid references public.profiles(id),
  status        text not null default 'lobby', -- lobby | active | finished
  mode          text not null default 'task',  -- task | object
  settings      jsonb not null default '{}',   -- {safe_zones, protection_times, team_mode}
  started_at    timestamptz,
  ended_at      timestamptz,
  winner_id     uuid references public.profiles(id),
  created_at    timestamptz default now()
);

-- ── Game Players ─────────────────────────────────────────────
create table if not exists public.game_players (
  id            uuid primary key default gen_random_uuid(),
  game_id       uuid not null references public.games(id) on delete cascade,
  player_id     uuid not null references public.profiles(id) on delete cascade,
  is_admin      boolean default false,
  is_ready      boolean default false,
  is_alive      boolean default true,
  kills         int default 0,
  joined_at     timestamptz default now(),
  eliminated_at timestamptz,
  unique (game_id, player_id)
);

-- ── Tasks (global pool) ──────────────────────────────────────
create table if not exists public.tasks (
  id            uuid primary key default gen_random_uuid(),
  description   text not null,
  category      text default 'custom',
  difficulty    int  default 1 check (difficulty between 1 and 3),
  is_builtin    boolean default false,
  created_by    uuid references public.profiles(id),
  created_at    timestamptz default now()
);

-- ── Assignments (active target relationships) ────────────────
create table if not exists public.assignments (
  id            uuid primary key default gen_random_uuid(),
  game_id       uuid not null references public.games(id) on delete cascade,
  killer_id     uuid not null references public.profiles(id),
  target_id     uuid not null references public.profiles(id),
  is_active     boolean default true,
  assigned_at   timestamptz default now()
);

-- ── Player Tasks ─────────────────────────────────────────────
create table if not exists public.player_tasks (
  id              uuid primary key default gen_random_uuid(),
  game_id         uuid not null references public.games(id) on delete cascade,
  player_id       uuid not null references public.profiles(id),
  task_id         uuid not null references public.tasks(id),
  is_used         boolean default false,
  acquired_from   uuid references public.profiles(id), -- null = original assignment
  created_at      timestamptz default now()
);

-- ── Eliminations ─────────────────────────────────────────────
create table if not exists public.eliminations (
  id              uuid primary key default gen_random_uuid(),
  game_id         uuid not null references public.games(id) on delete cascade,
  killer_id       uuid not null references public.profiles(id),
  victim_id       uuid not null references public.profiles(id),
  task_id         uuid references public.tasks(id),
  status          text default 'pending', -- pending | confirmed | rejected
  confirmed_by    uuid references public.profiles(id),
  created_at      timestamptz default now(),
  confirmed_at    timestamptz
);

-- ── Achievements ─────────────────────────────────────────────
create table if not exists public.achievements (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  description     text,
  icon            text,
  condition_type  text, -- first_kill | kills_N | win | survivor
  condition_value int   default 1
);

create table if not exists public.player_achievements (
  id              uuid primary key default gen_random_uuid(),
  player_id       uuid references public.profiles(id),
  achievement_id  uuid references public.achievements(id),
  game_id         uuid references public.games(id),
  earned_at       timestamptz default now(),
  unique (player_id, achievement_id, game_id)
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.profiles           enable row level security;
alter table public.games              enable row level security;
alter table public.game_players       enable row level security;
alter table public.tasks              enable row level security;
alter table public.assignments        enable row level security;
alter table public.player_tasks       enable row level security;
alter table public.eliminations       enable row level security;
alter table public.achievements       enable row level security;
alter table public.player_achievements enable row level security;

-- profiles
create policy "profiles_select" on public.profiles for select using (auth.role() = 'authenticated');
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- games: viewable only by participants
create policy "games_select" on public.games for select using (
  creator_id = auth.uid() or
  exists (select 1 from public.game_players where game_id = id and player_id = auth.uid())
);
create policy "games_insert" on public.games for insert with check (auth.uid() = creator_id);
create policy "games_update" on public.games for update using (
  exists (select 1 from public.game_players where game_id = id and player_id = auth.uid() and is_admin = true)
);

-- game_players
create policy "gp_select" on public.game_players for select using (
  exists (select 1 from public.game_players gp2 where gp2.game_id = game_id and gp2.player_id = auth.uid())
);
create policy "gp_insert" on public.game_players for insert with check (player_id = auth.uid());
create policy "gp_update" on public.game_players for update using (
  player_id = auth.uid() or
  exists (select 1 from public.game_players where game_id = game_players.game_id and player_id = auth.uid() and is_admin = true)
);
create policy "gp_delete" on public.game_players for delete using (
  player_id = auth.uid() or
  exists (select 1 from public.game_players where game_id = game_players.game_id and player_id = auth.uid() and is_admin = true)
);

-- tasks: everyone reads, authenticated creates
create policy "tasks_select" on public.tasks for select using (auth.role() = 'authenticated');
create policy "tasks_insert" on public.tasks for insert with check (auth.uid() = created_by);

-- assignments: ONLY the killer sees their own active assignment
create policy "assignments_select" on public.assignments for select using (killer_id = auth.uid() and is_active = true);
create policy "assignments_insert" on public.assignments for insert with check (
  exists (select 1 from public.game_players where game_id = assignments.game_id and player_id = auth.uid() and is_admin = true)
);

-- player_tasks: only the player sees their tasks
create policy "ptasks_select" on public.player_tasks for select using (player_id = auth.uid());
create policy "ptasks_insert" on public.player_tasks for insert with check (
  player_id = auth.uid() or
  exists (select 1 from public.game_players where game_id = player_tasks.game_id and player_id = auth.uid() and is_admin = true)
);
create policy "ptasks_update" on public.player_tasks for update using (player_id = auth.uid());

-- eliminations: all game participants can read
create policy "elim_select" on public.eliminations for select using (
  exists (select 1 from public.game_players where game_id = eliminations.game_id and player_id = auth.uid())
);
create policy "elim_insert" on public.eliminations for insert with check (killer_id = auth.uid());
create policy "elim_update" on public.eliminations for update using (
  victim_id = auth.uid() or
  exists (select 1 from public.game_players where game_id = eliminations.game_id and player_id = auth.uid() and is_admin = true)
);

-- achievements
create policy "ach_select" on public.achievements for select using (auth.role() = 'authenticated');
create policy "pach_select" on public.player_achievements for select using (player_id = auth.uid());
create policy "pach_insert" on public.player_achievements for insert with check (player_id = auth.uid());

-- ============================================================
-- Database Functions (called via supabase.rpc)
-- ============================================================

-- Generate a random 6-char game code
create or replace function generate_game_code()
returns text language plpgsql as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code  text := '';
  i     int;
begin
  for i in 1..6 loop
    code := code || substr(chars, floor(random() * length(chars))::int + 1, 1);
  end loop;
  -- Retry if code already exists
  if exists (select 1 from public.games where games.code = code) then
    return generate_game_code();
  end if;
  return code;
end;
$$;

-- Start game: shuffle players into circular assignment chain
create or replace function start_game(game_id_param uuid)
returns void language plpgsql security definer as $$
declare
  player_ids uuid[];
  task_ids   uuid[];
  n          int;
  i          int;
  t_idx      int;
  task_count int;
begin
  -- Authorization: must be admin of this game
  if not exists (
    select 1 from public.game_players
    where game_id = game_id_param and player_id = auth.uid() and is_admin = true
  ) then
    raise exception 'Not authorized';
  end if;

  -- Get shuffled player list
  select array_agg(player_id order by random())
  into player_ids
  from public.game_players
  where game_id = game_id_param and is_alive = true;

  n := array_length(player_ids, 1);
  if n < 2 then
    raise exception 'Need at least 2 players';
  end if;

  -- Create circular kill-chain: player[i] hunts player[(i%n)+1]
  for i in 1..n loop
    insert into public.assignments (game_id, killer_id, target_id)
    values (
      game_id_param,
      player_ids[i],
      player_ids[(i % n) + 1]
    );
  end loop;

  -- Assign 1 random task per player (if tasks exist)
  select array_agg(id order by random()) into task_ids from public.tasks;
  task_count := coalesce(array_length(task_ids, 1), 0);

  if task_count > 0 then
    for i in 1..n loop
      t_idx := ((i - 1) % task_count) + 1;
      insert into public.player_tasks (game_id, player_id, task_id)
      values (game_id_param, player_ids[i], task_ids[t_idx]);
    end loop;
  end if;

  -- Update game status
  update public.games
  set status = 'active', started_at = now()
  where id = game_id_param;
end;
$$;

-- Confirm kill: reassign target chain, transfer tasks, check game over
create or replace function confirm_kill(elimination_id_param uuid)
returns jsonb language plpgsql security definer as $$
declare
  elim          record;
  killer_assign record;
  victim_assign record;
  alive_count   int;
begin
  -- Load elimination
  select * into elim from public.eliminations where id = elimination_id_param;

  -- Authorization: victim or admin
  if elim.victim_id != auth.uid() then
    if not exists (
      select 1 from public.game_players
      where game_id = elim.game_id and player_id = auth.uid() and is_admin = true
    ) then
      raise exception 'Not authorized to confirm';
    end if;
  end if;

  -- Get killer's current assignment
  select * into killer_assign from public.assignments
  where game_id = elim.game_id and killer_id = elim.killer_id and is_active = true;

  -- Get victim's current assignment (victim's target becomes killer's new target)
  select * into victim_assign from public.assignments
  where game_id = elim.game_id and killer_id = elim.victim_id and is_active = true;

  -- Deactivate killer's old assignment
  update public.assignments set is_active = false where id = killer_assign.id;

  -- Deactivate victim's assignment
  if victim_assign.id is not null then
    update public.assignments set is_active = false where id = victim_assign.id;

    -- Assign killer to victim's target (unless killer = victim's target = themselves, impossible but safety check)
    if victim_assign.target_id != elim.killer_id then
      insert into public.assignments (game_id, killer_id, target_id)
      values (elim.game_id, elim.killer_id, victim_assign.target_id);
    end if;
  end if;

  -- Transfer victim's unused tasks to killer
  update public.player_tasks
  set player_id = elim.killer_id, acquired_from = elim.victim_id
  where game_id = elim.game_id and player_id = elim.victim_id and is_used = false;

  -- Mark victim as eliminated
  update public.game_players
  set is_alive = false, eliminated_at = now()
  where game_id = elim.game_id and player_id = elim.victim_id;

  -- Update killer kill count
  update public.game_players
  set kills = kills + 1
  where game_id = elim.game_id and player_id = elim.killer_id;

  -- Confirm elimination
  update public.eliminations
  set status = 'confirmed', confirmed_by = auth.uid(), confirmed_at = now()
  where id = elimination_id_param;

  -- Update global profile stats
  update public.profiles set total_kills = total_kills + 1 where id = elim.killer_id;

  -- Check if game is over
  select count(*) into alive_count
  from public.game_players
  where game_id = elim.game_id and is_alive = true;

  if alive_count <= 1 then
    -- Game over
    declare
      winner_id uuid;
    begin
      select player_id into winner_id from public.game_players
      where game_id = elim.game_id and is_alive = true limit 1;

      update public.games
      set status = 'finished', ended_at = now(), winner_id = winner_id
      where id = elim.game_id;

      update public.profiles
      set total_wins = total_wins + 1, total_games = total_games + 1
      where id = winner_id;

      -- Update total_games for all participants
      update public.profiles
      set total_games = total_games + 1
      where id in (
        select player_id from public.game_players where game_id = elim.game_id and player_id != winner_id
      );

      return jsonb_build_object('game_over', true, 'winner_id', winner_id);
    end;
  end if;

  return jsonb_build_object('game_over', false);
end;
$$;

-- ============================================================
-- Seed built-in tasks
-- ============================================================
insert into public.tasks (description, category, difficulty, is_builtin, created_by) values
  ('Bringe dein Ziel dazu, das Wort „Ananas" zu sagen', 'social', 1, true, null),
  ('Mache ein Selfie zusammen mit deinem Ziel', 'social', 1, true, null),
  ('Bringe dein Ziel dazu, über Kreuz zu trinken', 'social', 2, true, null),
  ('Bringe dein Ziel dazu, einen roten Gegenstand zu berühren', 'object', 1, true, null),
  ('Bringe dein Ziel dazu, dir etwas zu leihen', 'social', 2, true, null),
  ('Bringe dein Ziel dazu, zu winken', 'social', 1, true, null),
  ('Bringe dein Ziel dazu, einen Witz zu erzählen', 'social', 2, true, null),
  ('Bringe dein Ziel dazu, dich auf den Arm zu nehmen (hochheben)', 'physical', 3, true, null),
  ('Bringe dein Ziel dazu, auf einem Bein zu stehen', 'physical', 2, true, null),
  ('Bringe dein Ziel dazu, ein Lied zu singen', 'social', 3, true, null),
  ('Bringe dein Ziel dazu, dich mit deinem Vornamen zu begrüßen', 'social', 1, true, null),
  ('Bringe dein Ziel dazu, etwas auf Englisch zu sagen', 'social', 1, true, null),
  ('Bringe dein Ziel dazu, dir eine Frage zu stellen', 'social', 2, true, null),
  ('Bringe dein Ziel dazu, dir zu applaudieren', 'social', 2, true, null),
  ('Bringe dein Ziel dazu, einen Handstand zu versuchen', 'physical', 3, true, null)
on conflict do nothing;

-- ============================================================
-- Seed achievements
-- ============================================================
insert into public.achievements (name, description, icon, condition_type, condition_value) values
  ('Erstmörder', 'Erstes Opfer eliminiert', '🗡️', 'first_kill', 1),
  ('Serienkiller', '3 Opfer in einer Runde eliminiert', '💀', 'kills_in_game', 3),
  ('Massenmörder', '5 Opfer in einer Runde eliminiert', '☠️', 'kills_in_game', 5),
  ('Überlebender', 'Eine Runde gewonnen', '🏆', 'win', 1),
  ('Veteran', '5 Spielrunden abgeschlossen', '⚔️', 'total_games', 5),
  ('Meuchelmörder', '10 Opfer insgesamt eliminiert', '🔪', 'total_kills', 10)
on conflict do nothing;

-- ============================================================
-- Realtime: enable for necessary tables
-- ============================================================
alter publication supabase_realtime add table public.games;
alter publication supabase_realtime add table public.game_players;
alter publication supabase_realtime add table public.assignments;
alter publication supabase_realtime add table public.eliminations;
alter publication supabase_realtime add table public.player_tasks;
