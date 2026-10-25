# Deployment validation — 25 October 2026

Live frontend: https://icp-assignment-portal.pages.dev/
Backend: isolated ICP tables in Supabase project enwlfhfkbrqrkpfotpgy.

Passed: JavaScript syntax; embedded PostgreSQL RLS/deadline tests; Cloudflare production build/deployment; all four demo account password logins through Supabase Auth; three private PDF note uploads; two published assignments; student submission upload; lecturer score/feedback publication; own published feedback read; second student denied access to another submission/file; anonymous private-file access denied; course member note download. Live login page rendered and visually inspected in browser.

Four presentation accounts have independent portal profiles. No passwords are stored in this repository. Demo contents are synthetic. FoodCo row counts before/after: 7 profiles, 32 products, 11 orders. The shared signup trigger now excludes only ICP-marked registrations; FoodCo registrations retain their existing path.

Portal helper search_path warnings were corrected. Existing notices for other applications were outside this change.

Limitations: browser UI login and all interactive role routes were not end-to-end browser-tested; API workflow checks passed. Mobile screenshot comparison remains pending. New-user email confirmation and password-recovery redirects/SMTP delivery have not been configured or verified because the connected management account did not have access to the shared project's Auth configuration. Existing confirmed demo logins work. Shared Auth settings were left unchanged.

The original ICP course-registration database/site was not modified. Shared-hosting compatibility deliberately modifies the FoodCo Auth trigger condition to prevent portal users from receiving FoodCo profiles; no FoodCo data or business function was removed.
