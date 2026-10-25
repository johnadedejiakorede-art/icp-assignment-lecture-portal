# Homepage, invitations and one-time student import — 25 October 2026

## Baseline and rollback

Source baseline: GitHub commit 33c590764116609f063a57582ba347699061dadd. Local tag: pre-homepage-invitations-20261025. The schema/functions/policies snapshot is stored in backups/schema-before-update-20261025.json; it contains no password hashes, user identities or student documents. Prior source commits remain available for frontend rollback. Database changes are additive except replacement of portal policies/functions, and the demo-course unique key is extended to distinguish imported catalogue rows. Do not roll back database objects by dropping tables that now contain live data.

## Completed

- Original ICP header, footer, hero art, stylesheet, colours, typography and logo reused for a default public homepage.
- Separate Student Login and Staff Login routes; roles remain server-authorized.
- Student-only public signup with matric/approved temporary identifier and programme/level/session/semester; unverified applicants remain pending. No public role selector.
- 36 authorized source catalogue courses, two programmes and 72 curriculum mappings copied as a local snapshot. No runtime link to original ICP.
- Approved, independently verified students auto-enrol from local mappings. Lecturer removal/suspension status survives re-enrolment; membership history is append-only.
- Hashed, expiring, revocable lecturer invitations with email binding, usage limits, atomic redemption and administrator approval. Named invitations apply selected courses after approval; generic links never preassign courses.
- Backend icp-lecturer-invite function validates administrator authorization before using Supabase Auth's email delivery. Mail failures are recorded, not reported as sent. New invitees can set their password from the confirmation homepage.
- Administrator file access removed; counts/participation/workload are provided through a guarded aggregate endpoint. Lecturer membership actions are course-scoped. Private coursework audit records preserve past submission/feedback values.
- Existing coursework, accounts and files are retained. Historical demonstration catalogue rows are excluded from the active UI.

## One-time student copy

The source had two student records; both portal profiles were copied with source academic identifiers. No credentials or identifiable student snapshots are committed to GitHub.

One email did not exist in the destination Auth service: its credential was transferred directly between trusted services without printing it or saving it in a file/repository. The other email already belonged to a FoodCo Auth user: its portal profile uses that destination identity, while the existing FoodCo password remains untouched. Therefore that student must use the shared backend account password, not assume the original course-portal password applies. Separate Auth projects are needed to keep different passwords for the same email.

One student's source context yielded nine enrolled courses. The other source lacked level/semester, so automatic enrolment is pending an administrator correction. No academic context was fabricated. This copy has no ongoing synchronization.

## Tests

Passed locally: existing coursework/RLS/deadline tests; public homepage and separate login links; no public lecturer selector; academic signup fields; invitation-only lecturer form; student-only signup even with forged role metadata; automatic enrolment; persistence of lecturer removal; named invitation redemption; repeat-use rejection; revocation rejection; course allocation after approval; administrator metadata analytics; administrator note-file access denied.

Live database migrations 007–009 and edge function are installed. Source catalogue import and student profile/enrolment counts verified. FoodCo profile count remains seven.

## Remaining verification / blockers

- Supabase Auth redirect allow-list and delivery/SMTP settings require management access. The current management connector previously returned Forbidden for this shared project. No shared Auth settings were changed. Email confirmation, password recovery and delivered named invitation callbacks must be verified after the portal origin/query callback routes are added to the allow-list while preserving other apps' entries. The server mail handler exists, but real email delivery has not been claimed as tested.
- No actual invitations were emailed to real people during verification.
- Imported existing-account passwords were not entered or exposed to run login tests. Existing demo Auth logins had passed before this update.
- Full mobile screenshot comparison and signed-in browser route checks remain to be completed. DOM and database tests are not a substitute for those checks.

## Standalone migration plan

The portal is standalone from the source course-registration application; it still shares infrastructure/Auth with FoodCo due the free-project limit. A fully separate Supabase Auth/Storage deployment remains a separate reversible step: provision an available target project, install database scripts in order, privately transfer only authorized portal Auth identities and icp_ records/files, resolve any existing-email conflict before switching, add target redirects, validate isolation, then change only the portal Cloudflare environment and rebuild. Preserve the old portal dataset temporarily for rollback. Never migrate FoodCo tables or change its credentials, and never put credentials into the repository.
