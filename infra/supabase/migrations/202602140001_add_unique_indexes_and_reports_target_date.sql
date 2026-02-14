-- FortuneLog schema patch
-- Date: 2026-02-14
--
-- Fixes:
-- - Required unique indexes for PostgREST upsert (on_conflict) to work.
-- - Adds reports.target_date to support querying daily fortunes by date and idempotency.

alter table public.reports
  add column if not exists target_date date;

-- Upsert for saju_charts uses on_conflict=user_id,birth_profile_id,engine_version
create unique index if not exists uq_saju_charts_user_birth_engine
  on public.saju_charts (user_id, birth_profile_id, engine_version);

-- Upsert for non-daily reports uses on_conflict=user_id,chart_id,report_type
create unique index if not exists uq_reports_user_chart_type_non_daily
  on public.reports (user_id, chart_id, report_type)
  where report_type <> 'daily';

-- Daily fortune should be idempotent by (user_id, date). Chart may change; we overwrite chart_id/content.
create unique index if not exists uq_reports_user_daily_date
  on public.reports (user_id, report_type, target_date)
  where report_type = 'daily';

create index if not exists idx_reports_user_type_target_date
  on public.reports (user_id, report_type, target_date desc);

