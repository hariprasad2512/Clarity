-- Clarity tasks table. Run via Supabase Dashboard → SQL Editor,
-- or `supabase db push` if you use the Supabase CLI.
--
-- Design notes for future cross-platform clients:
-- * `id` is client-generated (UUID string). Offline-created tasks keep a
--   stable identity across devices — no server round-trip needed to name them.
-- * `user_id` references auth.users; every query is scoped by RLS below.
-- * Conflict policy is last-write-wins on `updated_at` (see SyncEngine).

create table if not exists public.tasks (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  due_at timestamptz null,
  priority smallint not null default 4,
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tasks_user_updated_idx
  on public.tasks (user_id, updated_at desc);

alter table public.tasks enable row level security;

drop policy if exists "Users manage own tasks" on public.tasks;
create policy "Users manage own tasks"
  on public.tasks
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
