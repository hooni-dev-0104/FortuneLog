-- Account deletion request queue (beta v1)
-- Date: 2026-03-15

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'requested',
  requested_reason text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  constraint account_deletion_requests_status_check
    check (status in ('requested', 'processing', 'completed', 'rejected', 'canceled'))
);

create index if not exists idx_account_deletion_requests_user_requested_at
  on public.account_deletion_requests (user_id, requested_at desc);

create unique index if not exists uq_account_deletion_requests_user_active
  on public.account_deletion_requests (user_id)
  where status in ('requested', 'processing');

alter table public.account_deletion_requests enable row level security;

create policy "Users can view own account deletion requests"
on public.account_deletion_requests
for select
using (auth.uid() = user_id);

create policy "Users can insert own account deletion requests"
on public.account_deletion_requests
for insert
with check (auth.uid() = user_id);
