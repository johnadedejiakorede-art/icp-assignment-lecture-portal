begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('icp-student-submissions','icp-student-submissions',false,10485760,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document']) on conflict(id) do nothing;
do $$declare p record;q text;c text;begin
 for p in select polname,polcmd,polqual,polwithcheck from pg_policy where polrelid='storage.objects'::regclass and polname in ('submission_upload','submission_file_read','submission_file_delete') loop
 q:=replace(pg_get_expr(p.polqual,'storage.objects'::regclass),'student-icp_submissions','icp-student-submissions');
 c:=replace(pg_get_expr(p.polwithcheck,'storage.objects'::regclass),'student-icp_submissions','icp-student-submissions');
 execute format('alter policy %I on storage.objects %s %s',p.polname,case when q is null then '' else 'using ('||q||')' end,case when c is null then '' else 'with check ('||c||')' end);
 end loop;
 execute replace(pg_get_functiondef('portal_private.validate_submission()'::regprocedure),'student-icp_submissions','icp-student-submissions');
end$$;
commit;
