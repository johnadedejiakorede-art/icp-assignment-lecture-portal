-- App-specific initial owner; never replaces an existing administrator.
begin;
create table portal_private.initial_owner_state(singleton boolean primary key default true check(singleton),closed_at timestamptz);
insert into portal_private.initial_owner_state(singleton) values(true);
create table portal_private.initial_owner_invitations(email text not null,token_hash text primary key,expires_at timestamptz not null,consumed_at timestamptz);
alter table portal_private.initial_owner_state enable row level security;
alter table portal_private.initial_owner_invitations enable row level security;
revoke all on portal_private.initial_owner_state,portal_private.initial_owner_invitations from public,anon,authenticated;
create function portal_private.launchbridge_provision_owner(owner_email text,invitation_sha256 text,expires_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform 1 from portal_private.initial_owner_state where singleton for update;
 if not found then raise exception 'Owner state missing';end if;
 if (select closed_at from portal_private.initial_owner_state where singleton) is not null or exists(select 1 from public.icp_user_roles where role='admin') then return jsonb_build_object('alreadyProvisioned',true);end if;
 if owner_email is null or lower(btrim(owner_email)) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or invitation_sha256 is null or invitation_sha256 !~ '^[0-9a-f]{64}$' or expires_at is null or expires_at<=now() or expires_at>now()+interval '7 days' then raise exception 'Invalid owner invitation';end if;
 delete from portal_private.initial_owner_invitations where consumed_at is null;
 insert into portal_private.initial_owner_invitations values(lower(btrim(owner_email)),invitation_sha256,expires_at,null);
 return jsonb_build_object('ready',true);
end $$;
revoke all on function portal_private.launchbridge_provision_owner(text,text,timestamptz) from public,anon,authenticated;
create function public.icp_claim_initial_owner(p_token text) returns boolean
language plpgsql security definer set search_path='' as $$
declare u auth.users;inv portal_private.initial_owner_invitations;
begin
 if auth.uid() is null then raise exception 'Sign in first';end if;
 perform 1 from portal_private.initial_owner_state where singleton for update;
 if not found then raise exception 'Owner state missing';end if;
 if (select closed_at from portal_private.initial_owner_state where singleton) is not null or exists(select 1 from public.icp_user_roles where role='admin') then raise exception 'Initial owner setup is closed';end if;
 select * into u from auth.users where id=auth.uid();
 if not found or u.email_confirmed_at is null then raise exception 'Verify the invited email first';end if;
 if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'Invalid owner invitation';end if;
 select * into inv from portal_private.initial_owner_invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
 if not found or inv.expires_at<=now() or inv.consumed_at is not null then raise exception 'Invitation expired or already used';end if;
 if lower(u.email)<>inv.email then raise exception 'Invitation belongs to another email';end if;
 update public.icp_user_roles set role='admin' where user_id=u.id;
 if not found then raise exception 'Register a portal account first';end if;
 update public.icp_profiles set approved=true,identity_verified=true where id=u.id;
 update portal_private.initial_owner_invitations set consumed_at=now() where token_hash=inv.token_hash;
 update portal_private.initial_owner_state set closed_at=now() where singleton;
 insert into portal_private.coursework_audit(table_name,record_id,actor_id,previous_data,new_data) values('initial_owner',u.id::text,u.id,null,jsonb_build_object('claimed',true));
 return true;
end $$;
revoke all on function public.icp_claim_initial_owner(text) from public,anon;
grant execute on function public.icp_claim_initial_owner(text) to authenticated;
commit;
