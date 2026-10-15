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
