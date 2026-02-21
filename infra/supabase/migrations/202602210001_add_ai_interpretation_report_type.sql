do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'report_type'
      and e.enumlabel = 'ai_interpretation'
  ) then
    alter type public.report_type add value 'ai_interpretation';
  end if;
end $$;
