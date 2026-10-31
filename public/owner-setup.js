const token=new URLSearchParams(location.hash.replace(/^#/,'' )||location.search).get('token');
history.replaceState(null,'',location.pathname);
const status=document.querySelector('#status');
let config=window.__LAUNCHBRIDGE_CONFIG__ || (window.PORTAL_CONFIG && {url:window.PORTAL_CONFIG.url,publishableKey:window.PORTAL_CONFIG.key});
document.querySelector('#claim').addEventListener('click',async()=>{
 try{
  if(!token||!/^[0-9a-f]{64}$/.test(token))throw Error('This setup link is missing or invalid. Request a new invitation.');
  if(!config?.url||!config?.publishableKey){
   const response=await fetch('/runtime-config.json',{cache:'no-store'});
   if(response.ok)config=await response.json();
  }
  if(!config?.url||!config?.publishableKey)throw Error('Portal configuration is unavailable.');
  const client=window.supabase.createClient(config.url,config.publishableKey);
  const {data,error}=await client.auth.getUser();
  if(error||!data.user)throw Error('Sign in with the invited email, then return here.');
  const claim=await client.rpc('icp_claim_initial_owner',{p_token:token});
  if(claim.error)throw claim.error;
  status.textContent='Administrator setup complete. You can now open the portal.';
  document.querySelector('#claim').disabled=true;
 }catch(error){status.textContent=error.message||'Setup could not be completed.'}
});
