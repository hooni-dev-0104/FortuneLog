-- Profile deactivation guard for account deletion flow
-- Date: 2026-03-15

alter table public.profiles
  add column if not exists is_deactivated boolean not null default false;

alter table public.profiles
  add column if not exists deactivated_at timestamptz;

create index if not exists idx_profiles_is_deactivated_true
  on public.profiles (is_deactivated)
  where is_deactivated = true;
