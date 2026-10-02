"""Real PostgreSQL transaction tests, isolated from Supabase/production."""
import concurrent.futures
import json
import pathlib
import subprocess
import sys
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[3]
IMAGE = "postgres:17-alpine@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24"
NAME = "fortunelog-credit-test-" + uuid.uuid4().hex[:12]


def command(*args, input=None, check=True):
    return subprocess.run(args, input=input, text=True, capture_output=True, check=check)


def sql(statement):
    result = command("docker", "exec", "-i", NAME, "psql", "-h", "127.0.0.1", "-U", "postgres", "-v", "ON_ERROR_STOP=1", "-Atq", input=statement)
    return result.stdout.strip()


def ident(n):
    return f"00000000-0000-4000-8000-{n:012d}"


def prepare(user, chart, key):
    return json.loads(sql(f"select public.prepare_ai_interpretation_request('{ident(user)}','{ident(chart)}','{ident(key)}');"))


def finalize(user, chart, key, summary="original", source="openai"):
    content = json.dumps(dict(source=source, summary=summary))
    return json.loads(sql(f"select public.finalize_ai_interpretation_request('{ident(user)}','{ident(chart)}','{ident(key)}','{content}'::jsonb);"))


def balance(user):
    return int(sql(f"select coalesce(sum(delta),0) from credit_ledger where user_id='{ident(user)}';"))


try:
    command("docker", "run", "--detach", "--rm", "--name", NAME, "--network", "none",
            "-e", "POSTGRES_HOST_AUTH_METHOD=trust", IMAGE)
    # The entrypoint temporarily starts a socket-only server during initdb.
    # Wait for TCP so we cannot race its shutdown/restart into the final server.
    for _ in range(150):
        if command("docker", "exec", NAME, "pg_isready", "-h", "127.0.0.1", "-U", "postgres", check=False).returncode == 0:
            break
        time.sleep(0.2)
    else:
        raise RuntimeError("isolated Postgres did not become ready")
    sql("""
      create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as
        $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      grant usage on schema public, auth to anon, authenticated, service_role;
    """)
    for migration in sorted((ROOT / "infra/supabase/migrations").glob("*.sql")):
        sql(migration.read_text())
    for user in (1, 2, 3, 4):
        sql(f"""
          insert into auth.users values ('{ident(user)}');
          insert into birth_profiles(id,user_id,birth_datetime_local,birth_timezone,birth_location,calendar_type,gender)
          values ('{ident(user+10)}','{ident(user)}','2000-01-01','Asia/Seoul','fixture','solar','other');
          insert into saju_charts(id,user_id,birth_profile_id,chart_json,five_elements_json,engine_version)
          values ('{ident(user+20)}','{ident(user)}','{ident(user+10)}','{{}}','{{}}','fixture');
          insert into credit_ledger(user_id,credit_type,delta,reason)
          values ('{ident(user)}','ai_interpretation',1,'grant');
        """)
    sql(f"""insert into saju_charts(id,user_id,birth_profile_id,chart_json,five_elements_json,engine_version)
         values ('{ident(99)}','{ident(1)}','{ident(11)}','{{}}','{{}}','fixture-2');""")

    assert prepare(1, 21, 101)["status"] == "pending"
    assert prepare(1, 99, 101)["status"] == "key_conflict"
    assert prepare(2, 22, 101)["status"] == "key_conflict"
    assert prepare(2, 21, 102)["status"] == "chart_not_found"
    assert finalize(1, 21, 101, source="unverified")["status"] == "invalid_content"
    prepare(1, 21, 104)
    free = finalize(1, 21, 104, source="fallback")
    assert free["content"]["creditCharged"] is False
    assert finalize(1, 21, 104) == free  # racing paid candidate must remain free
    assert prepare(1, 21, 104) == free
    assert balance(1) == 1
    assert sql("select count(*) from reports") == "0"
    assert finalize(1, 21, 101, summary="")["status"] == "invalid_content"

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        replies = list(pool.map(lambda n: finalize(1, 21, 101, summary=f"candidate-{n}"), range(8)))
    assert all(reply == replies[0] for reply in replies), replies
    assert balance(1) == 0
    assert prepare(1, 21, 101) == replies[0]  # lost response, now zero balance
    assert finalize(1, 21, 101, source="fallback") == replies[0]
    assert sql(f"select count(*) from credit_ledger where user_id='{ident(1)}' and reason='consume'") == "1"

    prepare(2, 22, 201); prepare(2, 22, 202)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        replies = list(pool.map(lambda key: finalize(2, 22, key), [201, 202]))
    assert sorted(reply["status"] for reply in replies) == ["completed", "insufficient_credits"]
    assert balance(2) == 0

    prepare(3, 23, 301)
    sql("""create function fail_consumption() returns trigger language plpgsql as $$
      begin if new.reason='consume' then raise exception 'fixture storage failure'; end if; return new; end; $$;
      create trigger fixture_failure before insert on credit_ledger for each row execute function fail_consumption();""")
    try:
        finalize(3, 23, 301)
        raise AssertionError("injected failure should abort finalization")
    except subprocess.CalledProcessError:
        pass
    assert balance(3) == 1
    assert sql(f"select count(*) from reports where user_id='{ident(3)}'") == "0"
    assert prepare(3, 23, 301)["status"] == "pending"
    sql("drop trigger fixture_failure on credit_ledger; drop function fail_consumption();")
    assert finalize(3, 23, 301)["status"] == "completed"
    assert balance(3) == 0

    prepare(4, 24, 401)
    sql(f"update profiles set is_deactivated=true where id='{ident(4)}';")
    assert finalize(4, 24, 401)["status"] == "account_locked"
    assert balance(4) == 1

    # A later webhook setting visible=true must not expose the old fixed report.
    sql(f"""insert into reports(user_id,chart_id,report_type,content_json,is_paid_content,visible)
      values ('{ident(1)}','{ident(21)}','career','{{"summary":"fixed example"}}',true,true);
      grant select on reports to authenticated;""")
    visible = sql(f"""set role authenticated; set request.jwt.claim.sub='{ident(1)}';
      select count(*) from reports where report_type='career';""")
    assert visible == "0", visible
    assert sql("select has_function_privilege('anon','public.finalize_ai_interpretation_request(uuid,uuid,uuid,jsonb)','EXECUTE')") == "f"
    assert sql("select has_function_privilege('authenticated','public.prepare_ai_interpretation_request(uuid,uuid,uuid)','EXECUTE')") == "f"
    assert sql("select has_function_privilege('service_role','public.finalize_ai_interpretation_report(uuid,uuid,jsonb,text,jsonb)','EXECUTE')") == "f"
    assert sql("select has_table_privilege('authenticated','public.ai_interpretation_requests','SELECT')") == "f"
    # Immutable result persists when a newer request replaces the displayed report.
    sql(f"insert into credit_ledger(user_id,credit_type,delta,reason) values ('{ident(1)}','ai_interpretation',1,'grant');")
    original = prepare(1, 21, 101)
    prepare(1, 21, 103)
    assert finalize(1, 21, 103, summary="new explicit generation")["status"] == "completed"
    assert prepare(1, 21, 101) == original
    sql(f"delete from auth.users where id='{ident(1)}';")
    assert sql(f"select count(*) from ai_interpretation_requests where user_id='{ident(1)}'") == "0"
    print("PASS: full migration chain, fallback/invalid no-charge, replay, 8-way duplicate, competing keys,")
    print("      atomic rollback/retry, user/chart binding, account lock, legacy visibility, RPC privileges, deletion")
except subprocess.CalledProcessError as error:
    # This process only handles generated local fixtures, never production data.
    print(error.stderr or error.stdout or str(error), file=sys.stderr)
    raise
finally:
    command("docker", "rm", "--force", NAME, check=False)
