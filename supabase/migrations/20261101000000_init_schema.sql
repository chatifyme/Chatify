-- Chatify: initial schema (DRAFT for Phase 5, see supabase/ERA.md)
-- Rules from CLAUDE.md that this file enforces:
--   2: no column can hold prompt text (events has only enums, numbers, dates, ids)
--   6: per-employee view is off by default (members.consent_individual_view = false)
--   8: Row Level Security on every table; org A never sees org B

-- ---------------------------------------------------------------------------
-- Enums (closed value sets instead of free text)
-- ---------------------------------------------------------------------------
create type public.member_role as enum ('admin', 'member');
create type public.ai_tool as enum ('chatgpt');                         -- shared/src/tools.ts
create type public.data_type as enum ('oib', 'iban', 'api_key', 'email');
create type public.policy_action as enum ('replace', 'block', 'warn');
create type public.event_action as enum (
  'checked',      -- prompt sent with nothing sensitive, only scored
  'replaced',     -- user replaced sensitive data with labels ([OIB], [IBAN], [KLJUC])
  'edited',       -- user edited the prompt manually
  'sent_anyway',  -- user sent despite the warning
  'blocked',      -- policy blocked sending
  'improved'      -- user clicked "Poboljsaj"
);

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table public.plans (
  id                        text primary key,               -- 'pilot', 'starter', 'pro'
  name                      text not null,
  max_seats                 integer not null check (max_seats > 0),
  max_improve_calls_monthly integer not null check (max_improve_calls_monthly >= 0),
  created_at                timestamptz not null default now()
);

create table public.organizations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 200),
  plan_id    text not null default 'pilot' references public.plans (id),
  created_at timestamptz not null default now()
);

create table public.teams (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 100),
  created_at timestamptz not null default now(),
  unique (org_id, name),
  unique (id, org_id)                       -- target for composite FKs below
);

create table public.members (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null unique references auth.users (id) on delete cascade, -- v1: one org per user
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  team_id                 uuid,
  role                    public.member_role not null default 'member',
  pseudo_id               uuid not null unique default gen_random_uuid(),
  consent_individual_view boolean not null default false,
  consent_at              timestamptz,
  joined_at               timestamptz not null default now(),
  -- the team must belong to the same org
  foreign key (team_id, org_id) references public.teams (id, org_id) on delete set null (team_id),
  unique (pseudo_id, org_id),
  check (consent_individual_view = false or consent_at is not null)
);

create table public.invites (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  team_id    uuid,
  code       text not null unique check (char_length(code) between 6 and 32),
  email      text,                                  -- optional: invite only this address
  role       public.member_role not null default 'member',
  max_uses   integer not null default 1 check (max_uses > 0),
  used_count integer not null default 0 check (used_count >= 0),
  expires_at timestamptz not null default now() + interval '14 days',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (team_id, org_id) references public.teams (id, org_id) on delete set null (team_id),
  check (used_count <= max_uses)
);

-- Rule 2: NO text column. Only ids, enums, numbers and dates.
create table public.events (
  id            bigint generated always as identity primary key,
  org_id        uuid not null references public.organizations (id) on delete cascade,
  team_id       uuid,
  pseudo_id     uuid,
  tool          public.ai_tool not null,
  week          date not null check (extract(isodow from week) = 1),   -- Monday of the ISO week
  quality_score smallint check (quality_score between 0 and 100),
  blocked_type  public.data_type,
  action        public.event_action not null,
  created_at    timestamptz not null default now(),
  foreign key (team_id, org_id) references public.teams (id, org_id) on delete set null (team_id),
  foreign key (pseudo_id, org_id) references public.members (pseudo_id, org_id) on delete set null (pseudo_id),
  -- actions about sensitive data must say which type was found
  check (
    (action in ('replaced', 'edited', 'sent_anyway', 'blocked')) = (blocked_type is not null)
  )
);

create index events_org_week_idx on public.events (org_id, week);
create index events_org_team_week_idx on public.events (org_id, team_id, week);

create table public.policies (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  data_type  public.data_type not null,
  action     public.policy_action not null default 'warn',
  enabled    boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (org_id, data_type)
);

create table public.usage_monthly (
  org_id        uuid not null references public.organizations (id) on delete cascade,
  month         date not null check (extract(day from month) = 1),   -- first day of month
  improve_calls integer not null default 0 check (improve_calls >= 0),
  tokens_in     bigint not null default 0 check (tokens_in >= 0),
  tokens_out    bigint not null default 0 check (tokens_out >= 0),
  primary key (org_id, month)
);

-- ---------------------------------------------------------------------------
-- Helper functions for RLS (security definer so they can read members
-- without recursing into members' own policies)
-- ---------------------------------------------------------------------------
create function public.is_org_member(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.members m
    where m.org_id = p_org and m.user_id = (select auth.uid())
  );
$$;

create function public.is_org_admin(p_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.members m
    where m.org_id = p_org and m.user_id = (select auth.uid()) and m.role = 'admin'
  );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security: ON for every table
-- ---------------------------------------------------------------------------
alter table public.plans         enable row level security;
alter table public.organizations enable row level security;
alter table public.teams         enable row level security;
alter table public.members       enable row level security;
alter table public.invites       enable row level security;
alter table public.events        enable row level security;
alter table public.policies      enable row level security;
alter table public.usage_monthly enable row level security;

-- plans: global price list, readable by any signed-in user, never written by users
create policy plans_read on public.plans
  for select to authenticated using (true);

-- organizations: members read their own org, admins rename it.
-- Creating an org goes through an RPC (create_organization) in Phase 5.
create policy org_read on public.organizations
  for select to authenticated using (public.is_org_member(id));
create policy org_update on public.organizations
  for update to authenticated using (public.is_org_admin(id)) with check (public.is_org_admin(id));

-- teams
create policy teams_read on public.teams
  for select to authenticated using (public.is_org_member(org_id));
create policy teams_admin_write on public.teams
  for all to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

-- members: everyone sees their own row; admins see and manage their org.
-- A member changes their own consent through an RPC (set_individual_consent) in Phase 5.
create policy members_read_self on public.members
  for select to authenticated using (user_id = (select auth.uid()));
create policy members_read_admin on public.members
  for select to authenticated using (public.is_org_admin(org_id));
create policy members_admin_update on public.members
  for update to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));
create policy members_admin_delete on public.members
  for delete to authenticated using (public.is_org_admin(org_id));

-- invites: admins only. Redeeming a code goes through an RPC (redeem_invite) in Phase 5.
create policy invites_admin on public.invites
  for all to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

-- events: a member may only insert events for themselves, in their own org and team.
-- Nobody selects raw events; the dashboard uses the aggregate function below.
create policy events_insert_self on public.events
  for insert to authenticated
  with check (
    exists (
      select 1 from public.members m
      where m.user_id = (select auth.uid())
        and m.org_id = events.org_id
        and m.pseudo_id = events.pseudo_id
        and m.team_id is not distinct from events.team_id
    )
  );

-- policies: members read them (the extension needs them), admins change them
create policy policies_read on public.policies
  for select to authenticated using (public.is_org_member(org_id));
create policy policies_admin_write on public.policies
  for all to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

-- usage_monthly: admins read; the Worker increments it through an RPC in Phase 6
create policy usage_read_admin on public.usage_monthly
  for select to authenticated using (public.is_org_admin(org_id));

-- ---------------------------------------------------------------------------
-- Aggregates for the dashboard: totals only, never individual rows
-- ---------------------------------------------------------------------------
create function public.team_weekly_stats(p_org uuid, p_from date default (current_date - 84))
returns table (
  team_id        uuid,
  week           date,
  active_users   bigint,
  prompts        bigint,
  avg_quality    numeric,
  blocked_total  bigint,
  blocked_oib    bigint,
  blocked_iban   bigint,
  blocked_key    bigint,
  blocked_email  bigint
)
language sql stable security definer set search_path = ''
as $$
  select
    e.team_id,
    e.week,
    count(distinct e.pseudo_id),
    count(*),
    round(avg(e.quality_score), 1),
    count(*) filter (where e.blocked_type is not null),
    count(*) filter (where e.blocked_type = 'oib'),
    count(*) filter (where e.blocked_type = 'iban'),
    count(*) filter (where e.blocked_type = 'api_key'),
    count(*) filter (where e.blocked_type = 'email')
  from public.events e
  where e.org_id = p_org
    and e.week >= p_from
    and public.is_org_admin(p_org)        -- non-admins and other orgs get zero rows
  group by e.team_id, e.week
  order by e.week, e.team_id;
$$;

revoke execute on function public.team_weekly_stats(uuid, date) from public, anon;
grant execute on function public.team_weekly_stats(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Seed: plans
-- ---------------------------------------------------------------------------
insert into public.plans (id, name, max_seats, max_improve_calls_monthly) values
  ('pilot',   'Pilot',   50,  2000),
  ('starter', 'Starter', 20,  1000),
  ('pro',     'Pro',     200, 10000);
