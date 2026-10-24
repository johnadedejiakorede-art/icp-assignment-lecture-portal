begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('course-materials','course-materials',false,15728640,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.presentationml.presentation']),
 ('student-submissions','student-submissions',false,10485760,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document']);
create policy material_upload on storage.objects for insert to authenticated with check(bucket_id='course-materials' and split_part(name,'/',2)=auth.uid()::text and portal_private.teaches(split_part(name,'/',1)::uuid));
create policy material_read on storage.objects for select to authenticated using(bucket_id='course-materials' and (
 (split_part(name,'/',2)=auth.uid()::text and portal_private.teaches(split_part(name,'/',1)::uuid)) or
 exists(select 1 from public.lecture_notes n where n.file_path=name and (portal_private.admin() or portal_private.teaches(n.course_id) or(n.published and portal_private.member(n.course_id)))) or
 exists(select 1 from public.assignments a where a.file_path=name and (portal_private.teaches(a.course_id) or(a.status<>'draft' and portal_private.member(a.course_id))))));
create policy material_delete on storage.objects for delete to authenticated using(bucket_id='course-materials' and (portal_private.admin() or(split_part(name,'/',2)=auth.uid()::text and portal_private.teaches(split_part(name,'/',1)::uuid))) and not exists(select 1 from public.lecture_notes n where n.file_path=name) and not exists(select 1 from public.assignments a where a.file_path=name));
create policy submission_upload on storage.objects for insert to authenticated with check(bucket_id='student-submissions' and split_part(name,'/',2)=auth.uid()::text and exists(select 1 from public.assignments a where a.id=split_part(name,'/',1)::uuid and a.status='published' and clock_timestamp()<a.due_at and portal_private.member(a.course_id)));
create policy submission_file_read on storage.objects for select to authenticated using(bucket_id='student-submissions' and (
 (split_part(name,'/',2)=auth.uid()::text and exists(select 1 from public.assignments a where a.id=split_part(name,'/',1)::uuid and portal_private.member(a.course_id))) or
 exists(select 1 from public.submissions s join public.assignments a on a.id=s.assignment_id where s.file_path=name and portal_private.teaches(a.course_id))));
create policy submission_file_delete on storage.objects for delete to authenticated using(bucket_id='student-submissions' and split_part(name,'/',2)=auth.uid()::text and portal_private.role_name()='student' and not exists(select 1 from public.submissions s where s.file_path=name));
-- Called only by triggers; no client EXECUTE permission.
create function portal_private.announce() returns trigger language plpgsql security definer set search_path='' as $$declare course uuid;msg text;begin
 if auth.uid() is null then return new;end if;
 if tg_table_name='lecture_notes' then
  if new.published and (tg_op='INSERT' or not old.published) then course:=new.course_id;msg:='New lecture note: '||new.title;end if;
 elsif tg_table_name='assignments' then
  if new.status='published' and (tg_op='INSERT' or old.status<>'published') then course:=new.course_id;msg:='New assignment: '||new.title;end if;
 elsif tg_table_name='assignment_feedback' then
  if new.published and (tg_op='INSERT' or not old.published or old.score<>new.score or old.feedback<>new.feedback) then
   insert into public.notifications(user_id,message) select s.student_id,'Assignment feedback published: '||a.title from public.submissions s join public.assignments a on a.id=s.assignment_id where s.id=new.submission_id;
  end if;return new;
 end if;
 if course is not null then insert into public.notifications(user_id,message) select student_id,msg from public.course_memberships where course_id=course;end if;return new;end$$;
create trigger note_notice after insert or update on lecture_notes for each row execute function portal_private.announce();
create trigger assignment_notice after insert or update on assignments for each row execute function portal_private.announce();
create trigger feedback_notice after insert or update on assignment_feedback for each row execute function portal_private.announce();
create function portal_private.clear_feedback() returns trigger language plpgsql security definer set search_path='' as $$begin
 if auth.uid()=new.student_id and new.file_path<>old.file_path then delete from public.assignment_feedback where submission_id=new.id;end if;return new;end$$;
create trigger submission_replaced after update on submissions for each row execute function portal_private.clear_feedback();
revoke all on function portal_private.announce(),portal_private.clear_feedback() from public;
commit;
