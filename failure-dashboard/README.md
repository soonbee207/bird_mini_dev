# Failure dashboard (Vercel static)

Instant-load static dashboard — no Python server. Same UI as the HTML export from `build_failure_dashboard_html.py`.

## View locally (fastest)

```bash
# From this folder
python3 -m http.server 8080
# Open http://localhost:8080/failures.html
```

Or open `failures.html` directly in the browser (double-click).

## Sync after regenerating dashboards

```bash
cd mini_dev_data/exports
python3 build_failure_dashboard_html.py --both --vercel-sync
```

## Deploy to Vercel (shareable URLs)

**You must log in once** (browser opens). From your terminal:

```bash
cd failure-dashboard
chmod +x deploy.sh
./deploy.sh
```

Or manually:

```bash
cd failure-dashboard
npx vercel login
npx vercel --prod
```

The CLI prints your production URL, e.g. `https://mini-dev-failure-dashboard-xxx.vercel.app`.

| Share this | Page |
|------------|------|
| `https://YOUR-URL.vercel.app/failures.html` | Failures only (~175) |
| `https://YOUR-URL.vercel.app/all.html` | All 500 |
| `https://YOUR-URL.vercel.app/` | Same as failures (default) |

**Without CLI:** [vercel.com/new](https://vercel.com/new) → Import Git repo → set **Root Directory** to `failure-dashboard` → Deploy.

**Optional:** set `VERCEL_TOKEN` in the environment to deploy non-interactively (create at vercel.com/account/tokens).

## Pages

| URL | Content |
|-----|---------|
| `/` or `/failures.html` | ~175 failures (default) |
| `/all.html` or `/all` | All 500 questions |
