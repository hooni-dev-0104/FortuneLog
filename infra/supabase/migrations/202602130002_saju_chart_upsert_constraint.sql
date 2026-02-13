-- Prevent duplicate chart rows for the same user/birth profile/engine version
create unique index if not exists uq_saju_charts_user_birth_engine
on public.saju_charts (user_id, birth_profile_id, engine_version);
