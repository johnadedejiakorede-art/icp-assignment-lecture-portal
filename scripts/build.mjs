import {cpSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
const url=process.env.SUPABASE_URL||'';
const key=process.env.SUPABASE_PUBLISHABLE_KEY||'';
if(!url||!key)throw new Error('Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY for your NEW project.');
if(!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url))throw new Error('Invalid hosted Supabase URL');
if(url.includes('qazayzyrwuwlendhfald'))throw new Error('Original ICP project is protected. Use a separate Supabase project.');
if(key.startsWith('sb_secret_'))throw new Error('Secret keys must never be bundled.');
if(key.split('.').length===3){const claims=JSON.parse(Buffer.from(key.split('.')[1],'base64url'));if(claims.role!=='anon')throw new Error('Only a publishable or legacy anon key is allowed.');}
rmSync('dist',{recursive:true,force:true});mkdirSync('dist');cpSync('public','dist',{recursive:true});
writeFileSync('dist/config.js',`window.PORTAL_CONFIG=${JSON.stringify({url,key})};\n`);
console.log('Static build prepared in dist/');
