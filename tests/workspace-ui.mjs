import {Window} from 'happy-dom';import {readFileSync} from 'node:fs';import assert from 'node:assert/strict';
const data=JSON.parse(readFileSync('database/catalogue-source-20261025.json'));
const w=new Window({url:'https://portal.example/'});w.document.body.innerHTML='<div id="app"></div><div id="toastContainer"></div>';w.PORTAL_CONFIG={url:'https://test.supabase.co',key:'sb_publishable_test'};
w.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),onAuthStateChange:()=>{}},from:()=>({select:()=>Promise.resolve({data:[],error:null})})})};
w.eval(['app.js','portal-update.js','invitation-picker.js','academic-workspace.js'].map(p=>readFileSync('public/'+p,'utf8')).join('\n')+`\nwindow.TEST={state,setAcademic:x=>academic=x,setCatalogue:x=>catalogue=x,setFilters:x=>courseFilters=x,matchingCourses,filterFields,shell,parseCourseCSV,peopleResults,action,setClient:x=>sb=x};`);
const t=w.TEST;t.state.courses=data.courses.map(c=>({...c,is_demo:false}));t.state.departments=data.departments;t.setAcademic(data);t.setCatalogue(data.mappings);t.state.role='admin';t.state.profile={full_name:'Test Admin'};t.shell();
assert.equal(w.document.querySelector('[data-page=courses]'),null);assert.equal(w.document.querySelector('[data-page=users]'),null);assert.ok(w.document.querySelector('[data-page=students]'));assert.ok(w.document.querySelector('[data-page=lecturers]'));
const session=data.sessions.find(s=>s.is_active).id;t.setFilters({year:'2',semester:'2',session});assert.equal(t.matchingCourses().length,8);
t.setFilters({search:'COM 111',session});assert.equal(t.matchingCourses().length,1);
assert.match(t.filterFields(),/datalist/);
assert.equal(t.parseCourseCSV('code,title,units,year_level,semester_id\nCOM 111,"Computing, basics",2,1,1')[0].title,'Computing, basics');
assert.throws(()=>t.parseCourseCSV('code,title,year_level,semester_id\nX,Y,9,1'));
t.state.role='student';const programme=data.programmes.find(p=>p.code==='ND-CS');t.state.profile={programme_id:programme.id,session_id:session,semester_id:1,year_level:1};t.setFilters({});assert.equal(t.matchingCourses().length,9);
console.log('PASS: separate admin lists, no My Courses/Users approval navigation, cohort filters, suggestions, CSV quoting and validation, student term scope.');

w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};
t.state.role='admin';t.state.people=[{id:'lecturer',full_name:'Lecturer Test',department_id:programme.department_id}];t.setClient({rpc:async()=>({data:{role:'lecturer',courses:[{id:'course',code:'TEST',title:'Course',assignments:1,submissions:0,grades:[],students:[{id:'student',full_name:'Student Test',status:'enrolled',submissions:0,graded:0,percentage:null}]}]},error:null})});
await t.action('person-details','lecturer');assert.match(w.document.querySelector('dialog').textContent,/Student Test/);assert.match(w.document.querySelector('dialog').textContent,/No grades/);assert.match(w.document.querySelector('dialog').textContent,/Allocate a course/);
console.log('PASS: lecturer analytics dialog renders student roster, no-grade state and allocation controls.');
