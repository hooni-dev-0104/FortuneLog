-- Prevent duplicate non-daily reports for same user/chart/type
create unique index if not exists uq_reports_user_chart_type_nondaily
on public.reports (user_id, chart_id, report_type)
where report_type <> 'daily';
