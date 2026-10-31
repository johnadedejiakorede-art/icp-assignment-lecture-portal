import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec(`create role authenticated;create role anon;create schema auth;create schema storage;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb);
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
alter table storage.objects enable row level security;grant usage on schema auth,storage to authenticated;grant select,insert,update,delete on storage.objects to authenticated;`);


import fs from 'node:fs';
const files=fs.readdirSync('database').filter(f=>/^\d+_.*\.sql$/.test(f)&&!f.includes('demo_catalogue')).sort();
for(const f of files){await db.exec(readFileSync('database/'+f,'utf8'));console.log('PASS',f)}
const tables=(await db.query("select tablename,rowsecurity from pg_tables where schemaname='public'")).rows;assert.ok(tables.length>10);assert.ok(tables.every(t=>t.rowsecurity));console.log('PASS public table RLS:',tables.length);await db.exec('alter table auth.users add column email_confirmed_at timestamptz');
const owner='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002',token='a'.repeat(64);
const scalar=async(q,args=[])=>Object.values((await db.query(q,args)).rows[0])[0];
const actor=async id=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id||'']);if(id)await db.exec('set role authenticated')};
await db.query(`insert into auth.users(id,email,raw_user_meta_data) values($1,'owner@example.invalid','{"portal_app":"icp_lecture"}'),($2,'other@example.invalid','{"portal_app":"icp_lecture"}')`,[owner,other]);
assert.equal((await db.query("select portal_private.launchbridge_provision_owner('owner@example.invalid',encode(sha256(convert_to($1,'UTF8')),'hex'),now()+interval '1 day') as r",[token])).rows[0].r.ready,true);
await actor(owner);
await assert.rejects(()=>db.query("select portal_private.launchbridge_provision_owner('x@example.invalid',$1,now()+interval '1 day')",[token]),/permission denied/);
await assert.rejects(()=>db.query('select icp_claim_initial_owner($1)',[token]),/Verify/);
assert.equal((await db.query("update icp_user_roles set role='admin' where user_id=$1",[owner])).affectedRows,0);
await actor(null);await db.exec('update auth.users set email_confirmed_at=now()');
await actor(other);await assert.rejects(()=>db.query('select icp_claim_initial_owner($1)',[token]),/another email/);
await actor(owner);await assert.rejects(()=>db.query('select icp_claim_initial_owner($1)',['b'.repeat(64)]),/expired or already used/);
await actor(null);await db.exec("update portal_private.initial_owner_invitations set expires_at=now()-interval '1 second'");
await actor(owner);await assert.rejects(()=>db.query('select icp_claim_initial_owner($1)',[token]),/expired or already used/);
await actor(null);await db.query("select portal_private.launchbridge_provision_owner('owner@example.invalid',encode(sha256(convert_to($1,'UTF8')),'hex'),now()+interval '1 day')",[token]);
await actor(owner);assert.equal(await scalar('select icp_claim_initial_owner($1)',[token]),true);
assert.equal(await scalar('select portal_private.role_name()'),'admin');
await assert.rejects(()=>db.query('select icp_claim_initial_owner($1)',[token]),/closed/);
await actor(null);await db.query('delete from auth.users where id=$1',[owner]);
assert.equal((await db.query("select portal_private.launchbridge_provision_owner('other@example.invalid',$1,now()+interval '1 day') as r",[token])).rows[0].r.alreadyProvisioned,true);
console.log('PASS owner: designated verified email, private adapter, denied self-promotion, wrong email/token, expiry, single use, deletion stays closed');

await db.close();
