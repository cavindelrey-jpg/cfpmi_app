-- CFPMI — pending migrations to apply to Supabase (project ccumxxysaaphhgdzlagk).
-- Paste this whole file into Supabase Dashboard -> SQL Editor -> Run.
-- Safe to run ONCE. On a re-run you may see 'already exists' / 'already member
-- of publication' on policies/realtime — ignore those.

-- ============================================================
-- 20261014120000_attendance_records.sql
-- ============================================================
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
create policy "attendance select" on public.attendance_records
  for select
  using (
    student_id = auth.uid()::text
    or school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

create policy "attendance insert" on public.attendance_records
  for insert
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

create policy "attendance update" on public.attendance_records
  for update
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  )
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

create policy "attendance delete" on public.attendance_records
  for delete
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

-- ============================================================
-- 20261014130000_fee_ledger.sql
-- ============================================================
-- 20261014130000_fee_ledger.sql
-- School fees as a RECORD-ONLY ledger. The app never processes money and has
-- no payment gateway: staff RECORD charges (fee obligations) and payments that
-- actually happened elsewhere (bank statement / payment slip), each with a
-- reference. Outstanding balance = sum(charges) - sum(payments), computed by
-- the client. No in-app transactions, no financial-report generation.
--
-- One row per ledger entry. entry_type is 'charge' or 'payment'. reference
-- holds the bank-statement line / slip / invoice number the entry mirrors.
-- RLS mirrors attendance_records / the roster exactly: school staff record;
-- a student reads only their own entries; super_admin sees all.

create table if not exists public.fee_ledger (
  id uuid primary key default gen_random_uuid(),
  school_id text not null,
  student_id text not null,
  student_name text not null default '',
  class_level text not null default '',
  academic_year text not null default '',
  term text not null default '',
  entry_type text not null check (entry_type in ('charge', 'payment')),
  amount double precision not null default 0,
  entry_date date not null default current_date,
  reference text not null default '',   -- bank-statement line / slip / invoice no.
  note text,
  recorded_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists fee_ledger_school_class_idx
  on public.fee_ledger (school_id, class_level);
create index if not exists fee_ledger_student_idx
  on public.fee_ledger (student_id);

alter table public.fee_ledger enable row level security;

create policy "fee select" on public.fee_ledger
  for select
  using (
    student_id = auth.uid()::text
    or school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

create policy "fee insert" on public.fee_ledger
  for insert
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

create policy "fee update" on public.fee_ledger
  for update
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  )
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

create policy "fee delete" on public.fee_ledger
  for delete
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

-- ============================================================
-- 20261014140000_academia_classroom.sql
-- ============================================================
-- 20261014140000_academia_classroom.sql
-- Academia Classroom: a teacher-controlled, offline-first live lesson with
-- three synchronized views (laptop control / TV display / student mobile).
-- Cloud realtime sync via supabase .stream(); local caching gives offline
-- continuity once materials are downloaded. (LAN/hotspot P2P sync is a
-- documented future step, per the spec.)
--
-- Two tables:
--   classroom_sessions  — one live/prepared lesson. current_slide + status
--                         are the live state the three views subscribe to.
--   classroom_resources — files attached to a session, each with a
--                         visibility state the teacher controls (the
--                         "preload-but-hide" + "release" mechanism).
--
-- Visibility model (section 9):
--   teacher_only   — only the teacher; students may NOT read the row.
--   hidden         — students MAY pre-download/cache the row, but the UI
--                    hides it until released (local existence != visible).
--   released       — students can see and open it.
--   after_class    — students can cache now, UI reveals only after the
--                    session ends.
--
-- RLS mirrors the school trust boundary used across this app (staff resolve
-- their school via users.institution_id). Students of the same school read
-- sessions and every non-teacher_only resource (so they can pre-cache) — the
-- "hidden until released" rule is enforced in the UI, exactly as the spec
-- describes ("their local existence must not expose their content
-- prematurely through the classroom UI").

create table if not exists public.classroom_sessions (
  id uuid primary key default gen_random_uuid(),
  school_id text not null,
  class_level text not null,
  subject text not null default '',
  topic text not null default '',
  teacher_id text not null default '',
  teacher_name text not null default '',
  status text not null default 'prepared' check (status in ('prepared', 'live', 'ended')),
  current_slide int not null default 0,
  slide_urls jsonb not null default '[]'::jsonb,
  original_file text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz
);

create index if not exists classroom_sessions_school_class_idx
  on public.classroom_sessions (school_id, class_level, status);

create table if not exists public.classroom_resources (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.classroom_sessions(id) on delete cascade,
  school_id text not null,
  title text not null default '',
  kind text not null default 'document',  -- document|image|pdf|video|pptx|link
  url text not null default '',
  visibility text not null default 'hidden'
    check (visibility in ('teacher_only', 'hidden', 'released', 'after_class')),
  position int not null default 0,
  released_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists classroom_resources_session_idx
  on public.classroom_resources (session_id);

alter table public.classroom_sessions enable row level security;
alter table public.classroom_resources enable row level security;

-- Helper predicates inlined per policy (no functions, to match this repo's style).

-- Sessions: any member of the school reads; staff of the school write.
create policy "classroom sessions select" on public.classroom_sessions
  for select
  using (
    school_id in (select coalesce(institution_id, id) from public.users where id = auth.uid())
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );
create policy "classroom sessions write" on public.classroom_sessions
  for all
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  )
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

-- Resources: staff read all; students read every non-teacher_only row of
-- their school (so hidden/after_class can be pre-cached), UI gates display.
create policy "classroom resources select" on public.classroom_resources
  for select
  using (
    exists (
      select 1 from public.users u where u.id = auth.uid()
        and u.role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
        and school_id in (select coalesce(u.institution_id, u.id))
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or (
      visibility <> 'teacher_only'
      and school_id in (select coalesce(institution_id, id) from public.users where id = auth.uid())
    )
  );
create policy "classroom resources write" on public.classroom_resources
  for all
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  )
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
  );

-- Live sync: the three views subscribe via supabase .stream(), which needs
-- these tables in the realtime publication (new tables are not realtime by
-- default). Safe to ignore "already member of publication" on a re-run.
alter publication supabase_realtime add table public.classroom_sessions;
alter publication supabase_realtime add table public.classroom_resources;

