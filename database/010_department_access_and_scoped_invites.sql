begin;
-- Department-based access does not fabricate a student's level or semester.
create function portal_private.department_course(department uuid,course uuid) returns boolean language sql stable security definer set search_path='' as $$
 select department is not null and exists(select 1 from public.icp_curriculum c join public.icp_programmes p on p.id=c.programme_id join public.icp_courses co on co.id=c.course_id where p.department_id=department and c.course_id=course and not co.is_demo)
$$;
create function portal_private.sync_department_courses(student uuid) returns void language plpgsql security definer set search_path='' as $$declare p public.icp_profiles;begin
 select * into p from public.icp_profiles where id=student;
 if p.approved and p.identity_verified and p.department_id is not null and exists(select 1 from public.icp_user_roles where user_id=p.id and role='student') then
  update public.icp_course_memberships m set status='suspended',reason='Department changed',updated_at=now() where m.student_id=p.id and m.status='enrolled' and not portal_private.department_course(p.department_id,m.course_id) and exists(select 1 from public.icp_courses c where c.id=m.course_id and not c.is_demo);
  update public.icp_course_memberships m set status='enrolled',reason='Department restored',updated_at=now() where m.student_id=p.id and m.status='suspended' and m.reason in ('Academic context changed','Department changed') and portal_private.department_course(p.department_id,m.course_id);
  insert into public.icp_course_memberships(course_id,student_id)
   select distinct c.course_id,p.id from public.icp_curriculum c join public.icp_programmes pr on pr.id=c.programme_id join public.icp_courses co on co.id=c.course_id where pr.department_id=p.department_id and not co.is_demo on conflict do nothing;
 end if;end$$;
create or replace function portal_private.enrol_student() returns trigger language plpgsql security definer set search_path='' as $$begin perform portal_private.sync_department_courses(new.id);return new;end$$;
drop trigger icp_auto_enrol on icp_profiles;
create trigger icp_auto_enrol after insert or update of approved,identity_verified,department_id,programme_id,session_id,semester_id,year_level on icp_profiles for each row execute function portal_private.enrol_student();
-- Run once for existing approved students, retaining explicit course removals.
do $$declare s record;begin for s in select p.id from public.icp_profiles p join public.icp_user_roles r on r.user_id=p.id where r.role='student' loop perform portal_private.sync_department_courses(s.id);end loop;end$$;
alter table icp_invitations add column programme_id uuid references icp_programmes;
alter table icp_invitations add column session_id uuid references icp_sessions;
alter table icp_invitations add column semester_id smallint references icp_semesters;
alter table icp_invitations add column year_level smallint check(year_level in (1,2));
create function public.icp_create_scoped_invite(details jsonb) returns jsonb language plpgsql security definer set search_path='' as $$declare chosen uuid[];dept uuid;prog uuid;sess uuid;sem smallint;level smallint;email text;result jsonb;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 dept:=nullif(details->>'department','')::uuid;prog:=nullif(details->>'programme_id','')::uuid;sess:=nullif(details->>'session_id','')::uuid;sem:=nullif(details->>'semester_id','')::smallint;level:=nullif(details->>'year_level','')::smallint;
 email:=nullif(trim(details->>'invitee_email'),'');
 select coalesce(array_agg(x::uuid),'{}') into chosen from jsonb_array_elements_text(coalesce(details->'courses','[]'::jsonb)) x;
 if email is not null then
  if dept is null or prog is null or sess is null or sem is null or level is null then raise exception 'Select department, programme, ND level, session and semester';end if;
  if not exists(select 1 from public.icp_programmes where id=prog and department_id=dept) then raise exception 'Programme does not belong to the selected department';end if;
  if cardinality(chosen)=0 then raise exception 'Select at least one available course';end if;
  if exists(select 1 from unnest(chosen) co where not exists(select 1 from public.icp_curriculum c join public.icp_courses cr on cr.id=c.course_id where c.course_id=co and c.programme_id=prog and c.session_id=sess and c.semester_id=sem and c.year_level=level and not cr.is_demo)) then raise exception 'Selected course is outside the chosen department, level or term';end if;
 elsif cardinality(chosen)>0 then raise exception 'Registration links require manual course allocation after approval';end if;
 result:=public.icp_create_invite(details->>'invitee_name',email,dept,chosen,coalesce((details->>'expires_hours')::integer,168),coalesce((details->>'max_uses')::integer,1));
 update public.icp_invitations set programme_id=prog,session_id=sess,semester_id=sem,year_level=level where id=(result->>'id')::uuid;
 return result;end$$;
-- A named, email-bound invitation is administrator pre-approval. Generic links
-- continue to require a separate administrator approval and course allocation.
create or replace function public.icp_accept_invite(token text) returns void language plpgsql security definer set search_path='' as $$declare inv public.icp_invitations;email text;verified timestamptz;fullname text;begin
 if auth.uid() is null then raise exception 'Sign in first';end if;
 select u.email,u.email_confirmed_at,coalesce(u.raw_user_meta_data->>'full_name',split_part(u.email,'@',1)) into email,verified,fullname from auth.users u where id=auth.uid();
 if verified is null then raise exception 'Confirm your email first';end if;
 select * into inv from public.icp_invitations where token_hash=encode(sha256(convert_to(token,'UTF8')),'hex') for update;
 if inv.id is null or inv.revoked_at is not null or inv.expires_at<=now() or inv.used_count>=inv.usage_limit then raise exception 'Invitation expired, revoked or fully used';end if;
 if inv.email is not null and lower(email)<>inv.email then raise exception 'Invitation belongs to another email';end if;
 if exists(select 1 from public.icp_invite_redemptions where invitation_id=inv.id and user_id=auth.uid()) then raise exception 'Invitation already accepted';end if;
 if exists(select 1 from public.icp_profiles where id=auth.uid() and approved) then raise exception 'An administrator must correct an existing approved account';end if;
 insert into public.icp_profiles(id,email,full_name,requested_role) values(auth.uid(),email,fullname,'student') on conflict do nothing;
 insert into public.icp_user_roles(user_id,role) values(auth.uid(),'student') on conflict do nothing;
 insert into public.icp_invite_redemptions(invitation_id,user_id) values(inv.id,auth.uid());
 update public.icp_profiles set requested_role='lecturer',department_id=inv.department_id where id=auth.uid();
 update public.icp_user_roles set role='lecturer' where user_id=auth.uid();
 update public.icp_invitations set used_count=used_count+1 where id=inv.id;
 if inv.email is not null then update public.icp_profiles set approved=true where id=auth.uid();end if;
end$$;
revoke all on function portal_private.department_course(uuid,uuid),portal_private.sync_department_courses(uuid) from public,anon,authenticated;
revoke all on function public.icp_create_scoped_invite(jsonb) from public,anon;
grant execute on function public.icp_create_scoped_invite(jsonb) to authenticated;
commit;
