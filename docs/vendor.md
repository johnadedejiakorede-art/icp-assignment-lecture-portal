# Vendored browser SDK

`public/vendor/supabase.js` was retrieved from the original deployed ICP frontend on 24 October 2026. It is stored as an immutable source asset with its SHA-256 in `source-digests.json`; the original deployment did not provide package metadata identifying its exact release. It is not fetched from a moving CDN URL at runtime. Supabase JavaScript client is open-source under MIT; see https://github.com/supabase/supabase-js/blob/master/LICENSE.

The original browser SDK file is retained to match the existing stack; future updates should deliberately replace it with a known tested release and update the digest. Test dependencies are exact-version pinned with package-lock.json.
