# Academia Classroom (CFPMI) — foundation

Teacher-controlled, offline-first live lesson with three synchronized views.
Built per the spec's instruction to lay the **foundation** (section 12), not
every future feature. CFPMI repo only.

## The three views (all implemented)
- **Teacher Control** — `features/classroom/classroom_teacher_page.dart`
  (`ClassroomTeacherPage` + `ClassroomControlPage`). Laptop/web control panel:
  Start Class (class/subject/topic), slide prev/next, add slides, add
  resources, **Release/Hide** each resource, Go live / End class, "Open
  projector display".
- **TV Display** — `features/classroom/classroom_display_page.dart`. Full-bleed
  current slide only, no controls. Teacher opens it from the control panel and
  drags that window/tab onto the HDMI screen. Follows the same live stream, so
  slides change automatically.
- **Student** — `features/classroom/student_classroom_page.dart`. Joins the
  live class for the student's own class; tabs: **Presentation** (synced
  slide), **My Notes** (private, stored on-device via SharedPreferences, never
  uploaded), **Resources** (only teacher-**released** items; after-class items
  appear once the lesson ends).

## Core mechanisms (implemented)
- **Live sync** — Supabase realtime `.stream()` (realtimeTolerant) on the
  session row (current_slide, status) and on resources (visibility). Teacher
  action → display + every student update live.
- **Controlled release** — each resource has a visibility state
  (`teacher_only` / `hidden` / `released` / `after_class`). Teacher taps
  **Release**; it appears on student phones instantly, independent of the
  current slide (section 4).
- **Preload-but-hide** — RLS lets students read every non-`teacher_only`
  resource row of their school's sessions (so files can be pre-cached), while
  the student UI only shows released ones. "Local existence must not expose
  content prematurely" is enforced in the UI exactly as the spec describes
  (section 5). `teacher_only` rows are blocked at the database (RLS).
- **Separate layers** — presentation (slide_urls + current_slide) and
  resources are independent tables/streams, so the teacher releases a document
  without touching the slide (section 3).
- **Offline continuity** — the lesson is content + a tiny bit of live state;
  once slides/resources are cached, viewing works offline. State re-syncs when
  the connection returns (realtimeTolerant never blanks the lesson).

## Backend
`supabase/migrations/20261014140000_academia_classroom.sql` — `classroom_sessions`
+ `classroom_resources` with the visibility model and RLS. **Apply via
`supabase db push`** before it works live (no Supabase login in the build sandbox).

## File upload (implemented)
`services/classroom_upload_service.dart` uploads to the shared `app-content`
Supabase Storage bucket (uploadBinary → works on web, the teacher's laptop)
under `classroom/<schoolId>/`. In the teacher control panel:
- **Upload slide images** (multi-select, sorted by name) → becomes the synced
  slide deck. Export slides from PowerPoint as PNG/JPG, pick them, done.
- **Attach PowerPoint / PDF** → stored as the lesson's `original_file` for
  download.
- **Resources → Upload file** → any file uploaded, `kind` inferred from the
  extension, title auto-filled.

## Deliberately FUTURE (per spec section 12 + sandbox limits)
- **Automatic .pptx/PDF → slide images rendering.** Today the teacher uploads
  slide *images* (fully self-serve, no server) and can attach the raw .pptx/PDF
  for download. Auto-rendering a raw deck into slide images needs a server-side
  step (LibreOffice/unoconv in a Supabase Edge Function or cloud function) —
  the model already carries `original_file` to feed it.
- **LAN/hotspot P2P sync** (teacher laptop as local host) — the spec marks this
  "where technically practical / eventually". Current sync is cloud realtime;
  offline = cached content. P2P is a later transport swap behind the same repo.
- Annotations/highlight, polls, raise-hand, live questions, recording, AI
  summaries — all listed as future; the session/resource architecture is built
  to add them without a redesign.
