# Department course access and invitation picker

Changes requested from the three mobile screenshots:

- Homepage cards now use the original access-card icon wrapper and a full-width content wrapper. Mobile descriptions occupy the normal text column rather than the narrow icon column.
- Removed the imported-record warning. Approved, identity-verified students automatically receive the mapped courses for their department, across ND levels and semesters. Academic details are preserved; no missing level/semester was invented. Normal account approval remains required.
- Existing explicitly removed/suspended course memberships remain restricted. Department changes update automatic memberships, and later catalogue mapping changes also synchronize affected students. Historical records and documents are retained.
- Hidden legacy demo submissions/feedback are excluded from active UI counts alongside hidden demo assignments, preventing unmatched submission counts.
- Lecturer invitation form has Email Invitation / Registration Link controls, department/programme/ND I-or-II/session/semester filters, scoped course checkboxes, a selection count and an empty-catalogue state. Filter changes clear stale course selections. The backend rejects course IDs outside the selected academic context.
- Named email-bound invitations represent administrator pre-approval: once the intended lecturer verifies their email and redeems a valid invitation, its selected courses activate automatically. Generic links do not preassign courses and still require administrator approval/allocation.

Database scripts: 010_department_access_and_scoped_invites.sql 011_department_catalogue_sync.sql and 012_department_membership_guard.sql, applied after 001–009. No changes to FoodCo data or the original course-registration system.

Passed: JavaScript syntax; public route tests; invitation-filter DOM tests against the authorized catalogue; database tests for missing level/semester, department boundaries, removal persistence, future catalogue synchronization, invalid invitation scope, verified named acceptance and exact allocation. Live database confirmed 36 active department courses for each existing student after the migration.

Email callback/SMTP configuration remains the previously reported separate limitation; this change does not claim real email delivery was tested.

Production deployment 32c67fbf-a6ea-4b13-b8d9-109d6ff2e82f succeeded for commit a9c1ed10777850f1a614a1f78987f768b6a8f877. The refreshed homepage was visually inspected. Tests also confirm department content access is denied when a department is cleared, even if historical membership rows remain. Actual mobile-device screenshot comparison and real email delivery remain unverified.
