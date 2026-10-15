-- 20261014120000_attendance_records.sql
-- Daily student attendance — the core school-management operation that was
-- missing (the initial schema explicitly flagged attendance as a gap:
-- "timetable/attendance/assignments ... See"). One row per
-- (student, class, session_date, subject). subject = '' means a whole-day /
-- homeroom register; a subject value scopes it to one period. Teachers and
-- school staff record; a student reads only their own rows.
--
-- RLS mirrors public.school_students (the roster) exactly: staff resolve
-- their own school via users.institution_id (users has no school_id column),
-- and super_admin sees everything. Same single-school trust boundary the
-- roster and marks already use.

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  school_id text not null,
  class_level text not null,
  subject text not null default '',
  session_date date not null,
  student_id text not null,
  student_name text not null default '',
  status text not null default 'present'
    check (status in ('present', 'absent', 'late', 'excused')),
  note text,
  recorded_by text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, class_level, session_date, student_id, subject)
);

create index if not exists attendance_class_date_idx
  on public.attendance_records (school_id, class_level, session_date);
create index if not exists attendance_student_idx
  on public.attendance_records (student_id);

alter table public.attendance_records enable row level security;

-- Staff of the row's school (or super_admin) read/write; a student reads
-- only their own rows.
drop policy if exists "attendance select" on public.attendance_records;
create policy "attendance select" on public.attendance_records
  for select
  using (
    student_id = auth.uid()::text
    or school_id in (
      select coalesce(institution_id::text, id::text) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

drop policy if exists "attendance insert" on public.attendance_records;
create policy "attendance insert" on public.attendance_records
  for insert
  with check (
    school_id in (
      select coalesce(institution_id::text, id::text) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

drop policy if exists "attendance update" on public.attendance_records;
create policy "attendance update" on public.attendance_records
  for update
  using (
    school_id in (
      select coalesce(institution_id::text, id::text) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  )
  with check (
    school_id in (
      select coalesce(institution_id::text, id::text) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

drop policy if exists "attendance delete" on public.attendance_records;
create policy "attendance delete" on public.attendance_records
  for delete
  using (
    school_id in (
      select coalesce(institution_id::text, id::text) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );
