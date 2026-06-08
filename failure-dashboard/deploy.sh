#!/usr/bin/env bash
# Deploy static failure dashboard to Vercel (interactive login on first run).
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f failures.html ]] || [[ ! -f all.html ]]; then
  echo "Missing failures.html or all.html. Run from repo root:"
  echo "  cd mini_dev_data/exports && python3 build_failure_dashboard_html.py --both --vercel-sync"
  exit 1
fi

echo "==> Vercel login (skip if already logged in)"
npx vercel login

echo "==> Deploying to production..."
npx vercel --prod

echo ""
echo "Share these paths on your deployment URL:"
echo "  /failures.html  — failure cases only (~175)"
echo "  /all.html       — all 500 questions"
