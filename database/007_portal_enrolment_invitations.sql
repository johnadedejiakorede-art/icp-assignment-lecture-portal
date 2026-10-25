begin;
alter table icp_courses add column is_demo boolean not null default false;
update icp_courses set is_demo=true;
alter table icp_courses drop constraint icp_courses_code_key;
alter table icp_courses add unique(code,is_demo);
alter table icp_courses add column units smallint;
create table icp_programmes(id uuid primary key default gen_random_uuid(),department_id uuid not null references icp_departments,code text not null unique,name text not null);
create table icp_sessions(id uuid primary key default gen_random_uuid(),name text not null unique,is_active boolean not null default false);
create table icp_semesters(id smallint primary key,name text not null);
create table icp_curriculum(programme_id uuid references icp_programmes,course_id uuid references icp_courses,session_id uuid references icp_sessions,semester_id smallint references icp_semesters,year_level smallint check(year_level between 1 and 6),primary key(programme_id,course_id,session_id,semester_id,year_level));
alter table icp_profiles add column matric_number text;
create unique index icp_matric_unique on icp_profiles(upper(matric_number)) where matric_number is not null;
alter table icp_profiles add column identifier_type text not null default 'matric' check(identifier_type in ('matric','temporary'));
alter table icp_profiles add column programme_id uuid references icp_programmes;
alter table icp_profiles add column session_id uuid references icp_sessions;
alter table icp_profiles add column semester_id smallint references icp_semesters;
alter table icp_profiles add column year_level smallint check(year_level between 1 and 6);
alter table icp_profiles add column identity_verified boolean not null default false;
-- Preserve already approved presentation accounts, with no fabricated matric numbers.
update icp_profiles set identity_verified=approved;
alter table icp_course_memberships add column status text not null default 'enrolled' check(status in ('enrolled','removed','suspended'));
alter table icp_course_memberships add column reason text not null default '';
alter table icp_course_memberships add column updated_at timestamptz not null default now();
create table icp_enrolment_history(id uuid primary key default gen_random_uuid(),student_id uuid not null references icp_profiles,course_id uuid not null references icp_courses,session_id uuid references icp_sessions,semester_id smallint references icp_semesters,status text not null,reason text not null,actor_id uuid references icp_profiles,created_at timestamptz not null default now());
create table icp_invitations(id uuid primary key default gen_random_uuid(),name text not null,email text,department_id uuid references icp_departments,course_ids uuid[] not null default '{}',token_hash text not null unique,expires_at timestamptz not null,usage_limit integer not null check(usage_limit between 1 and 100),used_count integer not null default 0,revoked_at timestamptz,created_by uuid not null references icp_profiles,created_at timestamptz not null default now(),mail_status text not null default 'not_sent',mail_error text,check(email is not null or cardinality(course_ids)=0));
create table icp_invite_redemptions(invitation_id uuid references icp_invitations,user_id uuid references icp_profiles,approved_at timestamptz,primary key(invitation_id,user_id));
create table portal_private.coursework_audit(id uuid primary key default gen_random_uuid(),table_name text not null,record_id text not null,actor_id uuid,previous_data jsonb,new_data jsonb,created_at timestamptz not null default now());
create or replace function portal_private.signup() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.icp_profiles(id,email,full_name,requested_role) values(new.id,coalesce(new.email,''),coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1)),'student');
 insert into public.icp_user_roles(user_id,role) values(new.id,'student');return new;end$$;
create or replace function portal_private.member(c uuid) returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and portal_private.role_name()='student' and exists(select 1 from public.icp_course_memberships m join public.icp_profiles p on p.id=m.student_id where m.course_id=c and m.student_id=auth.uid() and m.status='enrolled' and p.identity_verified)$$;
-- Public academic options contain catalogue metadata only.
alter table icp_programmes enable row level security;alter table icp_sessions enable row level security;alter table icp_semesters enable row level security;alter table icp_curriculum enable row level security;alter table icp_enrolment_history enable row level security;alter table icp_invitations enable row level security;alter table icp_invite_redemptions enable row level security;alter table portal_private.coursework_audit enable row level security;
create policy programme_read on icp_programmes for select to anon,authenticated using(true);
create policy session_read on icp_sessions for select to anon,authenticated using(true);
create policy semester_read on icp_semesters for select to anon,authenticated using(true);
create policy programme_admin on icp_programmes for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy session_admin on icp_sessions for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy curriculum_admin on icp_curriculum for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy history_read on icp_enrolment_history for select to authenticated using(portal_private.admin() or student_id=auth.uid() or portal_private.teaches(course_id));
create policy invitation_admin on icp_invitations for select to authenticated using(portal_private.admin());
create policy redemption_read on icp_invite_redemptions for select to authenticated using(portal_private.admin() or user_id=auth.uid());
grant select on icp_programmes,icp_sessions,icp_semesters to anon,authenticated;
grant select on icp_curriculum,icp_enrolment_history,icp_invitations,icp_invite_redemptions to authenticated;
grant insert,update,delete on icp_programmes,icp_sessions,icp_curriculum to authenticated;
grant update(matric_number,identifier_type,programme_id,session_id,semester_id,year_level,identity_verified) on icp_profiles to authenticated;
revoke delete on icp_course_memberships from authenticated;
-- Student supplies details; approval requires an independent administrator identity check.
create function public.icp_register_details(details jsonb) returns void language plpgsql security definer set search_path='' as $$declare p public.icp_profiles; mat text;begin
 if auth.uid() is null then raise exception 'Sign in first';end if;
 select * into p from public.icp_profiles where id=auth.uid() for update;
 if p.id is null or p.approved or exists(select 1 from public.icp_user_roles where user_id=p.id and role<>'student') then raise exception 'Academic corrections require an administrator';end if;
 mat:=upper(trim(details->>'matric_number'));
 if mat is null or mat !~ '^[A-Z0-9][A-Z0-9/._-]{3,39}$' then raise exception 'Enter a valid matric number or permitted temporary identifier';end if;
 if not exists(select 1 from public.icp_programmes where id=(details->>'programme_id')::uuid) then raise exception 'Select a valid programme';end if;
 update public.icp_profiles set matric_number=mat,identifier_type=coalesce(details->>'identifier_type','matric'),programme_id=(details->>'programme_id')::uuid,session_id=(details->>'session_id')::uuid,semester_id=(details->>'semester_id')::smallint,year_level=(details->>'year_level')::smallint,department_id=(select department_id from public.icp_programmes where id=(details->>'programme_id')::uuid),identity_verified=false where id=auth.uid();
end$$;
create function portal_private.enrol_student() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.approved and new.identity_verified and new.programme_id is not null and exists(select 1 from public.icp_user_roles where user_id=new.id and role='student') then
  update public.icp_course_memberships m set status='suspended',reason='Academic context changed',updated_at=now() where m.student_id=new.id and m.status='enrolled' and not exists(select 1 from public.icp_curriculum c where c.course_id=m.course_id and c.programme_id=new.programme_id and c.session_id=new.session_id and c.semester_id=new.semester_id and c.year_level=new.year_level);
  update public.icp_course_memberships m set status='enrolled',reason='Academic context restored',updated_at=now() where m.student_id=new.id and m.status='suspended' and m.reason='Academic context changed' and exists(select 1 from public.icp_curriculum c where c.course_id=m.course_id and c.programme_id=new.programme_id and c.session_id=new.session_id and c.semester_id=new.semester_id and c.year_level=new.year_level);
  -- Historic entries are append-only; explicit lecturer removals are never overwritten.
  insert into public.icp_course_memberships(course_id,student_id)
  select c.course_id,new.id from public.icp_curriculum c where c.programme_id=new.programme_id and c.session_id=new.session_id and c.semester_id=new.semester_id and c.year_level=new.year_level on conflict do nothing;
 end if;return new;end$$;
create trigger icp_auto_enrol after update of approved,identity_verified,programme_id,session_id,semester_id,year_level on icp_profiles for each row execute function portal_private.enrol_student();
create function portal_private.membership_log() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.icp_enrolment_history(student_id,course_id,session_id,semester_id,status,reason,actor_id) select new.student_id,new.course_id,p.session_id,p.semester_id,new.status,new.reason,auth.uid() from public.icp_profiles p where p.id=new.student_id;return new;end$$;
create trigger icp_membership_history after insert or update on icp_course_memberships for each row execute function portal_private.membership_log();
create function public.icp_set_membership(course uuid,student uuid,new_status text,reason text) returns void language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null or not (portal_private.admin() or portal_private.teaches(course)) then raise exception 'Course allocation required';end if;
 if new_status not in ('enrolled','removed','suspended') or length(trim(reason))<3 then raise exception 'Choose a status and provide a reason';end if;
 update public.icp_course_memberships set status=new_status,reason=icp_set_membership.reason,updated_at=now() where course_id=course and student_id=student;
 if not found then raise exception 'Student is not on this course roster';end if;
end$$;
-- Hashed token invites: return raw token only once to the administrator.
create function public.icp_create_invite(invitee_name text,invitee_email text,department uuid,courses uuid[],expires_hours integer default 168,max_uses integer default 1) returns jsonb language plpgsql security definer set search_path='' as $$declare token text;inv public.icp_invitations; email text;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 email:=nullif(lower(trim(invitee_email)),'');
 if length(trim(invitee_name))<2 or expires_hours not between 1 and 720 then raise exception 'Name and expiry required';end if;
 if email is not null and email !~ '^[^ @]+@[^ @]+\.[^ @]+$' then raise exception 'Invalid email';end if;
 if email is null and cardinality(courses)>0 then raise exception 'Generic links require manual course allocation';end if;
 if exists(select 1 from unnest(courses) c where not exists(select 1 from public.icp_courses where id=c and not is_demo)) then raise exception 'Choose valid catalogue courses';end if;
 token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 insert into public.icp_invitations(name,email,department_id,course_ids,token_hash,expires_at,usage_limit,created_by)
 values(trim(invitee_name),email,department,coalesce(courses,'{}'),encode(sha256(convert_to(token,'UTF8')),'hex'),now()+make_interval(hours=>expires_hours),case when email is not null then 1 else max_uses end,auth.uid()) returning * into inv;
 return jsonb_build_object('id',inv.id,'token',token,'expires_at',inv.expires_at);
end$$;
create function public.icp_invite_action(invitation uuid,action text) returns jsonb language plpgsql security definer set search_path='' as $$declare token text;inv public.icp_invitations;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 select * into inv from public.icp_invitations where id=invitation for update;
 if inv.id is null then raise exception 'Invitation not found';end if;
 if action='revoke' then update public.icp_invitations set revoked_at=now() where id=invitation;return jsonb_build_object('revoked',true);end if;
 if action<>'renew' or inv.used_count>0 then raise exception 'Only unused invitations can be renewed';end if;
 token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 update public.icp_invitations set token_hash=encode(sha256(convert_to(token,'UTF8')),'hex'),expires_at=now()+interval '7 days',revoked_at=null,mail_status='not_sent' where id=invitation;
 return jsonb_build_object('id',invitation,'token',token);
end$$;
create function public.icp_accept_invite(token text) returns void language plpgsql security definer set search_path='' as $$declare inv public.icp_invitations;email text;verified timestamptz;begin
 if auth.uid() is null then raise exception 'Sign in first';end if;
 select u.email,u.email_confirmed_at into email,verified from auth.users u where id=auth.uid();
 if verified is null then raise exception 'Confirm your email first';end if;
 select * into inv from public.icp_invitations where token_hash=encode(sha256(convert_to(token,'UTF8')),'hex') for update;
 if inv.id is null or inv.revoked_at is not null or inv.expires_at<=now() or inv.used_count>=inv.usage_limit then raise exception 'Invitation expired, revoked or fully used';end if;
 if inv.email is not null and lower(email)<>inv.email then raise exception 'Invitation belongs to another email';end if;
 if exists(select 1 from public.icp_invite_redemptions where invitation_id=inv.id and user_id=auth.uid()) then raise exception 'Invitation already accepted';end if;
 if not exists(select 1 from public.icp_profiles where id=auth.uid() and not approved) then raise exception 'An administrator must correct an existing approved account';end if;
 insert into public.icp_invite_redemptions(invitation_id,user_id) values(inv.id,auth.uid());
 update public.icp_profiles set requested_role='lecturer',department_id=inv.department_id where id=auth.uid();
 update public.icp_user_roles set role='lecturer' where user_id=auth.uid();
 update public.icp_invitations set used_count=used_count+1 where id=inv.id;
end$$;
create function portal_private.approve_invitee() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.approved and not old.approved then
  insert into public.icp_lecturer_allocations(course_id,lecturer_id)
   select unnest(i.course_ids),new.id from public.icp_invite_redemptions r join public.icp_invitations i on i.id=r.invitation_id where r.user_id=new.id and r.approved_at is null and i.email is not null on conflict do nothing;
  update public.icp_invite_redemptions set approved_at=now() where user_id=new.id and approved_at is null;
 end if;return new;end$$;
create trigger icp_invitee_approved after update of approved on icp_profiles for each row execute function portal_private.approve_invitee();
-- Prevent direct promotion of public registrants to lecturer without a redeemed invitation.
create function portal_private.role_guard() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.role='lecturer' and old.role<>'lecturer' and not exists(select 1 from public.icp_invite_redemptions where user_id=new.user_id) then raise exception 'Lecturer requires a verified invitation';end if;return new;end$$;
create trigger icp_role_guard before update on icp_user_roles for each row execute function portal_private.role_guard();
-- Admin may see counts and metadata, never the file bodies or feedback.
drop policy material_read on storage.objects;
create policy material_read on storage.objects for select to authenticated using(bucket_id='icp-course-materials' and ((split_part(name,'/',2)=auth.uid()::text and portal_private.teaches(split_part(name,'/',1)::uuid)) or exists(select 1 from public.icp_lecture_notes n where n.file_path=name and (portal_private.teaches(n.course_id) or(n.published and portal_private.member(n.course_id)))) or exists(select 1 from public.icp_assignments a where a.file_path=name and (portal_private.teaches(a.course_id) or(a.status<>'draft' and portal_private.member(a.course_id))))));
-- Remove administrator mutations of lecturer material as well as file access.
drop policy note_update on icp_lecture_notes;drop policy note_delete on icp_lecture_notes;
create policy note_update on icp_lecture_notes for update to authenticated using(owner_id=auth.uid() and portal_private.teaches(course_id)) with check(owner_id=auth.uid() and portal_private.teaches(course_id));
create policy note_delete on icp_lecture_notes for delete to authenticated using(owner_id=auth.uid() and portal_private.teaches(course_id));
create function portal_private.audit_coursework() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into portal_private.coursework_audit(table_name,record_id,actor_id,previous_data,new_data) values(tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'submission_id'),auth.uid(),case when tg_op='UPDATE' then to_jsonb(old) else null end,to_jsonb(new));return new;end$$;
create trigger icp_submission_audit after insert or update on icp_submissions for each row execute function portal_private.audit_coursework();
create trigger icp_feedback_audit after insert or update on icp_assignment_feedback for each row execute function portal_private.audit_coursework();
create function public.icp_activity_summary() returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;begin
 if auth.uid() is null or not portal_private.admin() then raise exception 'Administrator access required';end if;
 select jsonb_build_object('students',(select count(*) from public.icp_user_roles where role='student'),'lecturers',(select count(*) from public.icp_user_roles where role='lecturer'),'submissions',(select count(*) from public.icp_submissions),'graded',(select count(*) from public.icp_assignment_feedback),'pending_grading',(select count(*) from public.icp_submissions s where not exists(select 1 from public.icp_assignment_feedback f where f.submission_id=s.id)),'missed',(select count(*) from public.icp_assignments a join public.icp_course_memberships m on m.course_id=a.course_id where a.status<>'draft' and a.due_at<now() and m.status='enrolled' and not exists(select 1 from public.icp_submissions s where s.assignment_id=a.id and s.student_id=m.student_id)),'late',(select count(*) from public.icp_submissions s join public.icp_assignments a on a.id=s.assignment_id where s.submitted_at>a.due_at),'workload',(select coalesce(jsonb_agg(w),'[]') from (select p.full_name,count(distinct l.course_id) as courses,count(distinct a.id) as assignments from public.icp_profiles p join public.icp_lecturer_allocations l on l.lecturer_id=p.id left join public.icp_assignments a on a.course_id=l.course_id group by p.id,p.full_name)w)) into result;
 return result;end$$;
revoke all on function public.icp_register_details(jsonb),public.icp_set_membership(uuid,uuid,text,text),public.icp_create_invite(text,text,uuid,uuid[],integer,integer),public.icp_invite_action(uuid,text),public.icp_accept_invite(text),public.icp_activity_summary() from public,anon;
grant execute on function public.icp_register_details(jsonb),public.icp_set_membership(uuid,uuid,text,text),public.icp_create_invite(text,text,uuid,uuid[],integer,integer),public.icp_invite_action(uuid,text),public.icp_accept_invite(text),public.icp_activity_summary() to authenticated;
revoke all on function portal_private.enrol_student(),portal_private.membership_log(),portal_private.approve_invitee(),portal_private.role_guard(),portal_private.audit_coursework() from public,anon,authenticated;
commit;
