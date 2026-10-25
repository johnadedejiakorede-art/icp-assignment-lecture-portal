-- Shared-hosting compatibility. Existing FoodCo signup behavior is preserved
-- for all accounts except explicitly marked ICP portal registrations.
begin;
do $$begin
 if exists(select 1 from pg_trigger where tgrelid='auth.users'::regclass and tgname='fc_capture_signup') then
  execute 'drop trigger fc_capture_signup on auth.users';
  execute $ddl$create trigger fc_capture_signup after insert on auth.users for each row
   when (coalesce(new.raw_user_meta_data->>'portal_app','')<>'icp_lecture')
   execute function foodco_private.capture_signup()$ddl$;
 end if;
end$$;
commit;
