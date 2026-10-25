begin;
create function portal_private.student_course(student uuid,course uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.icp_profiles p join public.icp_curriculum m on m.programme_id=p.programme_id and m.session_id=p.session_id and m.semester_id=p.semester_id and m.year_level=p.year_level join public.icp_programmes pr on pr.id=m.programme_id where p.id=student and m.course_id=course and pr.department_id=p.department_id)
$$;
create or replace function portal_private.sync_department_courses(student uuid) returns void language plpgsql security definer set search_path='' as $$declare p public.icp_profiles;begin
 select * into p from public.icp_profiles where id=student;
 if p.approved and p.identity_verified and exists(select 1 from public.icp_user_roles where user_id=student and role='student') then
 update public.icp_course_memberships m set status='suspended',reason='Academic context changed',updated_at=now() where m.student_id=student and status='enrolled' and not portal_private.student_course(student,m.course_id);
 update public.icp_course_memberships m set status='enrolled',reason='Academic context restored',updated_at=now() where m.student_id=student and status='suspended' and reason in ('Academic context changed','Department changed') and portal_private.student_course(student,m.course_id);
 insert into public.icp_course_memberships(course_id,student_id) select c.id,student from public.icp_courses c where not c.is_demo and portal_private.student_course(student,c.id) on conflict do nothing;
 end if;end$$;
create or replace function portal_private.member(c uuid) returns boolean language sql stable security definer set search_path='' as $$select portal_private.role_name()='student' and exists(select 1 from public.icp_course_memberships m join public.icp_profiles p on p.id=m.student_id where m.course_id=c and m.student_id=auth.uid() and m.status='enrolled' and p.identity_verified and portal_private.student_course(p.id,c))$$;
create or replace function portal_private.teaches(c uuid) returns boolean language sql stable security definer set search_path='' as $$select portal_private.role_name()='lecturer' and exists(select 1 from public.icp_lecturer_allocations l join public.icp_curriculum m on m.course_id=l.course_id join public.icp_sessions s on s.id=m.session_id where l.lecturer_id=auth.uid() and l.course_id=c and s.is_active)$$;
create policy curriculum_member_read on public.icp_curriculum for select to authenticated using(portal_private.course_access(course_id));
-- Preserve historic content; only explicitly tagged current-term material appears to students.
alter table public.icp_lecture_notes add column session_id uuid references public.icp_sessions,add column semester_id smallint references public.icp_semesters;
alter table public.icp_assignments add column session_id uuid references public.icp_sessions,add column semester_id smallint references public.icp_semesters;
create function portal_private.term_matches(sess uuid,sem smallint) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.icp_profiles where id=auth.uid() and session_id=sess and semester_id=sem)$$;
create policy note_current_term on public.icp_lecture_notes as restrictive for select to authenticated using(portal_private.role_name()<>'student' or portal_private.term_matches(session_id,semester_id));
create policy assignment_current_term on public.icp_assignments as restrictive for select to authenticated using(portal_private.role_name()<>'student' or portal_private.term_matches(session_id,semester_id));
create function portal_private.check_material_term() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.session_id is null or new.semester_id is null or not exists(select 1 from public.icp_curriculum m join public.icp_sessions s on s.id=m.session_id where m.course_id=new.course_id and m.session_id=new.session_id and m.semester_id=new.semester_id and s.is_active) then raise exception 'Choose a mapped semester in the current session';end if;return new;end$$;
create trigger icp_note_term before insert or update of session_id,semester_id,course_id on public.icp_lecture_notes for each row execute function portal_private.check_material_term();
create trigger icp_assignment_term before insert or update of session_id,semester_id,course_id on public.icp_assignments for each row execute function portal_private.check_material_term();
create function portal_private.check_submission_term() returns trigger language plpgsql security definer set search_path='' as $$begin
 if not exists(select 1 from public.icp_assignments a where a.id=new.assignment_id and portal_private.term_matches(a.session_id,a.semester_id)) then raise exception 'Assignment is outside your current session or semester';end if;return new;end$$;
create trigger icp_submission_term before insert or update on public.icp_submissions for each row execute function portal_private.check_submission_term();
revoke all on function portal_private.check_material_term(),portal_private.check_submission_term() from public,anon,authenticated;
-- Atomic department/programme + batch course setup. Invalid rows roll back the whole import.
create function public.icp_save_department(details jsonb,rows jsonb) returns uuid language plpgsql security definer set search_path='' as $$declare dept uuid;prog uuid;c uuid;r jsonb;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 if length(trim(details->>'name'))<2 or length(trim(details->>'programme_code'))<2 or length(trim(details->>'programme_name'))<2 then raise exception 'Department and programme details required';end if;
 if jsonb_array_length(rows)<1 or jsonb_array_length(rows)>500 then raise exception 'Add between 1 and 500 courses';end if;
 insert into public.icp_departments(name) values(trim(details->>'name')) on conflict(name) do update set name=excluded.name returning id into dept;
 insert into public.icp_programmes(department_id,code,name) values(dept,upper(trim(details->>'programme_code')),trim(details->>'programme_name')) on conflict(code) do update set name=excluded.name where public.icp_programmes.department_id=dept returning id into prog;
 if prog is null then raise exception 'Programme code belongs to another department';end if;
 for r in select * from jsonb_array_elements(rows) loop
 if nullif(trim(r->>'code'),'') is null or nullif(trim(r->>'title'),'') is null or (r->>'year_level')::int not in(1,2) or (r->>'semester_id')::int not in(1,2) then raise exception 'Each course needs code, title, ND level and semester';end if;
 insert into public.icp_courses(code,title,department_id,units,is_demo) values(upper(trim(r->>'code')),trim(r->>'title'),dept,nullif(r->>'units','')::smallint,false) on conflict(code,is_demo) do update set title=excluded.title,units=excluded.units returning id into c;
 insert into public.icp_curriculum(programme_id,course_id,session_id,semester_id,year_level) values(prog,c,(details->>'session_id')::uuid,(r->>'semester_id')::smallint,(r->>'year_level')::smallint) on conflict do nothing;
 end loop;return dept;end$$;
-- Numeric academic analytics only: no file bodies or written feedback exposed to admins.
create function public.icp_person_analytics(person uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;kind text;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 select role into kind from public.icp_user_roles where user_id=person;
 select jsonb_build_object('role',kind,'courses',coalesce(jsonb_agg(x),'[]')) into result from (
 select c.id,c.code,c.title,m.status,
 (select count(*) from public.icp_assignments a where a.course_id=c.id and a.status<>'draft') assignments,
 (select count(*) from public.icp_submissions s join public.icp_assignments a on a.id=s.assignment_id where a.course_id=c.id and (kind='lecturer' or s.student_id=person)) submissions,
 (select coalesce(jsonb_agg(g),'[]') from (select p.id student_id,p.full_name,a.title assignment,f.score,a.max_score,f.published from public.icp_submissions s join public.icp_profiles p on p.id=s.student_id join public.icp_assignments a on a.id=s.assignment_id join public.icp_assignment_feedback f on f.submission_id=s.id where a.course_id=c.id and (kind='lecturer' or s.student_id=person)) g) grades
 from public.icp_courses c left join public.icp_course_memberships m on m.course_id=c.id and m.student_id=person
 where not c.is_demo and ((kind='student' and portal_private.student_course(person,c.id)) or(kind='lecturer' and exists(select 1 from public.icp_lecturer_allocations l where l.course_id=c.id and l.lecturer_id=person))) order by c.code
 ) x;return result;end$$;
revoke all on function portal_private.student_course(uuid,uuid),portal_private.term_matches(uuid,smallint) from public,anon;
grant execute on function portal_private.term_matches(uuid,smallint) to authenticated;
revoke all on function public.icp_save_department(jsonb,jsonb),public.icp_person_analytics(uuid) from public,anon;
grant execute on function public.icp_save_department(jsonb,jsonb),public.icp_person_analytics(uuid) to authenticated;
do $$declare p record;begin for p in select id from public.icp_profiles where approved loop perform portal_private.sync_department_courses(p.id);end loop;end$$;
commit;
