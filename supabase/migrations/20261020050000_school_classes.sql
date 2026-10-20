-- 20261020050000_school_classes.sql
-- Configurable school-specific classes for technical, vocational, and secondary schools.

create table if not exists public.school_classes (
  id text primary key,
  school_id uuid not null references public.institutions(id) on delete cascade,
  name text not null,
  code text,
  programme text,
  academic_year text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint school_classes_school_name_unique unique (school_id, name)
);

create index if not exists school_classes_school_order_idx on public.school_classes (school_id, display_order);
create index if not exists school_classes_school_active_idx on public.school_classes (school_id, is_active);

alter table public.school_classes enable row level security;

-- Authenticated school members can read classes
create policy "school members can read classes" on public.school_classes
  for select
  using (
    school_id in (
      select coalesce(school_id, institution_id) from public.users
      where id = auth.uid()
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

-- School staff / admins can insert classes
create policy "school staff can insert classes" on public.school_classes
  for insert
  with check (
    school_id in (
      select coalesce(school_id, institution_id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

-- School staff / admins can update classes
create policy "school staff can update classes" on public.school_classes
  for update
  using (
    school_id in (
      select coalesce(school_id, institution_id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

-- Only school admins and super admins can delete classes
create policy "school admins can delete classes" on public.school_classes
  for delete
  using (
    school_id in (
      select coalesce(school_id, institution_id) from public.users
      where id = auth.uid() and role in ('department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );
