create table if not exists public.push_subscriptions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.profiles(id) on delete cascade not null,
  subscription text not null,
  endpoint     text not null,
  created_at   timestamptz default now(),
  unique(endpoint)
);

alter table public.push_subscriptions enable row level security;

create policy "push_sub_insert" on public.push_subscriptions
  for insert with check (user_id = auth.uid());
create policy "push_sub_select" on public.push_subscriptions
  for select using (user_id = auth.uid());
create policy "push_sub_delete" on public.push_subscriptions
  for delete using (user_id = auth.uid());
