begin transaction read only;
select current_database() as database_name;
select jobname,active from cron.job where jobname='gling-safety-monitor-every-minute';
select p.id,p.nickname,p.city_id,p.verification_level,p.ai_safety_consent_at is not null as has_ai_consent,u.raw_user_meta_data->>'seed' as internal_seed from public.profiles p join auth.users u on u.id=p.id where u.email like '%@seed.gling.invalid' and p.city_id='vancouver' order by p.id;
select count(*) as existing_published_posts from public.posts where status='published';
rollback;
