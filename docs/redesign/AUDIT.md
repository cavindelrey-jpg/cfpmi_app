# Desktop redesign — screenshot-verified audit (2026-10-15)

Reference target: `docs/redesign/TARGET_reference.png` (CFPMI 4-panel mockup).
Verification method: local `flutter build web` served on :8099, driven with
Playwright (guest flow), screenshots at 1440 / 390 widths. No claims of "done"
without a screenshot.

## Root cause of "looks like a mobile app stretched onto 16:9"
The signed-in `HomeShell` already had the correct desktop shell (left rail +
global top bar + per-page workspace). But **guests/landing** fell into a
separate `_GuestShell` that hardcoded a mobile `BottomAppBar` at every width.
Fixed: guests now use the same `HomeShell(user: AppUser.guest())`. (commit
f8d4e36)

Also fixed a stale `assets/logos/` entry in pubspec that was breaking every
web build (and the live deploy).

## Verified GOOD (render as real desktop workspaces)
- Shell: left rail (collapsed icons / expanded labels) + CFPMI top bar
  (logo + global search + notifications + account). ✓
- Home: two-column dashboard (featured banner, quick access, courses |
  progress ring, schedule, announcements). ✓
- Courses: heading + search/filters + education levels + recommended +
  recent reads + downloaded (two-column). ✓
- Library: File Explorer tree (left) + recommended/recent/offline (right). ✓

## Fixed this pass (embedded-in-shell pattern — drop duplicated top chrome)
- **Tests** (`quiz_categories_page`): cards were ~600px tall (fixed 2-col grid
  `childAspectRatio 0.92` on a wide workspace). Now responsive columns
  (2→5 by width) with a fixed 188px card height. Also dropped its own AppBar
  when embedded (slim in-body heading instead).
- **Profile**: was drawing a full second app bar (duplicate search/bell +
  Settings/Sign Out) under the global bar. Embedded → in-body header.
- **Magazine**: in-body header dropped duplicated search / notifications /
  avatar when embedded.
- **Groups**: AppBar actions (bell + avatar) dropped when embedded; keeps its
  page-specific title/search/category chips.

Pattern: each section page takes `embedded` (default false); the shell passes
`embedded: true`. Pushed detail routes keep their own AppBar + back button.

## Still to audit/redesign
- Lesson reader (reading column + Table-of-Contents/Resources panel) — needs
  course data to reach; verify structurally.
- School tools (Marks, Attendance, Fees, Timetable, School Connect,
  Classroom, Student Records) — check each for stretched-mobile + duplicate
  bars inside the School secondary-rail workspace.
- Default the desktop rail to expanded (labels) — reference shows labels.
- Signed-in verification with real data (needs a test login) to confirm
  populated states, not just guest empty states.
