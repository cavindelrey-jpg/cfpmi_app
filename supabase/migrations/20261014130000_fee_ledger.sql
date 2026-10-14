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
