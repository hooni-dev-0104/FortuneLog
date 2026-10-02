begin;
-- The old generation endpoint saved fixed examples as paid/visible reports.
-- Preserve the rows for review while closing direct Data API exposure as well.
update public.reports set visible = false
  where report_type in ('summary', 'personality', 'relationship', 'career');
create policy "Unverified report types remain private"
on public.reports as restrictive for select to anon, authenticated
using (report_type in ('daily', 'ai_interpretation'));
-- Later entitlement synchronization cannot undo this restrictive read policy.
commit;
