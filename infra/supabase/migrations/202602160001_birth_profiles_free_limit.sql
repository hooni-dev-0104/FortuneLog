begin;

drop index if exists public.ux_birth_profiles_user_id;

alter table public.birth_profiles
  add column if not exists profile_name text,
  add column if not exists profile_tag text;

update public.birth_profiles
set profile_name = '내 출생정보'
where profile_name is null or btrim(profile_name) = '';

update public.birth_profiles
set profile_tag = '본인'
where profile_tag is null;

alter table public.birth_profiles
  alter column profile_name set default '내 출생정보',
  alter column profile_name set not null;

alter table public.birth_profiles
  drop constraint if exists birth_profiles_profile_name_len_check;
alter table public.birth_profiles
  add constraint birth_profiles_profile_name_len_check
  check (char_length(btrim(profile_name)) between 1 and 24);

alter table public.birth_profiles
  drop constraint if exists birth_profiles_profile_tag_len_check;
alter table public.birth_profiles
  add constraint birth_profiles_profile_tag_len_check
  check (profile_tag is null or char_length(btrim(profile_tag)) <= 16);

create or replace function public.enforce_birth_profiles_free_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_count integer;
begin
  if new.user_id is null then
    return new;
  end if;

  select count(*)
    into existing_count
  from public.birth_profiles
  where user_id = new.user_id
    and id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

  if existing_count >= 4 then
    raise exception 'birth_profiles_limit_exceeded: free tier allows up to 4 profiles per user';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_birth_profiles_free_limit on public.birth_profiles;
create trigger trg_birth_profiles_free_limit
before insert or update of user_id
on public.birth_profiles
for each row
execute function public.enforce_birth_profiles_free_limit();

commit;
