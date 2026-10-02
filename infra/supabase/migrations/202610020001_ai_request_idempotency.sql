begin;

-- Reviewed offline: CLI scaffolding was unavailable in the saved cloud environment.
-- Apply only through the normal migration review/release process.
create table public.ai_interpretation_requests (
  request_key uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  chart_id uuid not null references public.saju_charts(id) on delete cascade,
  result_json jsonb,
  report_id uuid references public.reports(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint ai_request_completion check ((result_json is null) = (completed_at is null))
);
create index ai_requests_user_chart on public.ai_interpretation_requests(user_id, chart_id);
alter table public.ai_interpretation_requests enable row level security;
revoke all on public.ai_interpretation_requests from public, anon, authenticated;
grant select, insert, update, delete on public.ai_interpretation_requests to service_role;

-- Only the authenticated engine's service role can call these RPCs. The engine
-- derives p_user_id from the JWT, never from a request body.
create function public.prepare_ai_interpretation_request(
  p_user_id uuid, p_chart_id uuid, p_request_key uuid
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  existing public.ai_interpretation_requests%rowtype;
begin
  if not exists (select 1 from public.profiles where id = p_user_id and not is_deactivated) then
    return jsonb_build_object('status', 'account_locked');
  end if;
  if not exists (select 1 from public.saju_charts where id = p_chart_id and user_id = p_user_id) then
    return jsonb_build_object('status', 'chart_not_found');
  end if;
  insert into public.ai_interpretation_requests(request_key, user_id, chart_id)
  values (p_request_key, p_user_id, p_chart_id)
  on conflict (request_key) do nothing;
  select * into existing from public.ai_interpretation_requests where request_key = p_request_key;
  if existing.user_id <> p_user_id or existing.chart_id <> p_chart_id then
    return jsonb_build_object('status', 'key_conflict');
  end if;
  if existing.result_json is not null then
    return jsonb_build_object('status', 'completed', 'content', existing.result_json);
  end if;
  return jsonb_build_object('status', 'pending');
end;
$$;

create function public.finalize_ai_interpretation_request(
  p_user_id uuid, p_chart_id uuid, p_request_key uuid, p_content jsonb
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  existing public.ai_interpretation_requests%rowtype;
  saved_report_id uuid;
  saved_content jsonb;
  current_balance integer;
begin
  select * into existing from public.ai_interpretation_requests
    where request_key = p_request_key for update;
  if not found then
    return jsonb_build_object('status', 'request_missing');
  end if;
  if existing.user_id <> p_user_id or existing.chart_id <> p_chart_id then
    return jsonb_build_object('status', 'key_conflict');
  end if;
  -- Lock profile against a concurrent deactivation until this transaction ends.
  perform 1 from public.profiles where id = p_user_id and not is_deactivated for share;
  if not found then
    return jsonb_build_object('status', 'account_locked');
  end if;
  if not exists (select 1 from public.saju_charts where id = p_chart_id and user_id = p_user_id) then
    return jsonb_build_object('status', 'chart_not_found');
  end if;
  -- Replay comes before the balance/content check, including after a lost response.
  if existing.result_json is not null then
    return jsonb_build_object('status', 'completed', 'content', existing.result_json);
  end if;
  if p_content is null or jsonb_typeof(p_content) <> 'object'
      or coalesce(p_content->>'source', '') not in ('openai', 'fallback')
      or jsonb_typeof(p_content->'summary') is distinct from 'string'
      or length(trim(p_content->>'summary')) = 0 then
    return jsonb_build_object('status', 'invalid_content');
  end if;

  if p_content->>'source' = 'fallback' then
    -- A free response also terminates the request, so racing duplicates can never
    -- show "free" while another attempt charges for that same request key.
    saved_content := p_content || jsonb_build_object('creditCharged', false, 'requestKey', p_request_key);
    update public.ai_interpretation_requests
      set result_json = saved_content, completed_at = now() where request_key = p_request_key;
    return jsonb_build_object('status', 'completed', 'content', saved_content);
  end if;

  -- Same per-user lock as the legacy credit transaction; distinct keys compete
  -- for the same balance and can never overdraw it.
  perform pg_advisory_xact_lock(hashtext(p_user_id::text || ':ai_interpretation'));
  select coalesce(sum(delta), 0)::integer into current_balance
    from public.credit_ledger where user_id = p_user_id and credit_type = 'ai_interpretation';
  if current_balance < 1 then
    return jsonb_build_object('status', 'insufficient_credits');
  end if;
  saved_content := p_content || jsonb_build_object('creditCharged', true, 'requestKey', p_request_key);
  update public.reports set content_json = saved_content, is_paid_content = true, visible = true
    where user_id = p_user_id and chart_id = p_chart_id and report_type = 'ai_interpretation'
    returning id into saved_report_id;
  if saved_report_id is null then
    insert into public.reports(user_id, chart_id, report_type, content_json, is_paid_content, visible)
      values (p_user_id, p_chart_id, 'ai_interpretation', saved_content, true, true)
      returning id into saved_report_id;
  end if;
  insert into public.credit_ledger(user_id, credit_type, delta, reason, source_provider,
                                  source_event_id, related_report_id, metadata)
    values (p_user_id, 'ai_interpretation', -1, 'consume', 'engine-api',
            'ai-request:' || p_request_key::text, saved_report_id,
            jsonb_build_object('chartId', p_chart_id, 'requestKey', p_request_key));
  update public.ai_interpretation_requests
    set result_json = saved_content, report_id = saved_report_id, completed_at = now()
    where request_key = p_request_key;
  return jsonb_build_object('status', 'completed', 'content', saved_content);
  -- Any storage failure rolls back report, consumption and completion together.
end;
$$;
revoke all on function public.prepare_ai_interpretation_request(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.finalize_ai_interpretation_request(uuid, uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.prepare_ai_interpretation_request(uuid, uuid, uuid) to service_role;
grant execute on function public.finalize_ai_interpretation_request(uuid, uuid, uuid, jsonb) to service_role;
-- Old engine versions must fail closed instead of bypassing the request contract.
revoke all on function public.finalize_ai_interpretation_report(uuid, uuid, jsonb, text, jsonb)
  from public, anon, authenticated, service_role;
commit;
