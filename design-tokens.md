# Source-derived design tokens

Source: https://icp-course-portal.pages.dev/styles.css?v=20261007-letterhead-a4, retrieved 24 October 2026. `public/styles.css` is a byte-for-byte copy of the deployed stylesheet. This file has an earlier dark theme and a later light theme override: CSS cascade determines the active values. Do not use the earlier root block as the final palette.

| Active token | Value | Source |
| --- | --- | --- |
| Background | #f4f8f6 | public/styles.css:162 |
| Surface | #ffffff | public/styles.css:162 |
| Secondary surface | #edf5ef | public/styles.css:162 |
| Border | #dce6df | public/styles.css:162 |
| Text | #17231c | public/styles.css:162 |
| Muted | #67756c | public/styles.css:162 |
| Brand | #008f42 | public/styles.css:162 |
| Dark brand | #006c32 | public/styles.css:162 |
| Gold | #ffb31b | public/styles.css:162 |
| Radius | 14px | public/styles.css:162 |
| Shadow | 0 8px 28px rgba(18,54,34,.07) | public/styles.css:162 |
| Typeface | Inter, Arial, Helvetica, sans-serif | public/styles.css:163 |

No web font is loaded by the original index; actual rendering uses the first available font in that stack. Original gradients, typography, inputs, buttons, sidebar, cards, focus states, media queries and breakpoint definitions remain in the copied stylesheet. `public/portal.css` adds only workflow dialogs, lists and constrained mobile layout rules. SVG icons are copied from the original deployed `app.js` icon helper. Logo is copied from `assets/official-logo.png`.

These are verified source values. Source copying is not a claim that every new screen is pixel-identical to the original. Original/new sign-in content differs to reflect this project's purpose. Compare using `npm run test:ui` and review at 1440px and 390px.
