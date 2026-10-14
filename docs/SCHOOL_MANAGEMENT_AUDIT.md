# CFPMI — School-Management Audit & Build Log

Started 2026-10-14. CFPMI is a **school-management** app (daily academic +
administrative operations), not a study-material distributor like Academia.
This logs Phase 1 (inspect) findings and what has been implemented against
them. Inspect-first; then implement — not just report.

## Phase 1 — What already exists and works (reused, not rebuilt)

The fork inherits a substantial SMS layer (Supabase-backed, RLS-protected,
`lib/features/school/*`, `lib/repositories/*`, `lib/models/*`):

| Workflow | Status | Where |
|---|---|---|
| School registration / requests | ✅ exists | `school_connect_page`, `school_request_*`, `school_repository` |
| Student roster / admissions / enrolment | ✅ exists | `student_management_page`, `student_roster_page` + CSV import, `student_roster_repository` (`school_students`) |
| Teacher registration + assignments | ✅ exists | `teacher_management_page` + CSV, `teacher_management_repository`, `teaching_assignment` model |
| Subjects | ✅ exists | `manage_subjects_dialog` |
| Timetable | ✅ exists | `timetable_manager_page`, `timetable_page` + CSV, `school_timetable_repository` |
| Marks / results / report cards | ✅ exists | `marks_entry_page`, `marks_page` + CSV, `school_marks_repository` (`school_marks`) |
| Examinations / question bank | ✅ exists | `exam_composer/*`, `exam_repository` |
| Academic calendar / terms | ✅ exists | `school_calendar_*`, `school_calendar_repository` |
| Homework / assignments | ✅ exists | `homework_page`, `homework_repository` |
| Announcements / daily notices | ✅ exists | `daily_notices/*`, `announcement_repository`, `daily_notice_repository` |
| Parents | ✅ exists | `parent_dashboard_page`, `parent_link_repository` |
| Roles / permissions | ✅ exists | `UserRole` (student/lecturer/admin/super_admin) + `SchoolRole` (parent, class master, staff); RLS keys off `users.institution_id` |

## Phase 1 — Confirmed GAPS (the features that make it an SMS)

1. **Attendance — MISSING entirely.** No model/repository/page; the initial
   schema even flags it (`"timetable/attendance/assignments ... See"`).
   → **IMPLEMENTED (this pass).**
2. **School fees / payments — MISSING.** No fee/invoice/payment model,
   repository, or page (the existing `voucher`/`entitlement`/`purchase` are
   the Academia XP economy, not school fees). → **NEXT.**
3. **Consolidated reports** (academic/administrative/financial) — partial;
   per-feature exports exist (`exam_pdf_export`, `school_document_export`),
   no unified reporting hub. → later.
4. **Dedicated finance/secretary roles** (accountant/bursar) — not distinct
   from `staff`/`admin`. Evaluate once fees land.

## Implemented this pass — Attendance (end-to-end)

- **DB**: `supabase/migrations/20261014120000_attendance_records.sql` —
  `attendance_records` table (one row per school/class/date/student/subject),
  RLS mirroring the roster (staff of the school write; students read own;
  super_admin all). *Needs applying to Supabase on next `db push`.*
- **Model**: `lib/models/attendance_record.dart` (+ `AttendanceStatus`).
- **Repository**: `lib/repositories/attendance_repository.dart` —
  `getForClassDate`, `saveBatch` (upsert, no dupes), `getForStudent`.
- **UI**: `lib/features/school/attendance_page.dart` — teacher picks class +
  date, roster loads, per-student P/A/L/E toggle, live counts, save; re-opening
  the same class+date loads the saved register back.
- **Nav**: added to the staff **drawer** and the **School Connect** hub.
- **Tests**: `test/attendance_record_test.dart` (5, passing).

### End-to-end scenario covered (Scenario B — conducting a lesson)
Teacher opens Attendance → picks class/date → roster appears → marks statuses
→ Save → re-open same class/date → saved register is restored. (Admin monitor
view + student self-view are the immediate follow-ups.)

## Still pending (prioritised)
1. Student-facing attendance view + admin attendance monitor/summary.
2. **School fees** module (obligation → payment → outstanding balance → report).
3. Unified reports hub.
4. The two UI redesigns (mobile design system + distinct desktop/web "YouTube-style" app with offline) — separate track, after core functional gaps.
