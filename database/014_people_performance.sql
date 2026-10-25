begin;
create or replace function public.icp_person_analytics(person uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;kind text;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 select role into kind from public.icp_user_roles where user_id=person;
 select jsonb_build_object('role',kind,'courses',coalesce(jsonb_agg(x),'[]')) into result from (
 select c.id,c.code,c.title,m.status,
 (select count(*) from public.icp_assignments a where a.course_id=c.id and a.status<>'draft') assignments,
 (select count(*) from public.icp_submissions s join public.icp_assignments a on a.id=s.assignment_id where a.course_id=c.id and (kind='lecturer' or s.student_id=person)) submissions,
 (select coalesce(jsonb_agg(g),'[]') from (select p.id student_id,p.full_name,a.title assignment,a.session_id,a.semester_id,f.score,a.max_score,f.published from public.icp_submissions s join public.icp_profiles p on p.id=s.student_id join public.icp_assignments a on a.id=s.assignment_id join public.icp_assignment_feedback f on f.submission_id=s.id where a.course_id=c.id and (kind='lecturer' or s.student_id=person)) g) grades,
 case when kind='lecturer' then (select coalesce(jsonb_agg(roster),'[]') from (
 select p.id,p.full_name,p.matric_number,cm.status,
 (select count(*) from public.icp_submissions sub join public.icp_assignments a on a.id=sub.assignment_id where sub.student_id=p.id and a.course_id=c.id) submissions,
 (select count(*) from public.icp_submissions sub join public.icp_assignments a on a.id=sub.assignment_id join public.icp_assignment_feedback f on f.submission_id=sub.id where sub.student_id=p.id and a.course_id=c.id) graded,
 (select round(100*sum(f.score)/nullif(sum(a.max_score),0),1) from public.icp_submissions sub join public.icp_assignments a on a.id=sub.assignment_id join public.icp_assignment_feedback f on f.submission_id=sub.id where sub.student_id=p.id and a.course_id=c.id) percentage
 from public.icp_course_memberships cm join public.icp_profiles p on p.id=cm.student_id where cm.course_id=c.id order by p.full_name
 ) roster) else '[]'::jsonb end students
 from public.icp_courses c left join public.icp_course_memberships m on m.course_id=c.id and m.student_id=person
 where not c.is_demo and ((kind='student' and portal_private.student_course(person,c.id)) or(kind='lecturer' and exists(select 1 from public.icp_lecturer_allocations l where l.course_id=c.id and l.lecturer_id=person))) order by c.code
 ) x;return result;end$$;
commit;
