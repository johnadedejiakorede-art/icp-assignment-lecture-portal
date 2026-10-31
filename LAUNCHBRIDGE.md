# LaunchBridge deployment

Run npm ci, npm run check, and node tests/launchbridge-fresh.mjs. Build with public SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY; output is dist. The test uses a local PostgreSQL-compatible fixture, not a live Supabase service.

launchbridge.json declares the 14 required SQL files in order. The synthetic optional catalogue is deliberately excluded. The real student/lecturer data from an existing deployment is not copied.

The invitation Edge Function uses APP_ORIGIN (or PORTAL_ORIGIN) supplied by LaunchBridge. It validates the bearer user and approved administrator role. Gateway verify_jwt=false is explicit because the function performs Auth validation itself; review the source and confirm this configuration when deploying.

Supply the designated initial administrator email. After deployment, retrieve the private owner setup link in LaunchBridge. Register that email, verify it, sign in and claim the invitation once. Other visitors stay ordinary users. The owner invitation cannot reopen after deletion. Existing administrators are preserved; never rerun all schema scripts against an existing populated backend. Apply new migrations once through a controlled upgrade.

Only public configuration goes in the frontend. Never supply a service-role key to a frontend build. Connect an authorized GitHub account, current Cloudflare account, and Supabase organization with project/database/auth/functions/secrets permissions. Provider quotas still apply.
