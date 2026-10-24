# Validation record — 24 October 2026

## Passed

- JavaScript syntax checks (`npm run check`).
- Embedded PostgreSQL installation of all three numbered SQL files.
- Synthetic Auth signup trigger and profile creation.
- RLS on all 11 exposed tables.
- Member access to published assignments and notes; draft notes and files hidden.
- Student attempts to approve themselves/change roles do not update rows.
- Student cannot insert lecturer notes.
- Student B cannot read Student A submission row or file.
- Nonallocated lecturer cannot read/grade that submission.
- Draft grades hidden; published own grade visible.
- Score above assignment maximum rejected.
- New submission receipt and notification creation.
- Replacing work clears existing feedback.
- Submission/object upload after server deadline rejected.
- Admin submission access restricted; anonymous table access rejected.
- Static build with placeholder target configuration succeeds.
- Original ICP URL and server secret key build guards reject unsafe configuration.
- Copied deployed stylesheet is byte-identical to retrieved source; asset digests recorded.

Database tests use PGlite PostgreSQL with minimal simulated Auth/Storage tables and real RLS/trigger execution. They do not test Supabase's HTTP services or its object-store payload validation.

## Not verified in this environment

- Browser screenshots and responsive rendering: Playwright Chromium installation failed (browser archive download was incomplete). `tests/frontend.mjs` is supplied but has not passed here. It uses a mocked Supabase client and compares source style tokens at 1440px/390px.
- Live Supabase Auth email confirmation/recovery, Storage HTTP requests, deployed frontend/backend integration and SMTP delivery.
- Pixel-by-pixel similarity across all three role dashboards.
- Live acceptance checklist: requires a new target Supabase project and Cloudflare deployment in the recipient's accounts.

No new live database or Cloudflare deployment was created for this source-code handoff. Existing ICP resources were read only and were not changed.
