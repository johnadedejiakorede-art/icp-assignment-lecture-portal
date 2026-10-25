# Academic workspace update

Admin navigation now has Students, Lecturers, Departments & Courses and Lecturer Invitations; My Courses and Users & Approval are removed. People appear once each, with status, an edit dialog and academic analytics. Numeric performance is available to administrators through an admin-only RPC; private file bodies and written lecturer feedback remain restricted. Performance percentages use graded marks weighted by maximum marks, and are explicitly not GPA.

Departments and programmes can be created with CSV course batches (or pasted CSV), containing code,title,units,year_level,semester_id. Session is selected for the whole batch. Existing departments/programmes accept more mappings; duplicate uploads are idempotent. The import is atomic and validates academic fields. Courses support department, level, semester and session filters; all roles have course-code/title search with native dropdown suggestions. Lecturer allocation is available within each lecturer's detail dialog.

Student access now requires exact programme, department, ND level, profile session and semester. Membership synchronization preserves explicit removals. Lecturers access allocated courses mapped to an active session. New notes and assignments require mapped session/semester tags, and student material/submission access checks the current term. Historical content and enrolment records are preserved. Existing untagged content stays out of student current-term views until a lecturer explicitly tags it.

Live verification: the real ND I semester 2 student has 9 active courses for 2026/2027. The other real imported student lacks level/semester in the original source and receives no courses until an administrator completes his record. No level or semester was guessed. FoodCo profile count remains 7.

Checks: JavaScript syntax, PGlite database/RLS tests through migration 013, cohort allow/deny behavior, missing-context deny, admin-only analytics, atomic/idempotent imports, term matching, happy-dom role navigation/filter counts/CSV parsing/search suggestions, existing public routes and invitation picker. A fresh build passes with the configured public Supabase environment. Actual signed-in mobile browser visual testing remains unverified; responsive layouts are implemented with stacked record actions, grid filters and scrollable dialogs.

Existing invitation email provider/redirect configuration remains a separate pending item; no real emails were sent in this update.
