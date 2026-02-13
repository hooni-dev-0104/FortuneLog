-- FortuneLog initial schema
-- Date: 2026-02-13

create extension if not exists pgcrypto;

create type public.calendar_type as enum ('solar', 'lunar');
create type public.report_type as enum ('summary', 'personality', 'relationship', 'career', 'daily');
create type public.product_type as enum ('one_time', 'subscription');
create type public.order_status as enum ('pending', 'paid', 'failed', 'canceled');
create type public.subscription_status as enum ('active', 'grace', 'expired', 'canceled');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text,
  created_at timestamptz not null default now()
);

create table if not exists public.birth_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  birth_datetime_local timestamp not null,
  birth_timezone text not null,
  birth_location text not null,
  calendar_type public.calendar_type not null,
  is_leap_month boolean not null default false,
  gender text not null,
  unknown_birth_time boolean not null default false,
  created_at timestamptz not null default now(),
  constraint birth_profiles_gender_check check (gender in ('male', 'female', 'other'))
);

create table if not exists public.saju_charts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  birth_profile_id uuid not null references public.birth_profiles(id) on delete cascade,
  chart_json jsonb not null,
  five_elements_json jsonb not null,
  engine_version text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  chart_id uuid not null references public.saju_charts(id) on delete cascade,
  report_type public.report_type not null,
  content_json jsonb not null,
  is_paid_content boolean not null default false,
  visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  price integer not null,
  currency text not null default 'KRW',
  product_type public.product_type not null,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  status public.order_status not null default 'pending',
  provider text not null,
  provider_order_id text,
  created_at timestamptz not null default now(),
  unique (provider, provider_order_id)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_code text not null,
  status public.subscription_status not null,
  started_at timestamptz not null,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_birth_profiles_user_created_at on public.birth_profiles (user_id, created_at desc);
create index if not exists idx_saju_charts_user_created_at on public.saju_charts (user_id, created_at desc);
create index if not exists idx_reports_user_type_created_at on public.reports (user_id, report_type, created_at desc);
create index if not exists idx_orders_user_created_at on public.orders (user_id, created_at desc);
create index if not exists idx_subscriptions_user_status on public.subscriptions (user_id, status);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.birth_profiles enable row level security;
alter table public.saju_charts enable row level security;
alter table public.reports enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.subscriptions enable row level security;

create policy "Users can view own profile"
on public.profiles
for select
using (auth.uid() = id);

create policy "Users can update own profile"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "Users can insert own birth profile"
on public.birth_profiles
for insert
with check (auth.uid() = user_id);

create policy "Users can view own birth profiles"
on public.birth_profiles
for select
using (auth.uid() = user_id);

create policy "Users can update own birth profiles"
on public.birth_profiles
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own birth profiles"
on public.birth_profiles
for delete
using (auth.uid() = user_id);

create policy "Users can view own charts"
on public.saju_charts
for select
using (auth.uid() = user_id);

create policy "Users can insert own charts"
on public.saju_charts
for insert
with check (auth.uid() = user_id);

create policy "Users can view own reports"
on public.reports
for select
using (auth.uid() = user_id and visible = true);

create policy "Users can insert own reports"
on public.reports
for insert
with check (auth.uid() = user_id);

create policy "Everyone can view products"
on public.products
for select
using (true);

create policy "Users can view own orders"
on public.orders
for select
using (auth.uid() = user_id);

create policy "Users can insert own orders"
on public.orders
for insert
with check (auth.uid() = user_id);

create policy "Users can view own subscriptions"
on public.subscriptions
for select
using (auth.uid() = user_id);

-- Server-side updates (service role) bypass RLS in Supabase.
