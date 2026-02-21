begin;

-- Keep one row per (user_id, chart_id, report_type='daily', target_date).
with ranked as (
  select
    id,
    row_number() over (
      partition by user_id, chart_id, report_type, target_date
      order by created_at desc, id desc
    ) as rn
  from public.reports
  where report_type = 'daily'
    and target_date is not null
    and chart_id is not null
)
delete from public.reports r
using ranked x
where r.id = x.id
  and x.rn > 1;

drop index if exists public.uq_reports_user_type_target_date;

-- PostgREST on_conflict=user_id,chart_id,report_type,target_date needs matching unique index.
create unique index if not exists uq_reports_user_chart_type_target_date
  on public.reports (user_id, chart_id, report_type, target_date);

-- Query accelerator for daily report lookups by user+chart+date.
create index if not exists idx_reports_user_chart_daily_target_date
  on public.reports (user_id, chart_id, target_date desc)
  where report_type = 'daily';

commit;

