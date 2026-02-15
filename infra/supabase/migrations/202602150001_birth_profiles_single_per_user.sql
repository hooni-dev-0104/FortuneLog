-- Enforce single birth profile per user.
-- Keeps the newest profile (created_at DESC) and deletes older duplicates.

begin;

with ranked as (
  select
    id,
    user_id,
    row_number() over (partition by user_id order by created_at desc, id desc) as rn
  from public.birth_profiles
)
delete from public.birth_profiles bp
using ranked r
where bp.id = r.id
  and r.rn > 1;

-- After duplicates are removed, enforce uniqueness.
create unique index if not exists ux_birth_profiles_user_id
  on public.birth_profiles (user_id);

commit;

