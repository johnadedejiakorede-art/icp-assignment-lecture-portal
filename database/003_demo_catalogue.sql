-- Optional synthetic catalogue only. Create Auth accounts separately; no real student data.
insert into departments(id,name) values('10000000-0000-4000-8000-000000000001','Computer Science') on conflict do nothing;
insert into courses(code,title,department_id) values
('COM 211','Computer Programming','10000000-0000-4000-8000-000000000001'),
('COM 212','Computer Hardware','10000000-0000-4000-8000-000000000001'),
('GNS 202','Communication in English II','10000000-0000-4000-8000-000000000001') on conflict do nothing;
