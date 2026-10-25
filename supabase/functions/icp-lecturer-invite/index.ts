import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
const origin='https://icp-assignment-portal.pages.dev';
const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply(405,{error:'POST required'});
 const bearer=req.headers.get('Authorization')||'';
 if(!bearer.startsWith('Bearer '))return reply(401,{error:'Sign in first'});
 const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
 const client=createClient(url,anon,{global:{headers:{Authorization:bearer}},auth:{persistSession:false}});
 const {data:{user},error:authError}=await client.auth.getUser(bearer.slice(7));
 if(authError||!user)return reply(401,{error:'Invalid session'});
 const [{data:profile},{data:role}]=await Promise.all([client.from('icp_profiles').select('approved').eq('id',user.id).single(),client.from('icp_user_roles').select('role').eq('user_id',user.id).single()]);
 if(!profile?.approved||role?.role!=='admin')return reply(403,{error:'Administrator access required'});
 try{
 const body=await req.json();if(typeof body.token!=='string'||body.token.length!==64)return reply(400,{error:'Valid invitation token required'});
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.token)))).map(x=>x.toString(16).padStart(2,'0')).join('');
 const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
 const {data:inv,error}=await admin.from('icp_invitations').select('*').eq('id',body.invitation_id).eq('token_hash',hash).single();
 if(error||!inv?.email||inv.revoked_at||new Date(inv.expires_at)<=new Date()||inv.used_count>=inv.usage_limit)return reply(400,{error:'Invitation is unavailable'});
 if(inv.last_mailed_at&&Date.now()-new Date(inv.last_mailed_at).getTime()<60000)return reply(429,{error:'Wait one minute before resending'});
 const stamp=new Date().toISOString();let claim=admin.from('icp_invitations').update({last_mailed_at:stamp,mail_status:'sending',mail_error:null}).eq('id',inv.id);
 claim=inv.last_mailed_at?claim.eq('last_mailed_at',inv.last_mailed_at):claim.is('last_mailed_at',null);
 const {data:claimed}=await claim.select('id');if(!claimed?.length)return reply(409,{error:'Another delivery is in progress'});
 const redirectTo=origin+'/?callback=1&invite='+encodeURIComponent(body.token);
 let sent=await admin.auth.admin.inviteUserByEmail(inv.email,{data:{portal_app:'icp_lecture',full_name:inv.name},redirectTo});
 if(sent.error&&/already|registered|exists/i.test(sent.error.message)){
  const otp=await createClient(url,anon,{auth:{persistSession:false}}).auth.signInWithOtp({email:inv.email,options:{shouldCreateUser:false,emailRedirectTo:redirectTo}});
  sent={...sent,error:otp.error};
 }
 if(sent.error){await admin.from('icp_invitations').update({mail_status:'failed',mail_error:sent.error.message}).eq('id',inv.id);return reply(502,{error:sent.error.message});}
 await admin.from('icp_invitations').update({mail_status:'sent',mail_error:null}).eq('id',inv.id);
 return reply(200,{sent:true});
 }catch{return reply(400,{error:'Unable to process invitation'});}
});
