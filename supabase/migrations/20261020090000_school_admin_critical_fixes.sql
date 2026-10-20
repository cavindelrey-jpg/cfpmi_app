-- 20261020090000_school_admin_critical_fixes.sql
-- Critical persistence fixes for School Administration features:
-- 1. school_marks: Allow roster students (text ID std_...) + relax student FK & update trigger
-- 2. school_students: Broaden RLS to check has_school_role (including school_memberships & teachers)
-- 3. fee_ledger: Broaden RLS for school memberships and tenant UUID resolution
-- 4. classroom_sessions & resources: Broaden RLS for school memberships
-- 5. examinations, question_collections, question_bank, school_exam_templates: Create missing tables & RLS

-- ── 1. school_marks ─────────────────────────────────────────────────────────

-- Allow text student IDs (std_... from roster) instead of requiring auth.users UUID
alter table public.school_marks drop constraint if exists school_marks_student_id_fkey;
alter table public.school_marks alter column student_id type text using student_id::text;

-- Update trigger function to accept students from public.school_students OR public.users
create or replace function public.guard_school_mark_student()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user <> 'authenticated' then
    return new;
  end if;

  if not exists (
    select 1 from public.users s
    where s.id::text = new.student_id and (s.institution_id = new.school_id or s.institution_id is null)
  ) and not exists (
    select 1 from public.school_students ss
    where ss.id = new.student_id and ss.school_id = new.school_id
  ) then
    raise exception 'That student isn''t enrolled at this school' using errcode = '42501';
  end if;

  if not public.has_min_role('school_admin') and not exists (
    select 1 from public.users s
    where s.id::text = new.student_id and s.class_level = new.class_level
  ) and not exists (
    select 1 from public.school_students ss
    where ss.id = new.student_id and ss.class_level = new.class_level
  ) then
    raise exception 'That student isn''t in %', new.class_level using errcode = '42501';
  end if;

  return new;
end;
$$;

-- Ensure RLS on school_marks uses has_school_role
drop policy if exists "school marks select" on public.school_marks;
create policy "school marks select" on public.school_marks
  for select
  using (
    student_id = auth.uid()::text
    or public.has_school_role(school_marks.school_id, 'lecturer')
    or exists (
      select 1 from public.parent_links pl
      where pl.parent_id = auth.uid() and pl.student_id::text = school_marks.student_id
    )
  );

drop policy if exists "school marks insert" on public.school_marks;
create policy "school marks insert" on public.school_marks
  for insert
  with check (
    public.has_school_role(school_marks.school_id, 'school_admin')
    or (
      public.has_school_role(school_marks.school_id, 'lecturer')
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  );

drop policy if exists "school marks update" on public.school_marks;
create policy "school marks update" on public.school_marks
  for update
  using (
    public.has_school_role(school_marks.school_id, 'school_admin')
    or (
      public.has_school_role(school_marks.school_id, 'lecturer')
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  )
  with check (
    public.has_school_role(school_marks.school_id, 'school_admin')
    or (
      public.has_school_role(school_marks.school_id, 'lecturer')
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  );

drop policy if exists "school marks delete" on public.school_marks;
create policy "school marks delete" on public.school_marks
  for delete
  using (
    public.has_school_role(school_marks.school_id, 'school_admin')
    or (
      public.has_school_role(school_marks.school_id, 'lecturer')
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  );

-- ── 2. school_students RLS ──────────────────────────────────────────────────

drop policy if exists "school staff select students" on public.school_students;
create policy "school staff select students" on public.school_students
  for select
  using (
    public.has_school_role(school_id, 'lecturer')
  );

drop policy if exists "school staff insert students" on public.school_students;
create policy "school staff insert students" on public.school_students
  for insert
  with check (
    public.has_school_role(school_id, 'lecturer')
  );

drop policy if exists "school staff update students" on public.school_students;
create policy "school staff update students" on public.school_students
  for update
  using (
    public.has_school_role(school_id, 'lecturer')
  );

drop policy if exists "school staff delete students" on public.school_students;
create policy "school staff delete students" on public.school_students
  for delete
  using (
    public.has_school_role(school_id, 'lecturer')
  );

-- ── 3. fee_ledger RLS ────────────────────────────────────────────────────────

drop policy if exists "fee select" on public.fee_ledger;
create policy "fee select" on public.fee_ledger
  for select
  using (
    student_id = auth.uid()::text
    or exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and (
          u.role = 'super_admin'
          or (
            u.role in ('lecturer', 'department_admin', 'school_admin')
            and (
              u.institution_id::text = fee_ledger.school_id
              or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
            )
          )
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = fee_ledger.school_id
          or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  );

drop policy if exists "fee insert" on public.fee_ledger;
create policy "fee insert" on public.fee_ledger
  for insert
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and (
          u.role = 'super_admin'
          or (
            u.role in ('lecturer', 'department_admin', 'school_admin')
            and (
              u.institution_id::text = fee_ledger.school_id
              or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
            )
          )
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = fee_ledger.school_id
          or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  );

drop policy if exists "fee update" on public.fee_ledger;
create policy "fee update" on public.fee_ledger
  for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and (
          u.role = 'super_admin'
          or (
            u.role in ('lecturer', 'department_admin', 'school_admin')
            and (
              u.institution_id::text = fee_ledger.school_id
              or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
            )
          )
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = fee_ledger.school_id
          or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and (
          u.role = 'super_admin'
          or (
            u.role in ('lecturer', 'department_admin', 'school_admin')
            and (
              u.institution_id::text = fee_ledger.school_id
              or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
            )
          )
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = fee_ledger.school_id
          or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  );

drop policy if exists "fee delete" on public.fee_ledger;
create policy "fee delete" on public.fee_ledger
  for delete
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and (
          u.role = 'super_admin'
          or (
            u.role in ('lecturer', 'department_admin', 'school_admin')
            and (
              u.institution_id::text = fee_ledger.school_id
              or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
            )
          )
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = fee_ledger.school_id
          or fee_ledger.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  );

-- ── 4. classroom_sessions & resources RLS ────────────────────────────────────

drop policy if exists "classroom sessions select" on public.classroom_sessions;
create policy "classroom sessions select" on public.classroom_sessions
  for select
  using (
    classroom_sessions.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
    or school_id in (select coalesce(institution_id::text, id::text) from public.users where id = auth.uid())
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or exists (select 1 from public.school_memberships m where m.user_id = auth.uid() and m.school_id::text = classroom_sessions.school_id)
  );

drop policy if exists "classroom sessions write" on public.classroom_sessions;
create policy "classroom sessions write" on public.classroom_sessions
  for all
  using (
    exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('lecturer', 'department_admin', 'school_admin')
        and (
          u.institution_id::text = classroom_sessions.school_id
          or classroom_sessions.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = classroom_sessions.school_id
          or classroom_sessions.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  )
  with check (
    exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('lecturer', 'department_admin', 'school_admin')
        and (
          u.institution_id::text = classroom_sessions.school_id
          or classroom_sessions.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = classroom_sessions.school_id
          or classroom_sessions.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  );

drop policy if exists "classroom resources select" on public.classroom_resources;
create policy "classroom resources select" on public.classroom_resources
  for select
  using (
    exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or classroom_resources.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
    or exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and (
          u.role in ('lecturer', 'department_admin', 'school_admin')
          or visibility <> 'teacher_only'
        )
        and u.institution_id::text = classroom_resources.school_id
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and m.school_id::text = classroom_resources.school_id
    )
  );

drop policy if exists "classroom resources write" on public.classroom_resources;
create policy "classroom resources write" on public.classroom_resources
  for all
  using (
    exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('lecturer', 'department_admin', 'school_admin')
        and (
          u.institution_id::text = classroom_resources.school_id
          or classroom_resources.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = classroom_resources.school_id
          or classroom_resources.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  )
  with check (
    exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
    or exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('lecturer', 'department_admin', 'school_admin')
        and (
          u.institution_id::text = classroom_resources.school_id
          or classroom_resources.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
    )
    or exists (
      select 1 from public.school_memberships m
      where m.user_id = auth.uid()
        and (
          m.school_id::text = classroom_resources.school_id
          or classroom_resources.school_id in ('cfpmi', '446007a8-4389-40eb-bfa7-5452541b5a1f')
        )
        and public.role_level(m.role) >= public.role_level('lecturer')
    )
  );

-- ── 5. Examinations & Exam Composer Tables ───────────────────────────────────

create table if not exists public.examinations (
  id text primary key,
  school_id text not null,
  title text not null,
  examination_type text not null,
  subject text not null default '',
  class_level text not null default '',
  academic_year text not null default '',
  duration_minutes int not null default 90,
  date timestamptz not null default now(),
  examiner_name text not null default '',
  examiner_id text not null default '',
  instructions text not null default '',
  total_marks double precision not null default 100,
  template_id text,
  selected_template jsonb,
  questions jsonb not null default '[]'::jsonb,
  status text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists examinations_school_class_idx
  on public.examinations (school_id, class_level);
create index if not exists examinations_examiner_idx
  on public.examinations (examiner_id);

alter table public.examinations enable row level security;

create policy "examinations select" on public.examinations
  for select
  using (
    auth.uid() is not null
  );

create policy "examinations insert" on public.examinations
  for insert
  with check (
    auth.uid() is not null
  );

create policy "examinations update" on public.examinations
  for update
  using (
    auth.uid() is not null
  )
  with check (
    auth.uid() is not null
  );

create policy "examinations delete" on public.examinations
  for delete
  using (
    auth.uid() is not null
  );

-- Question collections
create table if not exists public.question_collections (
  id text primary key,
  school_id text not null,
  teacher_id text not null,
  name text not null,
  description text not null default '',
  subject text not null default '',
  questions jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists question_collections_teacher_idx
  on public.question_collections (teacher_id);

alter table public.question_collections enable row level security;

create policy "question collections all" on public.question_collections
  for all
  using (
    auth.uid() is not null
  )
  with check (
    auth.uid() is not null
  );

-- Question bank
create table if not exists public.question_bank (
  id text primary key,
  content text not null default '',
  marks int not null default 5,
  type text not null default 'structured',
  subject text not null default '',
  class_level text not null default '',
  topic text not null default '',
  subtopic text not null default '',
  difficulty text not null default 'medium',
  source text not null default 'School Question Bank',
  source_ref text,
  year int,
  options jsonb not null default '[]'::jsonb,
  correct_option_index int,
  rubric text,
  expected_points jsonb not null default '[]'::jsonb,
  tags jsonb not null default '[]'::jsonb,
  school_id text,
  created_by text,
  created_at timestamptz not null default now()
);

create index if not exists question_bank_subject_idx
  on public.question_bank (subject);

alter table public.question_bank enable row level security;

create policy "question bank all" on public.question_bank
  for all
  using (
    auth.uid() is not null
  )
  with check (
    auth.uid() is not null
  );

-- School exam templates
create table if not exists public.school_exam_templates (
  id text primary key,
  school_id text not null,
  name text not null default '',
  type text not null default 'examination',
  school_name text not null default '',
  school_logo_url text,
  country_header text not null default '',
  sub_header text not null default '',
  motto text not null default '',
  include_student_fields boolean not null default true,
  include_instructions_box boolean not null default true,
  include_marks_box boolean not null default true,
  font_family text not null default 'Serif',
  is_default boolean not null default false,
  default_instructions text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists school_exam_templates_school_idx
  on public.school_exam_templates (school_id);

alter table public.school_exam_templates enable row level security;

create policy "school exam templates all" on public.school_exam_templates
  for all
  using (
    auth.uid() is not null
  )
  with check (
    auth.uid() is not null
  );

-- Realtime publications
do $$ begin alter publication supabase_realtime add table public.examinations; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.question_collections; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.school_exam_templates; exception when duplicate_object then null; end $$;
