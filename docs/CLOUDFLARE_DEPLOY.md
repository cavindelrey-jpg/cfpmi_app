# CFPMI — Cloudflare Pages production deployment

The web app is a Flutter web build (static files in `build/web`). Cloudflare
Pages hosts it and serves the custom domain. Builds happen in GitHub Actions
(where Flutter is available) and the output is pushed to Cloudflare Pages on
every push to `main` — so the agent's future pushes publish automatically.

## Build settings (framework-specific)
- Framework preset: **None** (Flutter is not a Cloudflare preset).
- Build output directory: **`build/web`**
- Build command (only if you use Cloudflare's own Git build instead of the
  GitHub Action below):
  `git clone https://github.com/flutter/flutter.git --depth 1 -b stable _f && _f/bin/flutter build web --release --dart-define=BRAND_ID=cfpmi`
- SPA routing: `web/_redirects` ships `/* /index.html 200`, so deep links,
  browser refreshes and bookmarks resolve instead of 404ing. Policy pages
  (`/privacy.html`, `/delete-account.html`) are matched first and stay public.

## Recommended: deploy from GitHub Actions (already wired)
`.github/workflows/build.yml` builds the web app and runs a
**Deploy to Cloudflare Pages** step. Three one-time steps by the account owner:

1. **Create the Pages project** (Cloudflare dashboard → Workers & Pages →
   Create → Pages → *Direct Upload*). Name it exactly **`cfpmi`**.
2. **Add two GitHub repo secrets** (GitHub → repo → Settings → Secrets and
   variables → Actions):
   - `CLOUDFLARE_API_TOKEN` — a token with the *Cloudflare Pages: Edit*
     permission.
   - `CLOUDFLARE_ACCOUNT_ID` — from the Cloudflare dashboard URL / overview.
   Once these exist, every push to `main` publishes automatically.
3. **Custom domain**: once `cfpmischools.com` registration is complete,
   Cloudflare dashboard → the `cfpmi` Pages project → *Custom domains* → add
   `cfpmischools.com` (and `www.cfpmischools.com`). Cloudflare issues the TLS
   cert and routes the domain to the latest deployment.

## Verify
- The GitHub Action's "Deploy to Cloudflare Pages" step must show success
  (it is `continue-on-error` only so the pipeline is green before the secrets
  exist — check the step log for the deployment URL once set up).
- Open the Pages `*.pages.dev` preview URL, then the custom domain once added.
- Confirm `/privacy.html` and `/delete-account.html` load without signing in.

## Note on per-section URLs
Public policy pages already have their own real static URLs. The in-app
sections (courses, marks entry, etc.) are navigated inside the single-page
Flutter shell; giving each its own path (e.g. `/courses`) is a routing
refactor (go_router) tracked separately — the `_redirects` SPA fallback
already keeps refresh/bookmarks working on whatever the app shows.
