-- GymKeep control-plane foundation. Apply only after creating the control-plane Supabase project.
-- This project stores platform metadata; each gym's member/attendance data belongs in its own tenant project.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('owner','admin','support')),
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now()
);

create table if not exists public.gym_instances (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  owner_email text not null,
  status text not null default 'provisioning' check (status in ('provisioning','active','suspended','failed')),
  plan text not null default 'starter' check (plan in ('starter','growth','pro')),
  tenant_project_ref text unique,
  tenant_project_url text,
  provisioning_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gym_branding (
  gym_id uuid primary key references public.gym_instances(id) on delete cascade,
  app_name text not null default 'GymKeep',
  logo_url text,
  primary_color text not null default '#b7f34a',
  secondary_color text not null default '#151c18',
  theme text not null default 'dark' check (theme in ('dark','light','system')),
  layout_config jsonb not null default '{}'::jsonb,
  navigation_config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.gym_feature_flags (
  gym_id uuid not null references public.gym_instances(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (gym_id, feature_key)
);

create table if not exists public.gym_subscriptions (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gym_instances(id) on delete cascade,
  plan text not null check (plan in ('starter','growth','pro')),
  status text not null default 'pending' check (status in ('pending','trialing','active','past_due','cancelled','suspended')),
  provider text not null default 'razorpay',
  provider_customer_id text,
  provider_subscription_id text unique,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.platform_audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id),
  action text not null,
  gym_id uuid references public.gym_instances(id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists gym_instances_status_idx on public.gym_instances(status);
create index if not exists gym_subscriptions_gym_idx on public.gym_subscriptions(gym_id, created_at desc);
create index if not exists platform_audit_created_idx on public.platform_audit_log(created_at desc);

create or replace function public.is_platform_admin()
returns boolean
language sql stable security invoker
set search_path = public
as $$
  select exists (
    select 1 from public.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.status = 'active'
  );
$$;

alter table public.platform_admins enable row level security;
alter table public.gym_instances enable row level security;
alter table public.gym_branding enable row level security;
alter table public.gym_feature_flags enable row level security;
alter table public.gym_subscriptions enable row level security;
alter table public.platform_audit_log enable row level security;

create policy "platform admins read own admin record"
on public.platform_admins for select to authenticated
using (user_id = (select auth.uid()));

create policy "platform admins read gym instances"
on public.gym_instances for select to authenticated
using (public.is_platform_admin());

create policy "platform admins read branding"
on public.gym_branding for select to authenticated
using (public.is_platform_admin());

create policy "platform admins read feature flags"
on public.gym_feature_flags for select to authenticated
using (public.is_platform_admin());

create policy "platform admins read subscriptions"
on public.gym_subscriptions for select to authenticated
using (public.is_platform_admin());

create policy "platform admins read audit log"
on public.platform_audit_log for select to authenticated
using (public.is_platform_admin());

-- No browser-side write policies are intentionally provided. Provisioning, admin grants,
-- subscription updates, project creation and audit writes must run through trusted server workflows.
