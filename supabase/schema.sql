-- Locked In — Supabase schema (v1)
-- Run this in the Supabase SQL editor of a fresh project.
--
-- Trust model (accepted in docs/DESIGN.md Open Question 2): permissive RLS,
-- anon key can read/write. Fine for a friend group; the clean upgrade path
-- is Supabase anonymous auth + user_id = auth.uid() policies.

create table users (
  id uuid primary key,
  display_name text not null,
  created_at timestamptz not null default now()
);

create table groups (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null default 'Locked In',
  created_at timestamptz not null default now()
);

create table memberships (
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table daily_scores (
  user_id uuid not null references users(id) on delete cascade,
  date date not null,
  seconds int not null default 0,
  is_active boolean not null default false,
  last_active_at timestamptz,
  heartbeat_at timestamptz not null default now(),
  primary key (user_id, date)
);

-- Permissive RLS: enabled so the tables aren't wide open to future policy
-- mistakes, but v1 policies allow the anon role everything.
alter table users enable row level security;
alter table groups enable row level security;
alter table memberships enable row level security;
alter table daily_scores enable row level security;

create policy anon_all_users on users for all using (true) with check (true);
create policy anon_all_groups on groups for all using (true) with check (true);
create policy anon_all_memberships on memberships for all using (true) with check (true);
create policy anon_all_daily_scores on daily_scores for all using (true) with check (true);

-- One round trip for the whole board: every member of the group with
-- their score row for the requested date (LEFT JOIN: members with no
-- score today still appear at 0).
create or replace function get_group_board(p_group uuid, p_date date)
returns table (
  user_id uuid,
  display_name text,
  seconds int,
  is_active boolean,
  last_active_at timestamptz,
  heartbeat_at timestamptz
)
language sql
stable
as $$
  select
    u.id,
    u.display_name,
    coalesce(s.seconds, 0),
    coalesce(s.is_active, false),
    s.last_active_at,
    s.heartbeat_at
  from memberships m
  join users u on u.id = m.user_id
  left join daily_scores s on s.user_id = u.id and s.date = p_date
  where m.group_id = p_group
  order by coalesce(s.seconds, 0) desc;
$$;
