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
   the Academia XP economy, not school fees). → **IMPLEMENTED (record-only
   ledger, per user: no transactions through the app, no financial reports —
   staff record charges/payments from the bank statement; app tracks balances).**
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

## Implemented this pass — Fees (record-only ledger)
Per user: the app performs **no transactions** and generates **no financial
reports** — staff only RECORD charges and payments (sourced from the bank
statement / slip) and the app derives outstanding balances.
- **DB**: `supabase/migrations/20261014130000_fee_ledger.sql` — `fee_ledger`
  (charge|payment entries, `reference` holds the bank-statement line), RLS
  mirrors attendance. *Needs applying on next `db push`.*
- **Model**: `lib/models/fee_ledger_entry.dart` (+ `StudentFeeBalance`).
- **Repository**: `lib/repositories/fee_repository.dart` — `addEntry`,
  `getForStudent`, `getForClass`, pure `balancesFrom()`.
- **UI**: `lib/features/school/fees_page.dart` — class → per-student balances
  (charged/paid/outstanding) → open student → ledger + Record charge / Record
  payment (amount, date, bank reference, note).
- **Nav**: staff **drawer** → Fees.
- **Tests**: `test/fee_ledger_test.dart` (5, passing — the balance math).

## Distinct web vs mobile UI — adaptive shell (started)
"To each lock its own key." `lib/screens/app_router.dart` `HomeShell` now
branches at a 900px breakpoint:
- **Mobile (< 900px):** the existing bottom `NavigationBar` capsule + FAB +
  drawer. Unchanged.
- **Desktop/web (≥ 900px):** a persistent **left sidebar** (YouTube-style) —
  brand wordmark + menu, one gold "Create" CTA, vertical nav with a 4-change
  active state (filled icon + brand colour + bold + tinted pill + left
  indicator bar), account row → Profile; content is width-capped (1180px) and
  centred. No bottom bar.
Same pages, tab state and role gating feed both — one shell, two surfaces.
(Guest shell + per-page multi-column desktop layouts are follow-ups.)

## Still pending (prioritised)
1. Apply remaining web rules per page (multi-column desktop layouts) + mobile
   design-note polish; extend the adaptive shell to the guest shell.
2. Student-facing views (attendance + fees balance) and admin monitors.
3. Unified operational dashboards (no financial reports, per user).

## Deployment caveat
Both new tables (`attendance_records`, `fee_ledger`) are committed as
migrations but must be applied to Supabase via `supabase db push` (no Supabase
login in the build sandbox). Until applied, the screens render but save/load
against those tables will error.
