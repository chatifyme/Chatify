-- =============================================================================
-- Chatify: complete database schema (replaces 20261101000000_init_schema.sql)
-- Covers Phases 5-11 from docs/PROMPTS.md. See supabase/ERA.md.
--
-- Privacy / GDPR rules this file enforces (CLAUDE.md):
--   * No names, no e-mails in any public table. A person is only a random code
--     (members.pseudo_id). Login identity stays inside Supabase Auth.
--   * Rule 2: events have NO free-text column. Only ids, enums, numbers, dates.
--   * Rule 6: per-person stats need BOTH the org setting AND the employee's own
--     consent; every access is written to the audit log.
--   * Rule 8: Row Level Security on every table; firm A never sees firm B.
--   * Small groups are hidden (k-anonymity, at least 3 people per row).
--   * Retention: old events are deleted automatically (purge_expired_data).
--   * Right of access / erasure: my_* functions and delete_my_data().
--   * Admins can never change an employee's consent (column privileges).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enums: closed value sets instead of free text
-- -----------------------------------------------------------------------------
create type public.member_role     as enum ('admin', 'member');
create type public.ai_tool         as enum ('chatgpt', 'claude', 'gemini');
create type public.browser         as enum ('chrome', 'edge');

-- What a detector found (never the value itself)
create type public.data_type as enum (
  'oib', 'email', 'phone',             -- personal / contact
  'iban', 'card_number',               -- financial
  'api_key', 'private_key',            -- secrets
  'source_code', 'contract'            -- company documents
);

-- Policy categories shown in the dashboard (Phase 7)
create type public.policy_category as enum (
  'personal_id', 'contact', 'financial', 'secrets', 'source_code', 'contracts'
);
create type public.policy_action   as enum ('replace', 'block', 'warn');

-- Prompt-quality rules (Phase 4)
create type public.rule_kind as enum (
  'vague', 'missing_context', 'contradiction', 'too_short', 'no_format'
);

-- What the user did with a prompt
create type public.event_action as enum (
  'sent',               -- sent normally (nothing sensitive)
  'replaced',           -- sensitive data replaced with labels, then sent
  'edited',             -- user chose to edit the prompt
  'sent_anyway',        -- sent despite the warning
  'blocked',            -- policy blocked sending
  'improve_requested'   -- user clicked "Poboljsaj"
);

create type public.audit_action as enum (
  'org_created', 'settings_changed', 'policy_changed', 'invite_created',
  'member_joined', 'member_role_changed', 'member_team_changed',
  'member_removed', 'consent_changed', 'individual_view_accessed',
  'data_deleted'
);

create type public.billing_provider as enum ('stripe', 'paddle', 'manual');
create type public.billing_status   as enum ('trialing', 'active', 'past_due', 'canceled');

-- Maps a detected data type to its policy category
create function public.category_of(t public.data_type)
returns public.policy_category
language sql immutable set search_path = ''
as $$
  select case t
    when 'oib'         then 'personal_id'
    when 'email'       then 'contact'
    when 'phone'       then 'contact'
    when 'iban'        then 'financial'
    when 'card_number' then 'financial'
    when 'api_key'     then 'secrets'
    when 'private_key' then 'secrets'
    when 'source_code' then 'source_code'
    when 'contract'    then 'contracts'
  end::public.policy_category;
$$;

-- -----------------------------------------------------------------------------
-- 2. Plans and organizations
-- -----------------------------------------------------------------------------
create table public.plans (
  id                        text primary key check (id ~ '^[a-z0-9_]{2,30}$'),
  name                      text not null check (char_length(name) between 1 and 50),
  max_seats                 integer not null check (max_seats > 0),
  max_improve_calls_monthly integer not null check (max_improve_calls_monthly >= 0),
  monthly_token_quota       bigint  not null check (monthly_token_quota >= 0),
  created_at                timestamptz not null default now()
);

create table public.organizations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 200),
  plan_id    text not null default 'pilot' references public.plans (id),
  created_at timestamptz not null default now()
);

create table public.org_settings (
  org_id                  uuid primary key references public.organizations (id) on delete cascade,
  individual_view_enabled boolean  not null default false,          -- rule 6, off by default
  min_group_size          smallint not null default 3 check (min_group_size between 3 and 50),
  retention_months        smallint not null default 12 check (retention_months between 3 and 24),
  enabled_tools           public.ai_tool[] not null default '{chatgpt}',
  weekly_report_enabled   boolean  not null default true,
  report_weekday          smallint not null default 1 check (report_weekday between 1 and 7),
  updated_at              timestamptz not null default now()
);

create table public.teams (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 100),
  created_at timestamptz not null default now(),
  unique (org_id, name),
  unique (id, org_id)
);

-- -----------------------------------------------------------------------------
-- 3. People: only a code, no name, no e-mail
-- -----------------------------------------------------------------------------
create table public.members (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null unique references auth.users (id) on delete cascade,
  org_id                  uuid not null references public.organizations (id) on delete cascade,
  team_id                 uuid,
  role                    public.member_role not null default 'member',
  pseudo_id               uuid not null unique default gen_random_uuid(),   -- the "user code"
  consent_individual_view boolean not null default false,
  consent_at              timestamptz,
  joined_at               timestamptz not null default now(),
  foreign key (team_id, org_id) references public.teams (id, org_id) on delete set null (team_id),
  unique (pseudo_id, org_id),
  check (consent_individual_view = false or consent_at is not null)
);

-- Proof of consent (GDPR art. 7). Keeps only the code, survives account deletion.
create table public.consent_log (
  id         bigint generated always as identity primary key,
  org_id     uuid not null references public.organizations (id) on delete cascade,
  pseudo_id  uuid not null,
  granted    boolean not null,
  created_at timestamptz not null default now()
);

-- Invite codes. No e-mail stored: the admin sends the code themselves.
create table public.invites (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  team_id    uuid,
  code       text not null unique check (code ~ '^[A-Z0-9]{8,16}$'),
  role       public.member_role not null default 'member',
  max_uses   integer not null default 1 check (max_uses between 1 and 500),
  used_count integer not null default 0 check (used_count >= 0),
  expires_at timestamptz not null default now() + interval '14 days',
  created_at timestamptz not null default now(),
  foreign key (team_id, org_id) references public.teams (id, org_id) on delete set null (team_id),
  check (used_count <= max_uses)
);

-- -----------------------------------------------------------------------------
-- 4. Events: one row per prompt. NO text column (rule 2).
-- -----------------------------------------------------------------------------
create table public.events (
  id                  bigint generated always as identity primary key,
  org_id              uuid not null references public.organizations (id) on delete cascade,
  team_id             uuid,
  pseudo_id           uuid,
  tool                public.ai_tool not null,
  browser             public.browser,
  week                date not null check (extract(isodow from week) = 1),       -- Monday
  action              public.event_action not null,
  quality_score       smallint check (quality_score between 0 and 100),
  est_tokens          integer  check (est_tokens between 0 and 100000),          -- estimate from length
  blocked_types       public.data_type[] not null default '{}' check (cardinality(blocked_types) <= 9),
  blocked_count       smallint not null default 0 check (blocked_count between 0 and 500),
  rule_hits           public.rule_kind[] not null default '{}' check (cardinality(rule_hits) <= 5),
  rules_applied       public.rule_kind[] not null default '{}',
  improve_suggestions smallint not null default 0 check (improve_suggestions between 0 and 50),
  improve_applied     smallint not null default 0 check (improve_applied between 0 and 50),
  created_at          timestamptz not null default now(),
  foreign key (team_id, org_id)   references public.teams (id, org_id)          on delete set null (team_id),
  foreign key (pseudo_id, org_id) references public.members (pseudo_id, org_id) on delete set null (pseudo_id),
  check ((action in ('replaced', 'edited', 'sent_anyway', 'blocked')) = (cardinality(blocked_types) > 0)),
  check (rules_applied <@ rule_hits),
  check (improve_applied <= improve_suggestions),
  check (action = 'improve_requested' or improve_suggestions = 0)
);

create index events_org_week_idx      on public.events (org_id, week);
create index events_org_team_week_idx on public.events (org_id, team_id, week);
create index events_pseudo_week_idx   on public.events (pseudo_id, week);

-- -----------------------------------------------------------------------------
-- 5. Policies (Phase 3 defaults, Phase 7 dashboard)
-- -----------------------------------------------------------------------------
create table public.policies (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations (id) on delete cascade,
  category   public.policy_category not null,
  action     public.policy_action not null default 'warn',
  enabled    boolean not null default true,
  team_ids   uuid[],                -- null = all teams
  tools      public.ai_tool[],      -- null = all tools
  updated_at timestamptz not null default now(),
  unique (org_id, category)
);

-- -----------------------------------------------------------------------------
-- 6. Usage and limits ("Poboljsaj" calls and exact LLM tokens)
-- -----------------------------------------------------------------------------
create table public.usage_monthly (
  org_id        uuid not null references public.organizations (id) on delete cascade,
  month         date not null check (extract(day from month) = 1),
  improve_calls integer not null default 0 check (improve_calls >= 0),
  tokens_in     bigint  not null default 0 check (tokens_in >= 0),
  tokens_out    bigint  not null default 0 check (tokens_out >= 0),
  alert_80_at   timestamptz,                    -- Phase 11: warning at 80 % of the cap
  primary key (org_id, month)
);

create table public.member_usage_monthly (
  org_id        uuid not null references public.organizations (id) on delete cascade,
  pseudo_id     uuid not null,
  month         date not null check (extract(day from month) = 1),
  improve_calls integer not null default 0 check (improve_calls >= 0),
  tokens_in     bigint  not null default 0 check (tokens_in >= 0),
  tokens_out    bigint  not null default 0 check (tokens_out >= 0),
  primary key (pseudo_id, month),
  foreign key (pseudo_id, org_id) references public.members (pseudo_id, org_id) on delete cascade
);

-- -----------------------------------------------------------------------------
-- 7. Operations: adapter rules (Phase 8), billing (Phase 10), reports, audit
-- -----------------------------------------------------------------------------
-- Input-field finding rules served as DATA (no remote code). Written by CI/service role.
create table public.adapter_rules (
  id         bigint generated always as identity primary key,
  tool       public.ai_tool not null,
  version    integer not null check (version > 0),
  rules      jsonb not null check (jsonb_typeof(rules) = 'object' and pg_column_size(rules) < 65536),
  active     boolean not null default false,
  created_at timestamptz not null default now(),
  unique (tool, version)
);
create unique index adapter_rules_one_active on public.adapter_rules (tool) where active;

-- Billing: written ONLY by the payment webhook (service role, rule 8 exception). No card data.
create table public.subscriptions (
  org_id                   uuid primary key references public.organizations (id) on delete cascade,
  provider                 public.billing_provider not null,
  external_customer_id     text check (external_customer_id ~ '^[A-Za-z0-9_-]{1,100}$'),
  external_subscription_id text check (external_subscription_id ~ '^[A-Za-z0-9_-]{1,100}$'),
  status                   public.billing_status not null,
  current_period_end       timestamptz,
  updated_at               timestamptz not null default now()
);

-- Webhook idempotency (each provider event processed once)
create table public.billing_events (
  provider          public.billing_provider not null,
  external_event_id text not null check (external_event_id ~ '^[A-Za-z0-9_-]{1,100}$'),
  received_at       timestamptz not null default now(),
  primary key (provider, external_event_id)
);

-- Weekly report idempotency (Phase 7, Resend + cron)
create table public.report_log (
  org_id     uuid not null references public.organizations (id) on delete cascade,
  week       date not null check (extract(isodow from week) = 1),
  recipients smallint not null default 0 check (recipients >= 0),
  sent_at    timestamptz not null default now(),
  primary key (org_id, week)
);

-- Who did what (GDPR accountability). Actor is a code, never a name.
create table public.audit_log (
  id              bigint generated always as identity primary key,
  org_id          uuid not null references public.organizations (id) on delete cascade,
  actor_pseudo_id uuid,
  action          public.audit_action not null,
  target_pseudo_id uuid,
  created_at      timestamptz not null default now()
);
create index audit_log_org_idx on public.audit_log (org_id, created_at);

-- -----------------------------------------------------------------------------
-- 8. Helper functions
-- -----------------------------------------------------------------------------
create function public.is_org_member(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.members m
                 where m.org_id = p_org and m.user_id = (select auth.uid()));
$$;

create function public.is_org_admin(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.members m
                 where m.org_id = p_org and m.user_id = (select auth.uid()) and m.role = 'admin');
$$;

-- The caller's own membership (one row or none)
create function public.current_member()
returns public.members language sql stable security definer set search_path = ''
as $$
  select m.* from public.members m where m.user_id = (select auth.uid());
$$;

create function public.write_audit(p_org uuid, p_action public.audit_action, p_target uuid default null)
returns void language sql volatile security definer set search_path = ''
as $$
  insert into public.audit_log (org_id, actor_pseudo_id, action, target_pseudo_id)
  values (p_org,
          (select m.pseudo_id from public.members m where m.user_id = (select auth.uid())),
          p_action, p_target);
$$;

-- -----------------------------------------------------------------------------
-- 9. Triggers
-- -----------------------------------------------------------------------------
-- Events: org, team and user code always come from the logged-in user, never
-- from the client. The client sends only tool, scores, counts and types.
create function public.events_fill_member()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare m public.members;
begin
  select * into m from public.members where user_id = (select auth.uid());
  if not found then
    raise exception 'not a member of any organization' using errcode = '42501';
  end if;
  new.org_id    := m.org_id;
  new.team_id   := m.team_id;
  new.pseudo_id := m.pseudo_id;
  new.week      := coalesce(new.week, date_trunc('week', now())::date);
  new.created_at := now();
  if new.week > current_date or new.week < current_date - 56 then
    raise exception 'week out of range' using errcode = '22023';
  end if;
  return new;
end;
$$;
create trigger events_fill_member before insert on public.events
  for each row execute function public.events_fill_member();

-- Audit admin changes
create function public.audit_policies()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  new.updated_at := now();
  perform public.write_audit(new.org_id, 'policy_changed');
  return new;
end;
$$;
create trigger policies_audit before insert or update on public.policies
  for each row execute function public.audit_policies();

create function public.audit_settings()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    perform public.write_audit(new.org_id, 'settings_changed');
  end if;
  return new;
end;
$$;
create trigger org_settings_audit before insert or update on public.org_settings
  for each row execute function public.audit_settings();

create function public.audit_members()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from public.organizations where id = old.org_id) then
      perform public.write_audit(old.org_id, 'member_removed', old.pseudo_id);
    end if;
    return old;
  end if;
  if new.role is distinct from old.role then
    perform public.write_audit(new.org_id, 'member_role_changed', new.pseudo_id);
  end if;
  if new.team_id is distinct from old.team_id then
    perform public.write_audit(new.org_id, 'member_team_changed', new.pseudo_id);
  end if;
  return new;
end;
$$;
create trigger members_audit after update or delete on public.members
  for each row execute function public.audit_members();

-- Every firm with members must keep at least one admin (checked at commit)
create function public.ensure_admin_left()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_org uuid := coalesce(old.org_id, new.org_id);
begin
  if exists (select 1 from public.members where org_id = v_org)
     and not exists (select 1 from public.members where org_id = v_org and role = 'admin') then
    raise exception 'organization must keep at least one admin' using errcode = '23514';
  end if;
  return null;
end;
$$;
create constraint trigger members_keep_admin after update or delete on public.members
  deferrable initially deferred for each row execute function public.ensure_admin_left();

-- -----------------------------------------------------------------------------
-- 10. Row Level Security (on for EVERY table)
-- -----------------------------------------------------------------------------
alter table public.plans                enable row level security;
alter table public.organizations        enable row level security;
alter table public.org_settings         enable row level security;
alter table public.teams                enable row level security;
alter table public.members              enable row level security;
alter table public.consent_log          enable row level security;
alter table public.invites              enable row level security;
alter table public.events               enable row level security;
alter table public.policies             enable row level security;
alter table public.usage_monthly        enable row level security;
alter table public.member_usage_monthly enable row level security;
alter table public.adapter_rules        enable row level security;
alter table public.subscriptions        enable row level security;
alter table public.billing_events       enable row level security;
alter table public.report_log           enable row level security;
alter table public.audit_log            enable row level security;

create policy plans_read on public.plans for select to authenticated using (true);

create policy org_read   on public.organizations for select to authenticated using (public.is_org_member(id));
create policy org_update on public.organizations for update to authenticated
  using (public.is_org_admin(id)) with check (public.is_org_admin(id));

create policy settings_read   on public.org_settings for select to authenticated using (public.is_org_member(org_id));
create policy settings_update on public.org_settings for update to authenticated
  using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

create policy teams_read  on public.teams for select to authenticated using (public.is_org_member(org_id));
create policy teams_write on public.teams for all to authenticated
  using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

create policy members_read_self  on public.members for select to authenticated using (user_id = (select auth.uid()));
create policy members_read_admin on public.members for select to authenticated using (public.is_org_admin(org_id));
create policy members_update     on public.members for update to authenticated
  using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));
create policy members_delete     on public.members for delete to authenticated using (public.is_org_admin(org_id));

create policy consent_read_self on public.consent_log for select to authenticated
  using (pseudo_id = (select m.pseudo_id from public.members m where m.user_id = (select auth.uid())));

create policy invites_admin on public.invites for all to authenticated
  using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

-- events: insert only for yourself (the trigger fills org/team/code). Nobody reads raw rows.
create policy events_insert_self on public.events for insert to authenticated
  with check (exists (select 1 from public.members m
                      where m.user_id = (select auth.uid())
                        and m.org_id = events.org_id
                        and m.pseudo_id = events.pseudo_id));

create policy policies_read  on public.policies for select to authenticated using (public.is_org_member(org_id));
create policy policies_write on public.policies for all to authenticated
  using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

create policy usage_read_admin on public.usage_monthly for select to authenticated using (public.is_org_admin(org_id));

create policy member_usage_read_self on public.member_usage_monthly for select to authenticated
  using (pseudo_id = (select m.pseudo_id from public.members m where m.user_id = (select auth.uid())));

create policy adapter_rules_read on public.adapter_rules for select to authenticated using (active);

create policy subscriptions_read_admin on public.subscriptions for select to authenticated using (public.is_org_admin(org_id));
create policy report_log_read_admin    on public.report_log    for select to authenticated using (public.is_org_admin(org_id));
create policy audit_read_admin         on public.audit_log     for select to authenticated using (public.is_org_admin(org_id));
-- billing_events: no policies at all -> only the service role (webhook) can touch it

-- Column privileges: admins may change ONLY team and role of a member, never consent.
revoke all on all tables in schema public from anon;
revoke update on public.members from authenticated;
grant  update (team_id, role) on public.members to authenticated;
revoke update on public.organizations from authenticated;
grant  update (name) on public.organizations to authenticated;
revoke insert, update, delete on public.events from authenticated;
grant  insert (tool, browser, week, action, quality_score, est_tokens, blocked_types, blocked_count,
               rule_hits, rules_applied, improve_suggestions, improve_applied) on public.events to authenticated;
revoke insert, update, delete on public.usage_monthly, public.member_usage_monthly, public.consent_log,
       public.audit_log, public.subscriptions, public.billing_events, public.report_log,
       public.adapter_rules, public.plans from authenticated;

-- -----------------------------------------------------------------------------
-- 11. Onboarding RPCs (Phase 5)
-- -----------------------------------------------------------------------------
create function public.create_organization(p_name text, p_team text default null)
returns uuid language plpgsql volatile security definer set search_path = ''
as $$
declare v_org uuid; v_team uuid;
begin
  if (select auth.uid()) is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if exists (select 1 from public.members where user_id = (select auth.uid())) then
    raise exception 'already a member of an organization' using errcode = '23505';
  end if;
  insert into public.organizations (name) values (p_name) returning id into v_org;
  insert into public.org_settings (org_id) values (v_org);
  if p_team is not null then
    insert into public.teams (org_id, name) values (v_org, p_team) returning id into v_team;
  end if;
  insert into public.members (user_id, org_id, team_id, role) values ((select auth.uid()), v_org, v_team, 'admin');
  -- Phase 3 defaults
  insert into public.policies (org_id, category, action) values
    (v_org, 'personal_id', 'replace'), (v_org, 'contact', 'warn'),
    (v_org, 'financial', 'replace'),   (v_org, 'secrets', 'block'),
    (v_org, 'source_code', 'warn'),    (v_org, 'contracts', 'warn');
  perform public.write_audit(v_org, 'org_created');
  return v_org;
end;
$$;

create function public.create_invite(p_org uuid, p_team uuid default null,
                                     p_role public.member_role default 'member',
                                     p_max_uses integer default 1, p_days integer default 14)
returns text language plpgsql volatile security definer set search_path = ''
as $$
declare v_code text := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
begin
  if not public.is_org_admin(p_org) then raise exception 'admins only' using errcode = '42501'; end if;
  if p_days not between 1 and 60 then raise exception 'p_days must be 1-60' using errcode = '22023'; end if;
  insert into public.invites (org_id, team_id, code, role, max_uses, expires_at)
  values (p_org, p_team, v_code, p_role, p_max_uses, now() + make_interval(days => p_days));
  perform public.write_audit(p_org, 'invite_created');
  return v_code;
end;
$$;

create function public.redeem_invite(p_code text)
returns uuid language plpgsql volatile security definer set search_path = ''
as $$
declare i public.invites; v_seats integer; v_max integer; v_pseudo uuid;
begin
  if (select auth.uid()) is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if exists (select 1 from public.members where user_id = (select auth.uid())) then
    raise exception 'already a member of an organization' using errcode = '23505';
  end if;
  select * into i from public.invites where code = upper(trim(p_code)) for update;
  if not found or i.expires_at < now() or i.used_count >= i.max_uses then
    raise exception 'invalid or expired code' using errcode = '22023';
  end if;
  select count(*), max(p.max_seats) into v_seats, v_max
    from public.members m join public.organizations o on o.id = m.org_id join public.plans p on p.id = o.plan_id
   where m.org_id = i.org_id;
  if v_seats >= v_max then raise exception 'no free seats on this plan' using errcode = '53400'; end if;
  insert into public.members (user_id, org_id, team_id, role)
  values ((select auth.uid()), i.org_id, i.team_id, i.role) returning pseudo_id into v_pseudo;
  update public.invites set used_count = used_count + 1 where id = i.id;
  perform public.write_audit(i.org_id, 'member_joined', v_pseudo);
  return i.org_id;
end;
$$;

-- Only the employee can give or withdraw consent (rule 6)
create function public.set_individual_consent(p_consent boolean)
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare m public.members;
begin
  select * into m from public.members where user_id = (select auth.uid());
  if not found then raise exception 'not a member' using errcode = '42501'; end if;
  update public.members
     set consent_individual_view = p_consent,
         consent_at = case when p_consent then now() else null end
   where id = m.id;
  insert into public.consent_log (org_id, pseudo_id, granted) values (m.org_id, m.pseudo_id, p_consent);
  perform public.write_audit(m.org_id, 'consent_changed', m.pseudo_id);
end;
$$;

-- Right to erasure (GDPR art. 17): removes the membership; past events stay
-- only as anonymous numbers (their user code is set to null).
-- The login account in auth.users is deleted afterwards by the Worker (service role).
create function public.delete_my_data()
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare m public.members; v_others integer; v_admins integer;
begin
  select * into m from public.members where user_id = (select auth.uid());
  if not found then return; end if;
  select count(*) filter (where id <> m.id), count(*) filter (where id <> m.id and role = 'admin')
    into v_others, v_admins from public.members where org_id = m.org_id;
  if v_others = 0 then
    delete from public.organizations where id = m.org_id;     -- last person: remove the whole firm
    return;
  end if;
  if m.role = 'admin' and v_admins = 0 then
    raise exception 'make another member admin first' using errcode = '23514';
  end if;
  perform public.write_audit(m.org_id, 'data_deleted');
  delete from public.members where id = m.id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 12. Extension RPCs
-- -----------------------------------------------------------------------------
-- Policies that apply to me (my team, given tool)
create function public.my_policies(p_tool public.ai_tool default 'chatgpt')
returns table (category public.policy_category, action public.policy_action)
language sql stable security definer set search_path = ''
as $$
  select p.category, p.action
    from public.policies p
    join public.members m on m.org_id = p.org_id
   where m.user_id = (select auth.uid())
     and p.enabled
     and (p.team_ids is null or m.team_id = any (p.team_ids))
     and (p.tools is null or p_tool = any (p.tools));
$$;

-- -----------------------------------------------------------------------------
-- 13. Worker RPCs for "Poboljsaj" limits (Phase 6), called with the user's JWT
-- -----------------------------------------------------------------------------
create function public.check_improve_quota()
returns table (allowed boolean, calls_left integer, tokens_left bigint)
language sql stable security definer set search_path = ''
as $$
  select coalesce(u.improve_calls, 0) < p.max_improve_calls_monthly
           and coalesce(u.tokens_in + u.tokens_out, 0) < p.monthly_token_quota,
         greatest(p.max_improve_calls_monthly - coalesce(u.improve_calls, 0), 0),
         greatest(p.monthly_token_quota - coalesce(u.tokens_in + u.tokens_out, 0), 0)
    from public.members m
    join public.organizations o on o.id = m.org_id
    join public.plans p on p.id = o.plan_id
    left join public.usage_monthly u on u.org_id = m.org_id and u.month = date_trunc('month', current_date)::date
   where m.user_id = (select auth.uid());
$$;

-- Records one "Poboljsaj" call. Returns usage % and whether the 80 % alert just fired.
create function public.record_improve_usage(p_tokens_in integer, p_tokens_out integer)
returns table (calls_pct numeric, tokens_pct numeric, alert_80 boolean)
language plpgsql volatile security definer set search_path = ''
as $$
declare m public.members; v_month date := date_trunc('month', current_date)::date;
        u public.usage_monthly; p public.plans; v_cpct numeric; v_tpct numeric;
begin
  select * into m from public.members where user_id = (select auth.uid());
  if not found then raise exception 'not a member' using errcode = '42501'; end if;
  if p_tokens_in not between 0 and 20000 or p_tokens_out not between 0 and 20000 then
    raise exception 'token counts out of range' using errcode = '22023';
  end if;
  insert into public.usage_monthly (org_id, month, improve_calls, tokens_in, tokens_out)
  values (m.org_id, v_month, 1, p_tokens_in, p_tokens_out)
  on conflict (org_id, month) do update
    set improve_calls = usage_monthly.improve_calls + 1,
        tokens_in  = usage_monthly.tokens_in  + excluded.tokens_in,
        tokens_out = usage_monthly.tokens_out + excluded.tokens_out
  returning * into u;
  insert into public.member_usage_monthly (org_id, pseudo_id, month, improve_calls, tokens_in, tokens_out)
  values (m.org_id, m.pseudo_id, v_month, 1, p_tokens_in, p_tokens_out)
  on conflict (pseudo_id, month) do update
    set improve_calls = member_usage_monthly.improve_calls + 1,
        tokens_in  = member_usage_monthly.tokens_in  + excluded.tokens_in,
        tokens_out = member_usage_monthly.tokens_out + excluded.tokens_out;
  select pl.* into p from public.organizations o join public.plans pl on pl.id = o.plan_id where o.id = m.org_id;
  v_cpct := round(100.0 * u.improve_calls / nullif(p.max_improve_calls_monthly, 0), 1);
  v_tpct := round(100.0 * (u.tokens_in + u.tokens_out) / nullif(p.monthly_token_quota, 0), 1);
  alert_80 := false;
  if u.alert_80_at is null and greatest(v_cpct, v_tpct) >= 80 then
    update public.usage_monthly set alert_80_at = now() where org_id = m.org_id and month = v_month;
    alert_80 := true;
  end if;
  calls_pct := v_cpct; tokens_pct := v_tpct;
  return next;
end;
$$;

-- -----------------------------------------------------------------------------
-- 14. Statistics for the dashboard (Phase 7). Totals only, small groups hidden.
-- -----------------------------------------------------------------------------
-- Org KPIs for the last N days. If fewer people than min_group_size were active,
-- everything except active_users is hidden.
create function public.org_overview(p_org uuid, p_days integer default 30)
returns table (
  active_users bigint, suppressed boolean, prompts bigint, est_tokens bigint,
  avg_quality numeric, blocked_prompts bigint, blocked_items bigint, sent_anyway bigint,
  rule_hits bigint, rules_applied bigint, apply_rate_pct numeric,
  improve_requests bigint, improve_applied bigint, est_minutes_saved numeric
)
language sql stable security definer set search_path = ''
as $$
  with e as (
    select * from public.events
     where org_id = p_org and week >= current_date - p_days and public.is_org_admin(p_org)
  ), a as (
    select count(distinct pseudo_id) au, count(*) prompts, sum(est_tokens) tok,
           round(avg(quality_score), 1) q,
           count(*) filter (where cardinality(blocked_types) > 0) bp,
           sum(blocked_count) bi,
           count(*) filter (where action = 'sent_anyway') sa,
           sum(cardinality(rule_hits)) rh, sum(cardinality(rules_applied)) ra,
           count(*) filter (where action = 'improve_requested') ir,
           sum(improve_applied) ia
      from e
  ), k as (select min_group_size from public.org_settings where org_id = p_org)
  select a.au,
         a.au < k.min_group_size,
         case when a.au >= k.min_group_size then a.prompts end,
         case when a.au >= k.min_group_size then coalesce(a.tok, 0) end,
         case when a.au >= k.min_group_size then a.q end,
         case when a.au >= k.min_group_size then a.bp end,
         case when a.au >= k.min_group_size then coalesce(a.bi, 0) end,
         case when a.au >= k.min_group_size then a.sa end,
         case when a.au >= k.min_group_size then coalesce(a.rh, 0) end,
         case when a.au >= k.min_group_size then coalesce(a.ra, 0) end,
         case when a.au >= k.min_group_size then round(100.0 * a.ra / nullif(a.rh, 0), 1) end,
         case when a.au >= k.min_group_size then a.ir end,
         case when a.au >= k.min_group_size then coalesce(a.ia, 0) end,
         -- ESTIMATE (placeholder formula, team to confirm): 0.5 min per applied
         -- rule suggestion + 1 min per applied "Poboljsaj" suggestion.
         case when a.au >= k.min_group_size then round(0.5 * coalesce(a.ra, 0) + 1.0 * coalesce(a.ia, 0), 0) end
    from a, k
   where public.is_org_admin(p_org);
$$;

-- Per team and week. Teams smaller than min_group_size are merged into team_id = null
-- ("other"), and that group is also hidden if it is still too small.
create function public.team_weekly_stats(p_org uuid, p_from date default current_date - 84,
                                         p_to date default current_date)
returns table (
  team_id uuid, week date, active_users bigint, prompts bigint,
  est_tokens bigint, token_share_pct numeric, avg_quality numeric,
  blocked_prompts bigint, blocked_personal_id bigint, blocked_contact bigint,
  blocked_financial bigint, blocked_secrets bigint, blocked_source_code bigint,
  blocked_contracts bigint, sent_anyway bigint,
  hits_vague bigint, hits_missing_context bigint, hits_contradiction bigint,
  hits_too_short bigint, hits_no_format bigint, rules_applied bigint,
  improve_requests bigint, improve_applied bigint
)
language sql stable security definer set search_path = ''
as $$
  with k as (select min_group_size n from public.org_settings where org_id = p_org),
  e as (
    select * from public.events
     where org_id = p_org and week between p_from and p_to and public.is_org_admin(p_org)
  ),
  sizes as (select e.team_id, e.week, count(distinct e.pseudo_id) n from e group by 1, 2),
  lab as (
    select e.*, case when s.n >= (select n from k) then e.team_id end as grp
      from e join sizes s on s.team_id is not distinct from e.team_id and s.week = e.week
  ),
  agg as (
    select grp, week,
           count(distinct pseudo_id) au, count(*) prompts, coalesce(sum(est_tokens), 0) tok,
           round(avg(quality_score), 1) q,
           count(*) filter (where cardinality(blocked_types) > 0) bp,
           count(*) filter (where blocked_types && '{oib}'::public.data_type[]) b_pid,
           count(*) filter (where blocked_types && '{email,phone}'::public.data_type[]) b_con,
           count(*) filter (where blocked_types && '{iban,card_number}'::public.data_type[]) b_fin,
           count(*) filter (where blocked_types && '{api_key,private_key}'::public.data_type[]) b_sec,
           count(*) filter (where blocked_types && '{source_code}'::public.data_type[]) b_src,
           count(*) filter (where blocked_types && '{contract}'::public.data_type[]) b_ctr,
           count(*) filter (where action = 'sent_anyway') sa,
           count(*) filter (where 'vague' = any (rule_hits)) h1,
           count(*) filter (where 'missing_context' = any (rule_hits)) h2,
           count(*) filter (where 'contradiction' = any (rule_hits)) h3,
           count(*) filter (where 'too_short' = any (rule_hits)) h4,
           count(*) filter (where 'no_format' = any (rule_hits)) h5,
           coalesce(sum(cardinality(rules_applied)), 0) ra,
           count(*) filter (where action = 'improve_requested') ir,
           coalesce(sum(improve_applied), 0) ia
      from lab group by grp, week
  ),
  shared as (
    select agg.*, round(100.0 * tok / nullif(sum(tok) over (partition by week), 0), 1) share from agg
  )
  select grp, week, au, prompts, tok, share, q, bp, b_pid, b_con, b_fin, b_sec, b_src, b_ctr, sa,
         h1, h2, h3, h4, h5, ra, ir, ia
    from shared
   where au >= (select n from k)
   order by week, grp nulls last;
$$;

-- Per user CODE. Only if the firm enabled it AND the employee consented. Every call is audited.
create function public.member_weekly_stats(p_org uuid, p_from date default current_date - 84)
returns table (
  pseudo_id uuid, team_id uuid, week date, prompts bigint, est_tokens bigint,
  avg_quality numeric, blocked_prompts bigint, rule_hits bigint, rules_applied bigint,
  improve_requests bigint, improve_applied bigint
)
language plpgsql volatile security definer set search_path = ''
as $$
begin
  if not public.is_org_admin(p_org)
     or not coalesce((select individual_view_enabled from public.org_settings where org_id = p_org), false) then
    return;
  end if;
  perform public.write_audit(p_org, 'individual_view_accessed');
  return query
    select e.pseudo_id, e.team_id, e.week, count(*), coalesce(sum(e.est_tokens), 0),
           round(avg(e.quality_score), 1),
           count(*) filter (where cardinality(e.blocked_types) > 0),
           coalesce(sum(cardinality(e.rule_hits)), 0), coalesce(sum(cardinality(e.rules_applied)), 0),
           count(*) filter (where e.action = 'improve_requested'), coalesce(sum(e.improve_applied), 0)
      from public.events e
      join public.members m on m.pseudo_id = e.pseudo_id and m.org_id = e.org_id
     where e.org_id = p_org and e.week >= p_from and m.consent_individual_view
     group by e.pseudo_id, e.team_id, e.week
     order by e.week, e.pseudo_id;
end;
$$;

-- "Poboljsaj" usage this month as a percentage of the plan (dashboard + 80 % warning)
create function public.org_usage(p_org uuid)
returns table (
  plan_id text, seats_used bigint, max_seats integer, seats_pct numeric,
  improve_calls integer, max_improve_calls integer, calls_pct numeric,
  tokens_used bigint, token_quota bigint, tokens_pct numeric
)
language sql stable security definer set search_path = ''
as $$
  select p.id,
         (select count(*) from public.members where org_id = p_org),
         p.max_seats,
         round(100.0 * (select count(*) from public.members where org_id = p_org) / p.max_seats, 1),
         coalesce(u.improve_calls, 0), p.max_improve_calls_monthly,
         round(100.0 * coalesce(u.improve_calls, 0) / nullif(p.max_improve_calls_monthly, 0), 1),
         coalesce(u.tokens_in + u.tokens_out, 0), p.monthly_token_quota,
         round(100.0 * coalesce(u.tokens_in + u.tokens_out, 0) / nullif(p.monthly_token_quota, 0), 1)
    from public.organizations o
    join public.plans p on p.id = o.plan_id
    left join public.usage_monthly u on u.org_id = o.id and u.month = date_trunc('month', current_date)::date
   where o.id = p_org and public.is_org_admin(p_org);
$$;

-- -----------------------------------------------------------------------------
-- 15. Self-service for every employee (GDPR right of access)
-- -----------------------------------------------------------------------------
create function public.my_weekly_stats(p_from date default current_date - 84)
returns table (
  week date, prompts bigint, est_tokens bigint, avg_quality numeric,
  blocked_prompts bigint, rule_hits bigint, rules_applied bigint,
  improve_requests bigint, improve_applied bigint
)
language sql stable security definer set search_path = ''
as $$
  select e.week, count(*), coalesce(sum(e.est_tokens), 0), round(avg(e.quality_score), 1),
         count(*) filter (where cardinality(e.blocked_types) > 0),
         coalesce(sum(cardinality(e.rule_hits)), 0), coalesce(sum(cardinality(e.rules_applied)), 0),
         count(*) filter (where e.action = 'improve_requested'), coalesce(sum(e.improve_applied), 0)
    from public.events e
    join public.members m on m.pseudo_id = e.pseudo_id and m.org_id = e.org_id
   where m.user_id = (select auth.uid()) and e.week >= p_from
   group by e.week order by e.week;
$$;

create function public.my_usage()
returns table (improve_calls integer, tokens_used bigint, share_of_org_tokens_pct numeric,
               share_of_plan_quota_pct numeric)
language sql stable security definer set search_path = ''
as $$
  select coalesce(mu.improve_calls, 0),
         coalesce(mu.tokens_in + mu.tokens_out, 0),
         round(100.0 * coalesce(mu.tokens_in + mu.tokens_out, 0) / nullif(u.tokens_in + u.tokens_out, 0), 1),
         round(100.0 * coalesce(mu.tokens_in + mu.tokens_out, 0) / nullif(p.monthly_token_quota, 0), 1)
    from public.members m
    join public.organizations o on o.id = m.org_id
    join public.plans p on p.id = o.plan_id
    left join public.member_usage_monthly mu on mu.pseudo_id = m.pseudo_id and mu.month = date_trunc('month', current_date)::date
    left join public.usage_monthly u on u.org_id = m.org_id and u.month = date_trunc('month', current_date)::date
   where m.user_id = (select auth.uid());
$$;

-- -----------------------------------------------------------------------------
-- 16. Retention (GDPR storage limitation). Run daily by the Worker cron or pg_cron
--     with the service role, e.g.:  select cron.schedule('purge', '0 3 * * *', 'select public.purge_expired_data()');
-- -----------------------------------------------------------------------------
create function public.purge_expired_data()
returns void language sql volatile security definer set search_path = ''
as $$
  delete from public.events e using public.org_settings s
   where s.org_id = e.org_id and e.week < current_date - make_interval(months => s.retention_months);
  delete from public.member_usage_monthly where month < current_date - interval '13 months';
  delete from public.invites where expires_at < now() - interval '30 days';
  delete from public.audit_log where created_at < now() - interval '24 months';
  delete from public.billing_events where received_at < now() - interval '90 days';
$$;

-- -----------------------------------------------------------------------------
-- 17. Function permissions: nothing for anonymous users; internal helpers hidden
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.is_org_member(uuid), public.is_org_admin(uuid), public.category_of(public.data_type),
  public.create_organization(text, text), public.create_invite(uuid, uuid, public.member_role, integer, integer),
  public.redeem_invite(text), public.set_individual_consent(boolean), public.delete_my_data(),
  public.my_policies(public.ai_tool), public.check_improve_quota(), public.record_improve_usage(integer, integer),
  public.org_overview(uuid, integer), public.team_weekly_stats(uuid, date, date),
  public.member_weekly_stats(uuid, date), public.org_usage(uuid),
  public.my_weekly_stats(date), public.my_usage()
to authenticated;
-- purge_expired_data, write_audit, current_member and trigger functions: service role only

-- -----------------------------------------------------------------------------
-- 18. Seed: plans (placeholder values, confirm before the pilot)
-- -----------------------------------------------------------------------------
insert into public.plans (id, name, max_seats, max_improve_calls_monthly, monthly_token_quota) values
  ('pilot',   'Pilot',   50,  2000,  2000000),
  ('starter', 'Starter', 20,  1000,  1000000),
  ('pro',     'Pro',     200, 10000, 10000000);
