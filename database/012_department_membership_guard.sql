-- Enforce the current department on every private course-content request.
create or replace function portal_private.member(c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and portal_private.role_name()='student' and exists(
 select 1 from public.icp_course_memberships m join public.icp_profiles p on p.id=m.student_id join public.icp_courses co on co.id=m.course_id
 where m.course_id=c and m.student_id=auth.uid() and m.status='enrolled' and p.identity_verified and (co.is_demo or portal_private.department_course(p.department_id,c)))
$$;
