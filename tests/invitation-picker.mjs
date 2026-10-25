import {Window} from 'happy-dom';import {readFileSync} from 'node:fs';import assert from 'node:assert/strict';
const data=JSON.parse(readFileSync('database/catalogue-source-20261025.json'));
const w=new Window({url:'https://portal.example/'});w.document.body.innerHTML='<div id="app"></div><div id="toastContainer"></div>';w.PORTAL_CONFIG={url:'https://test.supabase.co',key:'sb_publishable_test'};
w.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),onAuthStateChange:()=>{}},from:()=>({select:()=>Promise.resolve({data:[],error:null})})})};
w.eval(['public/app.js','public/portal-update.js','public/invitation-picker.js'].map(p=>readFileSync(p,'utf8')).join('\n')+'\nwindow.TEST={state,setAcademic:x=>academic=x,setCurriculum:x=>inviteCurriculum=x,composer:invitationComposer,setMethod:setInvitationMethod,home,available:invitationAvailableCourses};');
const t=w.TEST;t.state.courses=data.courses.map(c=>({...c,is_demo:false}));t.state.departments=data.departments;t.setAcademic({programmes:data.programmes,sessions:data.sessions,semesters:data.semesters});t.setCurriculum(data.mappings);
w.document.querySelector('#app').innerHTML=t.composer();t.setMethod('email');const f=w.document.querySelector('[data-invite-form]');
const set=(name,value)=>{f.elements[name].value=String(value);f.elements[name].dispatchEvent(new w.Event('change',{bubbles:true}));};
const dept=data.departments.find(d=>d.code==='CS'),prog=data.programmes.find(p=>p.code==='ND-CS'),session=data.sessions.find(s=>s.is_active);
set('department',dept.id);assert.equal(f.elements.programme_id.options.length,2);set('programme_id',prog.id);set('year_level',1);set('session_id',session.id);set('semester_id',1);
assert.equal(f.querySelectorAll('input[name=courses]').length,9);
let check=f.querySelector('input[name=courses]');check.checked=true;check.dispatchEvent(new w.Event('change',{bubbles:true}));assert.equal(f.querySelector('#inviteSelectionCount').textContent,'1 course(s) selected');assert.equal(f.querySelector('[data-invite-submit]').disabled,false);
set('year_level',2);assert.equal(f.querySelectorAll('input[name=courses]').length,10);assert.equal(f.querySelectorAll('input[name=courses]:checked').length,0);assert.equal(f.querySelector('[data-invite-submit]').disabled,true);
set('semester_id',2);assert.equal(f.querySelectorAll('input[name=courses]').length,8);
t.setMethod('link');assert.equal(f.elements.invitee_email.disabled,true);assert.equal(f.querySelector('[data-invite-submit]').textContent,'Create Registration Link');assert.equal(f.querySelector('[data-invite-submit]').disabled,false);
t.setMethod('email');const other=data.departments.find(d=>d.code!=='CS');set('department',other.id);set('programme_id',data.programmes.find(p=>p.department_id===other.id).id);set('year_level',1);set('session_id',session.id);set('semester_id',1);assert.equal(f.querySelectorAll('input[name=courses]').length,0);assert.match(f.querySelector('#inviteCourseList').textContent,/No courses are mapped/);
t.home();for(const card of w.document.querySelectorAll('.access-card')){assert.ok(card.querySelector('.access-card-top'));assert.equal(card.querySelector('p').parentElement,card.lastElementChild);assert.notEqual(card.querySelector('p').parentElement,card);}
console.log('PASS: course filters (department/programme/ND/year/session/semester), exact catalogue counts, selection count/reset, generic link isolation, empty mappings and mobile card structure.');
