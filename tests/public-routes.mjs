import {Window} from 'happy-dom';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
async function page(url){const w=new Window({url});w.document.body.innerHTML='<div id="app"></div><div id="toastContainer"></div>';w.PORTAL_CONFIG={url:'https://test.supabase.co',key:'sb_publishable_test'};
 const catalog={icp_programmes:[{id:'p1',code:'ND-CS',name:'Computer Science'}],icp_sessions:[{id:'s1',name:'2026/2027',is_active:true}],icp_semesters:[{id:1,name:'First Semester'}]};
 w.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),onAuthStateChange:()=>{}},from:t=>{const q={select:()=>q,then:(resolve,reject)=>Promise.resolve({data:catalog[t]||[],error:null}).then(resolve,reject)};return q;}})};
 w.eval(readFileSync('public/app.js','utf8')+'\n'+readFileSync('public/portal-update.js','utf8')+'\nwindow.TEST_READY=init();');await w.TEST_READY;return w;}
let w=await page('https://portal.example/');
assert.ok(w.document.querySelector('a[href="?view=login&audience=student"]'));
assert.ok(w.document.querySelector('a[href="?view=login&audience=staff"]'));
assert.ok(w.document.querySelector('a[href="?view=signup"]'));
assert.ok(!w.document.body.textContent.includes('CGPA'));
w=await page('https://portal.example/?view=signup');assert.ok(w.document.querySelector('[name="matric_number"]'));assert.ok(w.document.querySelector('[name="programme_id"]'));assert.equal(w.document.querySelector('[name="requested_role"]'),null);
w=await page('https://portal.example/?view=login&audience=staff');assert.equal(w.document.querySelector('h1').textContent,'Staff Sign In');
w=await page('https://portal.example/?view=signup&audience=staff&invite='+'a'.repeat(64));assert.equal(w.document.querySelector('h1').textContent,'Invited Lecturer Registration');assert.equal(w.document.querySelector('[name="matric_number"]'),null);assert.equal(w.document.querySelector('[name="requested_role"]'),null);
console.log('PASS: default homepage, student/staff links, student-only public registration, academic fields, invitation-only lecturer form.');
