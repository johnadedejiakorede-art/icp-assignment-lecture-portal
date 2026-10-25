# Moving the lecture portal to its own Supabase project

The portal is currently colocated with FoodCo. Keep every `icp_` table, private `portal_private` functions and `icp-` storage bucket separate from `fc_` data.

For a fresh installation, run numbered database scripts 001–005 in the recipient project, configure their publishable URL/key in Cloudflare and bootstrap their administrator. New signup requests must include `portal_app: icp_lecture`. There are no embedded administrator credentials in GitHub.

To preserve live data, stop portal writes during the move, export only portal profiles/roles/courses/content/memberships/submissions/feedback/notifications and related Auth users/identities, and transfer the two portal buckets via authenticated Storage API. Preserve UUIDs and original object paths. Do not export FoodCo users or tables. Transfer Auth identities/password hashes using a supported administrative migration process; otherwise have portal users reset their passwords and reconcile UUIDs before restoring dependent rows. Migrate accounts that belong to both apps with particular care.

Restore Auth identities first, then table data in dependency order, then file objects. Run RLS/access tests for student privacy and lecturer allocations. Configure exact portal confirmation/recovery redirects in the new project without changing any unrelated app redirects. Switch Cloudflare environment URL/key, rebuild, test, and retain the old portal data temporarily for rollback. Only remove old portal objects after successful verification; do not remove shared FoodCo/Auth data.

The repository contains schema and app code. Uploaded files, passwords, live records and Auth configuration are not included automatically by a GitHub clone.

## Homepage/invitation update

Install 007_portal_enrolment_invitations.sql, 008_authorized_catalogue.sql and 009_registration_and_invite_delivery.sql after scripts 001–006. Deploy supabase/functions/icp-lecturer-invite/index.ts as `icp-lecturer-invite` with JWT verification enabled. It uses the platform-provided SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY only on the server. For another deployment origin, change the explicit allowed origin in that function and redeploy.

Add the new portal's callback/verification/recovery routes to Supabase's redirect allow-list, preserving all unrelated app entries if hosting is shared. Verify actual email delivery before calling invitation email complete. A generic invitation link and a named email invitation have different allocation rules. The local catalogue snapshot contains academic structure only.

Two students were imported once in the current deployment. One shares an existing destination FoodCo Auth email; its original destination password was deliberately preserved. A migration to a truly separate Auth project must explicitly decide which credential the owner intends to retain for that email. Never replace an unrelated app's credential silently.
