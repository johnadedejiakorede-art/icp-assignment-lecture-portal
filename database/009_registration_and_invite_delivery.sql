begin;
create or replace function portal_private.signup() returns trigger language plpgsql security definer set search_path='' as $$declare d jsonb;mat text;begin
 d:=new.raw_user_meta_data->'academic_details';mat:=upper(trim(d->>'matric_number'));
 if d is not null and (mat is null or mat !~ '^[A-Z0-9][A-Z0-9/._-]{3,39}$') then raise exception 'Invalid academic identifier';end if;
 insert into public.icp_profiles(id,email,full_name,requested_role,matric_number,identifier_type,programme_id,session_id,semester_id,year_level,department_id)
 values(new.id,coalesce(new.email,''),coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1)),'student',mat,coalesce(d->>'identifier_type','matric'),(d->>'programme_id')::uuid,(d->>'session_id')::uuid,(d->>'semester_id')::smallint,(d->>'year_level')::smallint,(select department_id from public.icp_programmes where id=(d->>'programme_id')::uuid));
 insert into public.icp_user_roles(user_id,role) values(new.id,'student');return new;end$$;
alter table icp_invitations add column last_mailed_at timestamptz;
-- A verified existing Auth user can join via an email-bound invitation without
-- changing that user's password or any other application's profile.
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
end$$;
drop policy material_delete on storage.objects;
create policy material_delete on storage.objects for delete to authenticated using(bucket_id='icp-course-materials' and split_part(name,'/',2)=auth.uid()::text and portal_private.teaches(split_part(name,'/',1)::uuid) and not exists(select 1 from public.icp_lecture_notes n where n.file_path=name) and not exists(select 1 from public.icp_assignments a where a.file_path=name));
-- Capture a private baseline for coursework that predates the audit trigger.
insert into portal_private.coursework_audit(table_name,record_id,previous_data,new_data) select 'icp_submissions',id::text,null,to_jsonb(s) from public.icp_submissions s;
insert into portal_private.coursework_audit(table_name,record_id,previous_data,new_data) select 'icp_assignment_feedback',submission_id::text,null,to_jsonb(f) from public.icp_assignment_feedback f;
commit;
