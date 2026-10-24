# Live acceptance checks for the new installation

Use synthetic accounts and data only. Perform these after deployment in the recipient's new accounts.

1. Confirm email signup, login, password reset and pending approval. Confirm a student cannot select or self-authorize administrator/lecturer access.
2. Admin creates a department/course, approves a lecturer and two students, allocates the lecturer and assigns students. Check suspension denies further data access.
3. Allocated lecturer uploads a draft PDF note. Students cannot read it. Publish it and confirm a member can download it; a nonmember and anonymous request cannot.
4. Replace the note, download the replacement, unpublish and delete. Confirm clear validation for unsupported/oversized files.
5. Lecturer publishes an assignment with optional attachment, future due time and maximum score. Member students can view it and receive an in-app notification.
6. Student A uploads work and sees a receipt. Replace before deadline; verify one active row, updated timestamp and old feedback cleared.
7. Student B must not retrieve Student A's row, file or feedback using direct API requests or guessed IDs. A nonallocated lecturer must also be denied.
8. Lecturer views roster, submitted/pending counts, downloads work, saves draft feedback then publishes it. Student A sees only published own feedback. Scores outside 0..maximum fail.
9. Try submitting after the server deadline with the browser clock changed; both object upload and metadata save must fail. Account for timezone display.
10. Verify new note, assignment and feedback notifications; mark read. Upcoming deadlines are derived from visible assignments, with no scheduler.
11. Verify all screens at 1440px and 390px. Compare source login fixture/new login, source stylesheet tokens and dashboard shell. Review keyboard focus, dialog close, no horizontal overflow and recoverable errors.
12. Check Supabase Security Advisor and Auth/Storage logs. Verify original ICP production website and database were not modified.

UI mocks and embedded database tests do not prove live Supabase Auth, Storage HTTP behavior, SMTP deliverability or Cloudflare deployment. Record actual results separately; do not label unchecked items as passed.
