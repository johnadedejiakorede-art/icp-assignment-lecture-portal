# Selective reuse inventory

Inspected read-only: Cloudflare Pages metadata for `icp-course-portal`, production deployment `c0754d7e-53e9-48b4-ae6f-9982cd60bade`; public `index.html`, `styles.css`, `app.js`, `assets/official-logo.png` and `vendor/supabase.js` from https://icp-course-portal.pages.dev/.

| Original file/component | New location | Treatment |
| --- | --- | --- |
| styles.css | public/styles.css | Copied exactly; light theme override retained |
| assets/official-logo.png | public/assets/official-logo.png | Copied exactly |
| vendor/supabase.js | public/vendor/supabase.js | Existing browser SDK copied; frozen file digest recorded |
| app.js renderLogin | public/app.js auth | Same auth-side/auth-main layout and styling; scoped copy text and accessible labels |
| app.js renderShell | public/app.js shell | Same brandbar/sidebar/grid pattern, scoped navigation |
| app.js icon | public/app.js icon | SVG paths/helper copied |
| app.js renderLogin | tests/original-login.html | Original template isolated for visual comparison; no production credentials |
| Original data/Auth configuration | none | Not copied |
| Course/result processing handlers | none | Excluded |
| Original schema | none | New focused schema; does not alter source system |

The original app.js was inspected locally but deliberately excluded from the repository because it contains original environment configuration and unrelated workflows. Its copy is ignored under `reference/`. New schema, policies, workflows, tests and deployment build were authored for this project.

No original Cloudflare deployment, Supabase schema, account, file or record was modified. No live target Supabase project is hardcoded. Source asset checksums: `docs/source-digests.json`.
