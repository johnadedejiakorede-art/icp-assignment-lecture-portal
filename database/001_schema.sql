-- ICP-specific installation; compatible with shared FoodCo hosting. Never run against original ICP.
begin;
create schema if not exists portal_private;
revoke all on schema portal_private from public;
grant usage on schema portal_private to authenticated;
create table public.icp_departments(id uuid primary key default gen_random_uuid(),name text not null unique);
create table public.icp_profiles(id uuid primary key references auth.users on delete cascade,full_name text not null,email text not null,requested_role text not null default 'student' check(requested_role in ('student','lecturer')),approved boolean not null default false,department_id uuid references icp_departments,created_at timestamptz not null default now());
create table public.icp_user_roles(user_id uuid primary key references icp_profiles on delete cascade,role text not null check(role in ('admin','lecturer','student')));
create table public.icp_courses(id uuid primary key default gen_random_uuid(),code text not null unique,title text not null,department_id uuid references icp_departments,created_at timestamptz not null default now());
create table public.icp_course_memberships(course_id uuid references icp_courses on delete cascade,student_id uuid references icp_profiles on delete cascade,primary key(course_id,student_id));
create table public.icp_lecturer_allocations(course_id uuid references icp_courses on delete cascade,lecturer_id uuid references icp_profiles on delete cascade,primary key(course_id,lecturer_id));
create table public.icp_lecture_notes(id uuid primary key default gen_random_uuid(),course_id uuid not null references icp_courses,owner_id uuid not null references icp_profiles,title text not null,description text not null default '',file_path text not null,file_name text not null,file_size integer not null check(file_size between 1 and 15728640),published boolean not null default false,created_at timestamptz not null default now());
create table public.icp_assignments(id uuid primary key default gen_random_uuid(),course_id uuid not null references icp_courses,owner_id uuid not null references icp_profiles,title text not null,instructions text not null,due_at timestamptz not null,max_score numeric not null check(max_score>0),status text not null default 'draft' check(status in ('draft','published','closed')),file_path text,file_name text,created_at timestamptz not null default now());
create table public.icp_submissions(id uuid primary key default gen_random_uuid(),assignment_id uuid not null references icp_assignments,student_id uuid not null references icp_profiles,file_path text not null,file_name text not null,file_size integer not null check(file_size between 1 and 10485760),comment text not null default '',submitted_at timestamptz not null default now(),unique(assignment_id,student_id));
create table public.icp_assignment_feedback(submission_id uuid primary key references icp_submissions on delete cascade,score numeric not null check(score>=0),feedback text not null default '',published boolean not null default false,graded_by uuid not null references icp_profiles,updated_at timestamptz not null default now());
create table public.icp_notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references icp_profiles on delete cascade,message text not null,created_at timestamptz not null default now(),read_at timestamptz);
create index on icp_lecture_notes(course_id);create index on icp_assignments(course_id);create index on icp_submissions(student_id);create index on icp_course_memberships(student_id);create index on icp_lecturer_allocations(lecturer_id);create index on icp_notifications(user_id,created_at desc);
-- These narrowly scoped helpers avoid recursive RLS. No user-editable JWT claims authorize access.
create function portal_private.role_name() returns text language sql stable security definer set search_path='' as $$select r.role from public.icp_user_roles r join public.icp_profiles p on p.id=r.user_id where r.user_id=auth.uid() and p.approved$$;
create function portal_private.admin() returns boolean language sql stable as $$select coalesce(portal_private.role_name()='admin',false)$$;
create function portal_private.teaches(c uuid) returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and portal_private.role_name()='lecturer' and exists(select 1 from public.icp_lecturer_allocations where course_id=c and lecturer_id=auth.uid())$$;
create function portal_private.member(c uuid) returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and portal_private.role_name()='student' and exists(select 1 from public.icp_course_memberships where course_id=c and student_id=auth.uid())$$;
create function portal_private.course_access(c uuid) returns boolean language sql stable as $$select portal_private.admin() or portal_private.teaches(c) or portal_private.member(c)$$;
create function portal_private.signup() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.icp_profiles(id,email,full_name,requested_role) values(new.id,coalesce(new.email,''),coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1)),case when new.raw_user_meta_data->>'requested_role'='lecturer' then 'lecturer' else 'student' end);
 insert into public.icp_user_roles(user_id,role) values(new.id,'student');return new;end$$;
create trigger portal_signup after insert on auth.users for each row when (new.raw_user_meta_data->>'portal_app'='icp_lecture') execute function portal_private.signup();
-- Validate role allocation and preserve submission identity/deadlines at database boundary.
create function portal_private.validate_allocation() returns trigger language plpgsql security definer set search_path='' as $$declare uid uuid; expected text;begin
 if tg_table_name='icp_course_memberships' then uid:=new.student_id;expected:='student';else uid:=new.lecturer_id;expected:='lecturer';end if;
 if not exists(select 1 from public.icp_profiles p join public.icp_user_roles r on r.user_id=p.id where p.id=uid and p.approved and r.role=expected) then raise exception 'Assign an approved user with the correct role';end if;return new;end$$;
create trigger member_valid before insert or update on icp_course_memberships for each row execute function portal_private.validate_allocation();
create trigger lecturer_valid before insert or update on icp_lecturer_allocations for each row execute function portal_private.validate_allocation();
create function portal_private.validate_submission() returns trigger language plpgsql security definer set search_path='' as $$declare a public.icp_assignments;begin
 select * into a from public.icp_assignments where id=new.assignment_id for share;
 if a.id is null or a.status<>'published' or clock_timestamp()>=a.due_at then raise exception 'Assignment closed or deadline passed';end if;
 if new.student_id<>auth.uid() or not portal_private.member(a.course_id) then raise exception 'Course access denied';end if;
 if tg_op='UPDATE' and (new.id<>old.id or new.student_id<>old.student_id or new.assignment_id<>old.assignment_id) then raise exception 'Submission identity cannot change';end if;
 if split_part(new.file_path,'/',1)<>a.id::text or split_part(new.file_path,'/',2)<>auth.uid()::text then raise exception 'Invalid file owner';end if;
 if not exists(select 1 from storage.objects where bucket_id='icp-student-submissions' and name=new.file_path) then raise exception 'Upload the file first';end if;
 new.submitted_at:=clock_timestamp();return new;end$$;
create trigger submission_valid before insert or update on icp_submissions for each row execute function portal_private.validate_submission();
create function portal_private.validate_feedback() returns trigger language plpgsql security invoker set search_path='' as $$declare a public.icp_assignments;begin
 select icp_assignments.* into a from public.icp_assignments join public.icp_submissions s on s.assignment_id=icp_assignments.id where s.id=new.submission_id;
 if not portal_private.teaches(a.course_id) then raise exception 'Only allocated lecturers can grade';end if;
 if new.score<0 or new.score>a.max_score then raise exception 'Score exceeds assignment maximum';end if;
 new.graded_by:=auth.uid();new.updated_at:=clock_timestamp();return new;end$$;
create trigger feedback_valid before insert or update on icp_assignment_feedback for each row execute function portal_private.validate_feedback();
create function portal_private.validate_material() returns trigger language plpgsql security invoker set search_path='' as $$begin
 if tg_op='UPDATE' and (new.course_id<>old.course_id or new.owner_id<>old.owner_id) then raise exception 'Material ownership cannot change';end if;
 if new.file_path is not null and (split_part(new.file_path,'/',1)<>new.course_id::text or split_part(new.file_path,'/',2)<>new.owner_id::text) then raise exception 'Invalid material file path';end if;
 if new.file_path is not null and not exists(select 1 from storage.objects where bucket_id='icp-course-materials' and name=new.file_path) then raise exception 'Upload material first';end if;
 if tg_table_name='icp_assignments' and tg_op='UPDATE' then
   if exists(select 1 from public.icp_submissions s join public.icp_assignment_feedback f on f.submission_id=s.id where s.assignment_id=new.id and f.score>new.max_score) then raise exception 'Maximum below an existing score';end if;
 end if;return new;end$$;
create trigger note_valid before insert or update on icp_lecture_notes for each row execute function portal_private.validate_material();
create trigger assignment_valid before insert or update on icp_assignments for each row execute function portal_private.validate_material();
-- Enable RLS on every exposed table.
alter table icp_departments enable row level security;alter table icp_profiles enable row level security;alter table icp_user_roles enable row level security;alter table icp_courses enable row level security;alter table icp_course_memberships enable row level security;alter table icp_lecturer_allocations enable row level security;alter table icp_lecture_notes enable row level security;alter table icp_assignments enable row level security;alter table icp_submissions enable row level security;alter table icp_assignment_feedback enable row level security;alter table icp_notifications enable row level security;
create policy department_read on icp_departments for select to authenticated using(portal_private.role_name() is not null);
create policy department_admin on icp_departments for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy profile_read on icp_profiles for select to authenticated using(id=auth.uid() or portal_private.admin() or exists(select 1 from icp_course_memberships m where m.student_id=icp_profiles.id and portal_private.teaches(m.course_id)));
create policy profile_admin on icp_profiles for update to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy role_read on icp_user_roles for select to authenticated using(user_id=auth.uid() or portal_private.admin());
create policy role_admin on icp_user_roles for update to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy course_read on icp_courses for select to authenticated using(portal_private.course_access(id));
create policy course_admin on icp_courses for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy membership_read on icp_course_memberships for select to authenticated using(student_id=auth.uid() or portal_private.admin() or portal_private.teaches(course_id));
create policy membership_admin on icp_course_memberships for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy allocation_read on icp_lecturer_allocations for select to authenticated using(lecturer_id=auth.uid() or portal_private.admin());
create policy allocation_admin on icp_lecturer_allocations for all to authenticated using(portal_private.admin()) with check(portal_private.admin());
create policy note_read on icp_lecture_notes for select to authenticated using(portal_private.admin() or portal_private.teaches(course_id) or (published and portal_private.member(course_id)));
create policy note_insert on icp_lecture_notes for insert to authenticated with check(owner_id=auth.uid() and portal_private.teaches(course_id));
create policy note_update on icp_lecture_notes for update to authenticated using(portal_private.admin() or (owner_id=auth.uid() and portal_private.teaches(course_id))) with check(portal_private.admin() or (owner_id=auth.uid() and portal_private.teaches(course_id)));
create policy note_delete on icp_lecture_notes for delete to authenticated using(portal_private.admin() or(owner_id=auth.uid() and portal_private.teaches(course_id)));
create policy assignment_read on icp_assignments for select to authenticated using(portal_private.admin() or portal_private.teaches(course_id) or(status<>'draft' and portal_private.member(course_id)));
create policy assignment_insert on icp_assignments for insert to authenticated with check(owner_id=auth.uid() and portal_private.teaches(course_id));
create policy assignment_update on icp_assignments for update to authenticated using(owner_id=auth.uid() and portal_private.teaches(course_id)) with check(owner_id=auth.uid() and portal_private.teaches(course_id));
create policy submission_read on icp_submissions for select to authenticated using((student_id=auth.uid() and exists(select 1 from icp_assignments a where a.id=assignment_id and portal_private.member(a.course_id))) or exists(select 1 from icp_assignments a where a.id=assignment_id and portal_private.teaches(a.course_id)));
create policy submission_insert on icp_submissions for insert to authenticated with check(student_id=auth.uid() and exists(select 1 from icp_assignments a where a.id=assignment_id and portal_private.member(a.course_id)));
create policy submission_update on icp_submissions for update to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid());
create policy feedback_read on icp_assignment_feedback for select to authenticated using(exists(select 1 from icp_submissions s join icp_assignments a on a.id=s.assignment_id where s.id=submission_id and (portal_private.teaches(a.course_id) or(s.student_id=auth.uid() and published))));
create policy feedback_insert on icp_assignment_feedback for insert to authenticated with check(exists(select 1 from icp_submissions s join icp_assignments a on a.id=s.assignment_id where s.id=submission_id and portal_private.teaches(a.course_id)));
create policy feedback_update on icp_assignment_feedback for update to authenticated using(exists(select 1 from icp_submissions s join icp_assignments a on a.id=s.assignment_id where s.id=submission_id and portal_private.teaches(a.course_id))) with check(exists(select 1 from icp_submissions s join icp_assignments a on a.id=s.assignment_id where s.id=submission_id and portal_private.teaches(a.course_id)));
create policy notification_read on icp_notifications for select to authenticated using(user_id=auth.uid() and portal_private.role_name() is not null);
create policy notification_update on icp_notifications for update to authenticated using(user_id=auth.uid() and portal_private.role_name() is not null) with check(user_id=auth.uid());
-- Explicit grants support projects where automatic Data API grants are disabled.
grant select on icp_departments,icp_profiles,icp_user_roles,icp_courses,icp_course_memberships,icp_lecturer_allocations,icp_lecture_notes,icp_assignments,icp_submissions,icp_assignment_feedback,icp_notifications to authenticated;
grant insert,update,delete on icp_departments,icp_courses,icp_course_memberships,icp_lecturer_allocations,icp_lecture_notes to authenticated;
grant update(approved,full_name,department_id) on icp_profiles to authenticated;
grant update(role) on icp_user_roles to authenticated;
grant insert,update on icp_assignments,icp_submissions,icp_assignment_feedback to authenticated;
grant update(read_at) on icp_notifications to authenticated;
revoke all on all functions in schema portal_private from public;
grant execute on function portal_private.role_name(),portal_private.admin(),portal_private.teaches(uuid),portal_private.member(uuid),portal_private.course_access(uuid) to authenticated;
commit;
