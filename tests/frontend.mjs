import {chromium} from 'playwright';
import {createServer} from 'node:http';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve,extname} from 'node:path';
import assert from 'node:assert/strict';
const root=resolve('public');
const server=createServer((req,res)=>{try{const path=req.url.split('?')[0];const file=path==='/original-login'?resolve('tests/original-login.html'):resolve(root,'.'+(path==='/'?'/index.html':path));if(!file.startsWith(root)&&path!=='/original-login'){res.writeHead(403);res.end();return;}res.setHeader('Content-Type',({'js':'text/javascript','css':'text/css','png':'image/png'})[extname(file).slice(1)]||'text/html');res.end(readFileSync(file));}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||chromium.executablePath(),args:['--no-sandbox']});mkdirSync('docs/screenshots',{recursive:true});
const stub=`window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:window.TEST_ROLE?{user:{id:'u1',email:'demo@example.test'}}:null}}),onAuthStateChange:()=>{},signOut:async()=>({data:{}})},from:(table)=>{table=table.replace(/^icp_/, '');let single=false;const role=window.TEST_ROLE||'student';const course={id:'c1',code:'COM 211',title:'Computer Programming'};const profile={id:'u1',full_name:'Demo '+role,approved:true,email:'demo@example.test',requested_role:role};const rows={profiles:[profile],user_roles:[{user_id:'u1',role}],courses:[course],departments:[{id:'d1',name:'Computer Science'}],lecture_notes:[{id:'n1',course_id:'c1',owner_id:'u1',title:'Introduction to Programming',description:'Functions and variables',file_name:'lecture.pdf',file_size:1024,published:true,created_at:'2026-10-24T12:00:00Z'}],assignments:[{id:'a1',course_id:'c1',owner_id:'u1',title:'Programming exercise',instructions:'Write a simple program.',due_at:'2030-10-30T12:00:00Z',max_score:20,status:'published'}],submissions:[],assignment_feedback:[],notifications:[],course_memberships:[],lecturer_allocations:[]};const q={select:()=>q,eq:()=>q,order:()=>q,limit:()=>q,single:()=>{single=true;return q;},maybeSingle:()=>{single=true;return q;},then:(yes,no)=>Promise.resolve({data:single?rows[table]?.[0]:rows[table]||[],error:null}).then(yes,no)};return q;}})};`;
const errors=[];const evidence=[];
for(const width of [1440,390]){
 const context=await browser.newContext({viewport:{width,height:1000}});const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',body:'window.PORTAL_CONFIG={url:"https://new-demo.supabase.co",key:"sb_publishable_test"};'}));
 await page.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:stub}));
 await page.goto(base);await page.getByRole('heading',{name:'Sign in',exact:true}).waitFor();
 await page.screenshot({path:`docs/screenshots/login-${width}.png`,fullPage:true});
 const tokens=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement),b=getComputedStyle(document.querySelector('.btn-primary'));return{brand:s.getPropertyValue('--brand'),gold:s.getPropertyValue('--gold'),radius:s.getPropertyValue('--radius'),button:b.backgroundImage,font:getComputedStyle(document.body).fontFamily};});
 assert.equal(tokens.brand,'#008f42');assert.equal(tokens.gold,'#ffb31b');
 const overflow=()=>page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);assert.equal(await overflow(),false,'Login must fit viewport');
 await page.getByRole('button',{name:'Create account',exact:true}).click();await page.getByRole('heading',{name:'Create account',exact:true}).waitFor();
 await page.goto(base+'/original-login');await page.getByRole('heading',{name:'Sign in',exact:true}).waitFor();await page.screenshot({path:`docs/screenshots/original-login-${width}.png`,fullPage:true});
 const reference=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement),b=getComputedStyle(document.querySelector('.btn-primary'));return{brand:s.getPropertyValue('--brand'),gold:s.getPropertyValue('--gold'),radius:s.getPropertyValue('--radius'),button:b.backgroundImage,font:getComputedStyle(document.body).fontFamily};});assert.deepEqual(tokens,reference);
 for(const role of ['student','lecturer','admin']){await page.addInitScript(role=>{window.TEST_ROLE=role;},role);await page.goto(base);await page.getByRole('heading',{name:'Overview',exact:true}).waitFor();assert.equal(await overflow(),false,role+' dashboard fits');await page.screenshot({path:`docs/screenshots/${role}-${width}.png`,fullPage:true});
  for(const name of ['My Courses','Lecture Notes','Assignments','Submissions & Feedback','Notifications','Profile',...(role==='admin'?['Users & Approval','Courses & Allocations']:[])]){await page.getByRole('button',{name,exact:true}).click();await page.waitForTimeout(30);assert.equal(await overflow(),false,role+' '+name+' fits');}
  if(role==='lecturer'){await page.getByRole('button',{name:'Lecture Notes',exact:true}).click();await page.getByRole('button',{name:'Upload note',exact:true}).click();await page.getByRole('dialog').waitFor();await page.getByRole('button',{name:'Close',exact:true}).click();}
 }
 evidence.push({width,tokens,checks:'auth modes, role navigation, dialog, viewport overflow, source token comparison'});await context.close();
}
assert.deepEqual(errors,[]);writeFileSync('docs/ui-test-evidence.json',JSON.stringify({testedAt:new Date().toISOString(),mode:'Mocked Supabase client; UI only. Database tested separately.',evidence},null,2));console.log('PASS: desktop/mobile auth, roles, all routes, upload dialog, no JS errors/overflow, exact source style tokens.');
await browser.close();server.close();
