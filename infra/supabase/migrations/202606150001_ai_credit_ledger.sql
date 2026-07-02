-- AI generation credit ledger for consumable in-app purchases
-- Date: 2026-06-15

create table if not exists public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  provider text not null,
  provider_order_id text not null,
  event_id text not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_payment_webhook_events_user_created_at
  on public.payment_webhook_events (user_id, created_at desc);

alter table public.payment_webhook_events enable row level security;

create policy "Users can view own payment webhook events"
on public.payment_webhook_events
for select
using (auth.uid() = user_id);

create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  credit_type text not null,
  delta integer not null,
  reason text not null,
  source_provider text,
  source_event_id text,
  source_order_id text,
  related_report_id uuid references public.reports(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint credit_ledger_delta_nonzero check (delta <> 0),
  constraint credit_ledger_reason_check check (reason in ('purchase', 'consume', 'refund', 'grant', 'expire', 'adjustment'))
);

create unique index if not exists uq_credit_ledger_source_event
  on public.credit_ledger (source_provider, source_event_id)
  where source_provider is not null and source_event_id is not null;

-- RevenueCat can retry or emit multiple paid events around the same store transaction.
-- Event-level idempotency is still recorded above, but purchase grants must also be
-- bounded by the provider transaction/order id so one real purchase grants credits once.
create unique index if not exists uq_credit_ledger_purchase_order
  on public.credit_ledger (source_provider, source_order_id, reason, credit_type)
  where source_provider is not null
    and source_order_id is not null
    and reason = 'purchase';

create index if not exists idx_credit_ledger_user_type_created_at
  on public.credit_ledger (user_id, credit_type, created_at desc);

create or replace view public.credit_balances
with (security_invoker = true)
as
select
  user_id,
  credit_type,
  coalesce(sum(delta), 0)::integer as balance
from public.credit_ledger
group by user_id, credit_type;

create or replace function public.finalize_ai_interpretation_report(
  p_user_id uuid,
  p_chart_id uuid,
  p_content jsonb,
  p_source_event_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_balance integer;
  report_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext(p_user_id::text || ':ai_interpretation'));

  select coalesce(sum(delta), 0)::integer
  into current_balance
  from public.credit_ledger
  where user_id = p_user_id
    and credit_type = 'ai_interpretation';

  if coalesce(current_balance, 0) < 1 then
    return null;
  end if;

  insert into public.credit_ledger (
    user_id,
    credit_type,
    delta,
    reason,
    source_provider,
    source_event_id,
    metadata
  ) values (
    p_user_id,
    'ai_interpretation',
    -1,
    'consume',
    'engine-api',
    p_source_event_id,
    coalesce(p_metadata, '{}'::jsonb)
  );

  update public.reports
  set
    content_json = p_content,
    is_paid_content = true,
    visible = true
  where user_id = p_user_id
    and chart_id = p_chart_id
    and report_type = 'ai_interpretation'
  returning id into report_id;

  if report_id is null then
    insert into public.reports (
      user_id,
      chart_id,
      report_type,
      content_json,
      is_paid_content,
      visible
    ) values (
      p_user_id,
      p_chart_id,
      'ai_interpretation',
      p_content,
      true,
      true
    )
    returning id into report_id;
  end if;

  return report_id;
exception
  when unique_violation then
    return null;
end;
$$;

alter table public.credit_ledger enable row level security;

create policy "Users can view own credit ledger"
on public.credit_ledger
for select
using (auth.uid() = user_id);

insert into public.products (code, name, price, currency, product_type)
values
  ('fortunelog_ai_credit_1', 'AI 사주풀이 1회권', 1500, 'KRW', 'one_time'),
  ('fortunelog_ai_credit_5', 'AI 사주풀이 5회권', 5500, 'KRW', 'one_time'),
  ('fortunelog_ai_credit_10', 'AI 사주풀이 10회권', 10000, 'KRW', 'one_time')
on conflict (code) do update set
  name = excluded.name,
  price = excluded.price,
  currency = excluded.currency,
  product_type = excluded.product_type;
