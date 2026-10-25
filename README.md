# Deployment update — 25 October 2026

The live portal uses the existing Supabase project `enwlfhfkbrqrkpfotpgy` with isolated `icp_` tables, `portal_private` helpers and `icp-` private buckets. It shares Auth infrastructure with FoodCo. Portal signups carry `portal_app=icp_lecture`; the shared-hosting migration excludes those signups from FoodCo profile creation. Existing FoodCo records remain unchanged. See `docs/migration.md`.

# ICP Assignment & Lecture Note Portal

An independent academic project for Ibadan City Polytechnic, Ibadan. Static HTML/CSS/JavaScript frontend, Supabase Auth/Postgres/private Storage, Cloudflare Pages hosting.

## Included

- Administrator approval/suspension, departments, courses, student membership and lecturer allocations.
- Lecturer note upload/replacement, publish/unpublish, assignment drafting/publishing/closing, roster, grading and CSV export.
- Student course access, private submission/replacement before deadline, submission receipt and published feedback.
- In-app notifications and upcoming deadline indicators.
- Original deployed ICP stylesheet, logo, navigation/icon patterns and authentication layout.
- Database-enforced permissions, ownership, grading bounds and deadlines.

Course registration, semester results, GPA/CGPA, attendance, payments, chat and AI grading are outside this project.

## Import into another person's own accounts

This is a **private template repository**. Give the intended person access in GitHub Settings → Collaborators first. They can then use **Use this template → Create a new repository** under their own account, or copy a downloaded ZIP into a new repository. Their copy has independent code history and deployment settings. Do not share your account passwords or service-role key.

### 1. Create their new Supabase project

Create a separate project in their own organization. In its SQL editor, run the files in order:

1. `database/001_schema.sql`
2. `database/002_storage_notifications.sql`
3. `database/003_demo_catalogue.sql` (optional synthetic catalogue)
4. `database/004_shared_auth_isolation.sql` (shared-hosting compatibility; no-op without FoodCo)
5. `database/005_submission_bucket_name.sql` (compatibility correction)
6. `database/006_helper_search_path.sql` (helper hardening)

The scripts are one-time installation scripts for an empty project. They deliberately fail on name collisions; they do not drop existing data. Use a fresh project if setup fails halfway; each numbered script is transactional.

Enable email/password authentication with email confirmation. Under Authentication → URL Configuration, set their Pages URL as Site URL and allow both `https://THEIR-SITE.pages.dev/` and `https://THEIR-SITE.pages.dev/?recovery=1` as redirect URLs. Add exact custom-domain equivalents if used. Configure their own SMTP if needed for account email delivery. Application notifications themselves are in-app only.

### 2. Connect their GitHub repository to Cloudflare Pages

In their Cloudflare account, Workers & Pages → Create application → Pages → Import an existing Git repository. Select their copied repository.

| Setting | Value |
| --- | --- |
| Framework preset | None |
| Production branch | main |
| Build command | npm run build |
| Build output directory | dist |
| Root directory | repository root |
| SUPABASE_URL | Their new project URL |
| SUPABASE_PUBLISHABLE_KEY | Their publishable key (or legacy anon key) |

Set both environment variables in the production and any preview environment they use. Rebuild after changing them. The build writes public client configuration into `dist/config.js`; these values are intended to be public. Never put a secret/service-role key there. The build refuses the original ICP project URL and known secret key formats.

### 3. Create the first administrator

Sign up through the new portal with their administrator email, confirm that email, then run a copy of `database/bootstrap-admin.sql.example` in their new Supabase SQL editor, replacing the email. Sign in again. No preset administrator password is stored in this repository.

### 4. Complete the demonstration

Create two lecturer and four student accounts using the portal, confirming each email. As admin, approve users, assign appropriate roles/departments, allocate the lecturers to three courses and assign student memberships. Sign in as lecturers to upload three sample notes and publish two assignments; use student accounts to submit synthetic work. Grade and publish feedback from the allocated lecturer account.

Do not import original ICP users, student records, authentication sessions or files. This is a clean installation, not a copy of the original production database.

## Local development

Node 20+ is sufficient. The Supabase browser SDK is vendored from the deployed ICP frontend, so the application has no runtime package installation dependency.

```sh
npm ci
export SUPABASE_URL=https://YOUR-NEW-PROJECT.supabase.co
export SUPABASE_PUBLISHABLE_KEY=sb_publishable_REPLACE_ME
npm run build
python -m http.server 8080 --directory dist
```

The `.env.example` documents environment names; the build reads exported environment variables, not `.env` automatically.

```sh
npm run check
npm test
npx playwright install chromium
npm run test:ui
```

Database tests use an embedded PostgreSQL engine with simulated Auth/Storage schemas. UI tests use a mocked Supabase client. Neither replaces the live-account acceptance checks in `docs/acceptance.md`.

## File handling and privacy

Notes/attachments accept PDF, DOCX and PPTX up to 15 MB; submissions accept PDF/DOCX up to 10 MB. Both buckets are private. Downloads use authenticated requests and local blob URLs, not permanent public links. Storage validates declared MIME type/size; it is not an antivirus/content inspection service. Users should upload trusted academic documents.

One current submission per student/assignment is enforced by a unique constraint. Replacements use new immutable file objects and delete old unreferenced files after saving. Failed cleanup can leave private orphan files; owners can remove unreferenced objects via Storage. Replacing a submission clears its old grade. Due dates use browser local time for entry/display and UTC timestamps plus database server time for enforcement.

Approved administrators see content metadata, but submission files/grades are deliberately restricted to the student and allocated lecturers. Suspending a user removes access at the next database request. Files already downloaded remain on that user's device.

## Validation and limitations

See `docs/validation.md` for actual checks and unresolved live/browser verification. This repository contains implementation code, not an already configured live installation in the recipient's accounts. Their Supabase project, SMTP, Auth redirects and Cloudflare environment must be configured before use.

The source styles and assets were retrieved from the existing Cloudflare deployment on 24 October 2026. `design-tokens.md` and `reuse-inventory.md` describe the exact reuse. New workflow content naturally changes page content and dimensions; full visual parity requires screenshot review.

## Rollback

Restore a previous GitHub commit and redeploy Cloudflare Pages to roll back frontend code. Back up the new Supabase project before schema changes; reverting frontend code does not revert the database. For an unused demo installation, remove only its new Cloudflare/Supabase projects after confirming their identities. Original ICP resources are not installation targets.
