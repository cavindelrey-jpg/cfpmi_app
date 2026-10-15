# CFPMI — Security Review (2026-10-15)

Prompted by the "vibe-coding security" checklist. Focus: the real attack the
notes describe — "change the ID in the URL / hit the API directly and read
another user's data." For a Supabase app the anon key IS in the frontend by
design, so **Row-Level Security (RLS) is the wall**, not UI filtering.

## Method
Static audit of all `supabase/migrations/*.sql` (80 tables): which tables
enable RLS, and which have wide-open `using (true)` policies. Plus a secret
scan of all tracked files.

## Results — the critical items are SECURE

| Check (from the notes) | Result |
|---|---|
| Server-side authz on every record (not just filtered lists) | ✅ **79/79 real tables have RLS enabled.** |
| Sensitive PII tables not wide-open | ✅ `users`, `school_marks`, `messages`, `conversations`, `attendance_records`, `fee_ledger`, `school_students`, `examinations`, `exam_results` are **not** `using(true)` — each has ownership/role-scoped policies (student sees own; school staff see their school; super_admin all). |
| APIs require auth | ✅ PostgREST enforces the same RLS; a `curl` with the anon key only returns what the policies allow. |
| No secrets / DB URLs in frontend | ✅ Only the Supabase **anon** key + Firebase **client** config are committed — public by design. No `service_role` key, DB password, or private key is tracked (`migration/.env` is gitignored). |
| New CFPMI tables (attendance/fees/classroom) | ✅ Written with restrictive RLS: student reads own; staff of the school read/write; super_admin all; classroom `teacher_only` resources blocked from students at the DB. |

## One finding — MEDIUM: cross-tenant read-all on shared "content" tables
24 tables have `for select using (true)` (any authenticated user — or anyone
with the anon key — can read all rows across all schools):

- **Benign / intended public content:** `hero_slides`, `home_hero`,
  `course_category_visuals`, `curriculum_icons`, `academic_sections`,
  `institutions`, `serials` (display/catalog data).
- **Social/engagement:** `article_comments/likes/shares`,
  `course_comments/ratings/likes`.
- **Clubs (the real concern):** `club_posts`, `club_post_comments/likes`,
  `club_discussions` (+ likes/replies), `club_resources`, `club_events`,
  `club_event_rsvps`.

The club/discussion tables being `using(true)` means **tenant isolation for
club content is enforced only client-side** (the repository filters by school),
not by the API — exactly the pattern the notes warn about. This does **not**
expose marks, messages, attendance, or fees (those are properly scoped); it
means club posts/discussions are readable across schools via the raw API.

### Why this review does NOT change it here
These policies live in the **shared** Supabase project `ccumxxysaaphhgdzlagk`,
which also backs **Ladybird, Academia, and Green Hills** in production. Tightening
them is a coordinated backend change that must be tested against all those apps,
and this engagement is scoped to the **CFPMI repo only**. Changing shared prod
RLS unilaterally could break the other apps.

### Recommended fix (for a coordinated backend pass)
Replace `using (true)` on the club/discussion/resource/event tables with a
tenant-scoped predicate, e.g. the club's `school_id` must match the caller's
school (`coalesce(institution_id::text, id::text)` from `public.users`), mirroring
the pattern already used by `school_students`, `attendance_records`, `fee_ledger`,
and `classroom_*`. Keep genuinely public catalog tables (`hero_slides`,
`institutions`, etc.) as public read.

## Design-slop check (notes Part 2) — clean
CFPMI avoids the common AI tells: palette is navy/green/gold (no purple
gradients), Material icons (no emoji-as-icons), no chasing buttons / scroll
hijack / content-hiding fade-ins; good contrast; consistent visual language;
standard navigation. Privacy/deletion pages use semantic HTML with a clear H1.

## Workflow (notes Part 3) — followed
Flutter/Dart (popular, well-documented stack); small incremental commits to Git
with clear messages; tests added for new critical logic (attendance/fees math);
CI runs test→build before deploy.
