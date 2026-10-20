-- 20261020170000_classroom_upload_and_teacher_rls.sql
-- Ensures classroom teachers can always write/update their own classroom sessions
-- and attach presentations/slides/resources.

drop policy if exists "classroom sessions write" on public.classroom_sessions;
create policy "classroom sessions write" on public.classroom_sessions
  for all
  using (
    classroom_sessions.teacher_id = auth.uid()::text
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
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
    classroom_sessions.teacher_id = auth.uid()::text
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
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

drop policy if exists "classroom resources write" on public.classroom_resources;
create policy "classroom resources write" on public.classroom_resources
  for all
  using (
    exists (
      select 1 from public.classroom_sessions cs
      where cs.id = classroom_resources.session_id
        and cs.teacher_id = auth.uid()::text
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
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
    exists (
      select 1 from public.classroom_sessions cs
      where cs.id = classroom_resources.session_id
        and cs.teacher_id = auth.uid()::text
    )
    or exists (select 1 from public.users where id = auth.uid() and role = 'super_admin')
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
