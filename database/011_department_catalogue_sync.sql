begin;
create function portal_private.sync_curriculum_departments() returns trigger language plpgsql security definer set search_path='' as $$declare s record;old_prog uuid;new_prog uuid;begin
 old_prog:=(to_jsonb(old)->>'programme_id')::uuid;new_prog:=(to_jsonb(new)->>'programme_id')::uuid;
 for s in select p.id from public.icp_profiles p join public.icp_user_roles r on r.user_id=p.id where r.role='student' and p.department_id in (select department_id from public.icp_programmes where id in (old_prog,new_prog)) loop perform portal_private.sync_department_courses(s.id);end loop;
 return null;end$$;
create trigger icp_catalogue_enrolment after insert or update or delete on icp_curriculum for each row execute function portal_private.sync_curriculum_departments();
revoke all on function portal_private.sync_curriculum_departments() from public,anon,authenticated;
commit;
