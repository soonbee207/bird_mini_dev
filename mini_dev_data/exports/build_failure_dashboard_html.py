#!/usr/bin/env python3
"""Build a self-contained HTML dashboard from EX-annotated merged analysis JSON."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from collections import Counter
from pathlib import Path

try:
    from func_timeout import FunctionTimedOut, func_timeout
except ImportError:
    func_timeout = None
    FunctionTimedOut = Exception

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
sys.path.insert(0, str(REPO_ROOT / "mini_dev_data"))

from failure_categorizer import categorize_failure_extended  # noqa: E402

DEFAULT_ANNOTATED = REPO_ROOT / "mini_dev_data/merged_analysis_v3_8steps_ex_annotated.json"
DEFAULT_DB_ROOT = REPO_ROOT / "mini_dev_data/dev_databases"
DEFAULT_OUT_FAILURES = REPO_ROOT / "mini_dev_data/reports/failure_dashboard_v3_failures.html"
DEFAULT_OUT_ALL = REPO_ROOT / "mini_dev_data/reports/failure_dashboard_v3_all.html"
VERCEL_DIR = REPO_ROOT / "failure-dashboard"


def _execute_preview_inner(db_path: str, sql: str, limit: int) -> dict:
    out: dict = {
        "ok": False,
        "error": None,
        "truncated": False,
        "columns": [],
        "rows": [],
    }
    conn = sqlite3.connect(db_path, timeout=5.0)
    conn.execute("PRAGMA busy_timeout = 5000")
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchmany(limit + 1)
    out["columns"] = [d[0] for d in cur.description] if cur.description else []
    out["rows"] = [list(r) for r in rows[:limit]]
    out["truncated"] = len(rows) > limit
    out["ok"] = True
    conn.close()
    return out


def execute_preview(
    db_path: str, sql: str, limit: int = 5, timeout_sec: float = 5.0
) -> dict:
    try:
        if func_timeout is not None:
            return func_timeout(
                timeout_sec, _execute_preview_inner, args=(db_path, sql, limit)
            )
        return _execute_preview_inner(db_path, sql, limit)
    except FunctionTimedOut:
        return {
            "ok": False,
            "error": f"query timed out after {timeout_sec}s",
            "truncated": False,
            "columns": [],
            "rows": [],
        }
    except Exception as e:
        return {
            "ok": False,
            "error": str(e),
            "truncated": False,
            "columns": [],
            "rows": [],
        }


def enrich_row(
    row: dict, db_root: str, run_sql: bool, preview_limit: int
) -> dict:
    pred = row.get("predicted_sql") or ""
    gold = row.get("gold_sql") or ""
    category, reason = ("—", "—")
    if not row.get("ex_pass"):
        if row.get("failure_kind") == "result_mismatch":
            category, reason = categorize_failure_extended(pred, gold)
        else:
            category = row.get("failure_kind") or "failure"
            reason = row.get("error_detail") or ""

    item = {
        "sql_idx": row["sql_idx"],
        "question_id": row["question_id"],
        "db_id": row["db_id"],
        "difficulty": row["difficulty"],
        "ex_pass": row["ex_pass"],
        "failure_kind": row.get("failure_kind"),
        "error_detail": row.get("error_detail"),
        "question": row.get("question", ""),
        "evidence": row.get("evidence", ""),
        "gold_sql": gold,
        "predicted_sql": pred,
        "auto_category": category,
        "category_reason": reason,
        "gold_preview": None,
        "pred_preview": None,
    }

    if run_sql and not row.get("ex_pass"):
        db_path = os.path.join(db_root, row["db_id"], f"{row['db_id']}.sqlite")
        if os.path.isfile(db_path):
            item["gold_preview"] = execute_preview(db_path, gold, preview_limit)
            item["pred_preview"] = execute_preview(db_path, pred, preview_limit)

    return item


def build_dataset(
    annotated: dict,
    db_root: str,
    failures_only: bool,
    run_sql: bool,
    preview_limit: int,
) -> dict:
    rows = annotated["results"]
    if failures_only:
        rows = [r for r in rows if not r.get("ex_pass")]

    items = [enrich_row(r, db_root, run_sql, preview_limit) for r in rows]

    fail_items = [i for i in items if not i["ex_pass"]]
    cat_counts = Counter(i["auto_category"] for i in fail_items)
    diff_counts = Counter(i["difficulty"] for i in items)

    return {
        "meta": {
            "source": annotated.get("meta", {}),
            "failures_only": failures_only,
            "run_sql": run_sql,
            "item_count": len(items),
        },
        "summary": {
            "by_category": dict(cat_counts.most_common()),
            "by_difficulty": dict(diff_counts),
        },
        "items": items,
    }


def sync_to_vercel(failures_html: Path, all_html: Path) -> None:
    import shutil

    VERCEL_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(failures_html, VERCEL_DIR / "failures.html")
    shutil.copy2(all_html, VERCEL_DIR / "all.html")
    print(f"Synced Vercel static files -> {VERCEL_DIR}/")


HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Mini-Dev SQL failure review</title>
  <style>
    :root {
      --bg: #0f1419; --panel: #1a2332; --border: #2d3a4d;
      --text: #e7ecf3; --muted: #8b9cb3; --accent: #5b9fd4;
      --fail: #c75050; --gold: #d4a85b; --pred: #7eb8da;
    }
    * { box-sizing: border-box; }
    body { font-family: ui-sans-serif, system-ui, sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 1rem 1.5rem 3rem; line-height: 1.45; }
    h1 { font-size: 1.35rem; margin: 0 0 0.25rem; }
    .sub { color: var(--muted); font-size: 0.9rem; margin-bottom: 1rem; }
    .toolbar { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: center; background: var(--panel); border: 1px solid var(--border); padding: 1rem; border-radius: 8px; margin-bottom: 1rem; }
    .toolbar label { font-size: 0.85rem; color: var(--muted); display: flex; flex-direction: column; gap: 0.25rem; }
    .toolbar select, .toolbar input { background: var(--bg); color: var(--text); border: 1px solid var(--border); padding: 0.35rem 0.5rem; border-radius: 4px; min-width: 8rem; }
    #search { min-width: 14rem; }
    .stats { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem; font-size: 0.85rem; }
    .pill { background: var(--panel); border: 1px solid var(--border); padding: 0.25rem 0.6rem; border-radius: 999px; }
    .card { background: var(--panel); border: 1px solid var(--border); border-radius: 8px; margin-bottom: 1.25rem; overflow: hidden; }
    .card-header { padding: 0.75rem 1rem; border-bottom: 1px solid var(--border); display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; }
    .badge { font-size: 0.75rem; padding: 0.15rem 0.5rem; border-radius: 4px; font-weight: 600; }
    .badge.fail { background: #3a2222; color: #f0a0a0; }
    .badge.pass { background: #223a28; color: #90d8b0; }
    .badge.cat { background: #2a3548; color: var(--accent); }
    .badge.diff-moderate { background: #2e3520; color: #c8d878; }
    .badge.diff-challenging { background: #352028; color: #e8a0b8; }
    .badge.diff-simple { background: #203028; color: #90d8b0; }
    .card-body { padding: 1rem; }
    .q { margin: 0 0 0.5rem; }
    .evidence { color: var(--muted); font-size: 0.88rem; margin-bottom: 0.75rem; white-space: pre-wrap; }
    .reason { font-size: 0.88rem; color: var(--muted); margin-bottom: 0.75rem; }
    .sql-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
    @media (max-width: 900px) { .sql-grid { grid-template-columns: 1fr; } }
    .sql-block h3 { font-size: 0.8rem; margin: 0 0 0.35rem; text-transform: uppercase; letter-spacing: 0.04em; }
    .sql-block.gold h3 { color: var(--gold); }
    .sql-block.pred h3 { color: var(--pred); }
    pre.sql { margin: 0; padding: 0.75rem; background: var(--bg); border: 1px solid var(--border); border-radius: 6px; overflow-x: auto; font-size: 0.8rem; white-space: pre-wrap; word-break: break-word; }
    .preview-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; margin-top: 0.75rem; }
    @media (max-width: 900px) { .preview-grid { grid-template-columns: 1fr; } }
    table.preview { width: 100%; border-collapse: collapse; font-size: 0.75rem; }
    table.preview th, table.preview td { border: 1px solid var(--border); padding: 0.25rem 0.4rem; text-align: left; }
    table.preview th { background: var(--bg); }
    .err { color: var(--fail); font-size: 0.85rem; }
    #empty { display: none; text-align: center; color: var(--muted); padding: 2rem; }
  </style>
</head>
<body>
  <h1>Mini-Dev SQL failure review</h1>
  <p class="sub" id="subtitle"></p>

  <div class="toolbar">
    <label>Difficulty
      <select id="f-difficulty"><option value="">All</option></select>
    </label>
    <label>Category
      <select id="f-category"><option value="">All</option></select>
    </label>
    <label>Failure kind
      <select id="f-failure"><option value="">All</option></select>
    </label>
    <label>Database
      <select id="f-db"><option value="">All</option></select>
    </label>
    <label>Search
      <input id="search" type="search" placeholder="question, id, sql…" />
    </label>
    <label style="flex-direction:row;align-items:center;margin-top:1.1rem;gap:0.35rem;">
      <input type="checkbox" id="f-passed" /> Include passes
    </label>
  </div>

  <div class="stats" id="stats"></div>
  <div id="empty">No rows match filters.</div>
  <div id="cards"></div>

  <script>
    const DATA = __DATA_JSON__;

    const items = DATA.items;
    const failuresOnlyDefault = __FAILURES_ONLY_DEFAULT__;
    document.getElementById('subtitle').textContent =
      `${items.length} rows · failures_only=${DATA.meta.failures_only} · sql_preview=${DATA.meta.run_sql}`;

    function uniq(vals) {
      return [...new Set(vals.filter(Boolean))].sort();
    }

    function fillSelect(id, values) {
      const sel = document.getElementById(id);
      values.forEach(v => {
        const o = document.createElement('option');
        o.value = v; o.textContent = v;
        sel.appendChild(o);
      });
    }

    fillSelect('f-difficulty', uniq(items.map(i => i.difficulty)));
    fillSelect('f-category', uniq(items.map(i => i.auto_category)));
    fillSelect('f-failure', uniq(items.map(i => i.failure_kind)));
    fillSelect('f-db', uniq(items.map(i => i.db_id)));

    document.getElementById('f-passed').checked = !failuresOnlyDefault;

    function esc(s) {
      const d = document.createElement('div');
      d.textContent = s == null ? '' : String(s);
      return d.innerHTML;
    }

    function renderPreview(label, p) {
      if (!p) return '';
      if (!p.ok) return `<div class="err">${label}: ${esc(p.error)}</div>`;
      const head = (p.columns || []).map(c => `<th>${esc(c)}</th>`).join('');
      const body = (p.rows || []).map(r =>
        `<tr>${r.map(c => `<td>${esc(c)}</td>`).join('')}</tr>`
      ).join('');
      const note = p.truncated ? ' (more rows exist)' : '';
      return `<h4>${label}${note}</h4><table class="preview"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
    }

    function renderCard(it) {
      const diffClass = 'diff-' + (it.difficulty || 'simple');
      return `
        <article class="card" data-idx="${it.sql_idx}">
          <div class="card-header">
            <strong>#${it.sql_idx}</strong>
            <span>Q${it.question_id}</span>
            <span class="badge ${diffClass}">${esc(it.difficulty)}</span>
            <span class="badge ${it.ex_pass ? 'pass' : 'fail'}">${it.ex_pass ? 'PASS' : 'FAIL'}</span>
            <span class="badge cat">${esc(it.auto_category)}</span>
            <span>${esc(it.db_id)}</span>
            ${it.failure_kind ? `<span class="badge fail">${esc(it.failure_kind)}</span>` : ''}
          </div>
          <div class="card-body">
            <p class="q">${esc(it.question)}</p>
            ${it.evidence ? `<div class="evidence"><strong>Evidence:</strong> ${esc(it.evidence)}</div>` : ''}
            <div class="reason"><strong>Category reason:</strong> ${esc(it.category_reason)}</div>
            <div class="sql-grid">
              <div class="sql-block gold"><h3>Gold SQL</h3><pre class="sql">${esc(it.gold_sql)}</pre></div>
              <div class="sql-block pred"><h3>Predicted SQL</h3><pre class="sql">${esc(it.predicted_sql)}</pre></div>
            </div>
            ${it.gold_preview || it.pred_preview ? `
              <div class="preview-grid">
                <div>${renderPreview('Gold result', it.gold_preview)}</div>
                <div>${renderPreview('Predicted result', it.pred_preview)}</div>
              </div>` : ''}
          </div>
        </article>`;
    }

    function applyFilters() {
      const diff = document.getElementById('f-difficulty').value;
      const cat = document.getElementById('f-category').value;
      const fk = document.getElementById('f-failure').value;
      const db = document.getElementById('f-db').value;
      const q = document.getElementById('search').value.toLowerCase();
      const showPass = document.getElementById('f-passed').checked;

      const filtered = items.filter(it => {
        if (!showPass && it.ex_pass) return false;
        if (diff && it.difficulty !== diff) return false;
        if (cat && it.auto_category !== cat) return false;
        if (fk && it.failure_kind !== fk) return false;
        if (db && it.db_id !== db) return false;
        if (q) {
          const blob = [it.question, it.evidence, it.gold_sql, it.predicted_sql,
            String(it.question_id), String(it.sql_idx), it.auto_category].join(' ').toLowerCase();
          if (!blob.includes(q)) return false;
        }
        return true;
      });

      const stats = document.getElementById('stats');
      const cats = {};
      filtered.forEach(i => { if (!i.ex_pass) cats[i.auto_category] = (cats[i.auto_category]||0)+1; });
      stats.innerHTML = `<span class="pill">Showing ${filtered.length}</span>` +
        Object.entries(cats).sort((a,b)=>b[1]-a[1]).slice(0,10)
          .map(([k,v]) => `<span class="pill">${esc(k)}: ${v}</span>`).join('');

      document.getElementById('empty').style.display = filtered.length ? 'none' : 'block';
      document.getElementById('cards').innerHTML = filtered.map(renderCard).join('');
    }

    ['f-difficulty','f-category','f-failure','f-db','search','f-passed'].forEach(id => {
      const el = document.getElementById(id);
      el.addEventListener('input', applyFilters);
      el.addEventListener('change', applyFilters);
    });
    applyFilters();
  </script>
</body>
</html>
"""


def write_html(dataset: dict, output: Path, failures_only_default: bool) -> None:
    data_json = json.dumps(dataset, ensure_ascii=False)
    html_out = (
        HTML_TEMPLATE.replace("__DATA_JSON__", data_json).replace(
            "__FAILURES_ONLY_DEFAULT__", "true" if failures_only_default else "false"
        )
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html_out, encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--annotated-json", type=Path, default=DEFAULT_ANNOTATED)
    ap.add_argument("--db-root", type=Path, default=DEFAULT_DB_ROOT)
    ap.add_argument("-o", "--output", type=Path, default=None)
    ap.add_argument("--include-passes", action="store_true")
    ap.add_argument("--no-sql-preview", action="store_true")
    ap.add_argument("--preview-limit", type=int, default=5)
    ap.add_argument(
        "--both",
        action="store_true",
        help="Write default failures + all HTML paths (ignores -o unless set for failures)",
    )
    ap.add_argument(
        "--vercel-sync",
        action="store_true",
        help="Copy failures/all HTML to failure-dashboard/ for Vercel deploy",
    )
    args = ap.parse_args()

    with open(args.annotated_json, encoding="utf-8") as f:
        annotated = json.load(f)

    failures_only = not args.include_passes

    dataset = build_dataset(
        annotated,
        str(args.db_root),
        failures_only=failures_only,
        run_sql=not args.no_sql_preview,
        preview_limit=args.preview_limit,
    )

    if args.both:
        name = args.annotated_json.stem.replace("_ex_annotated", "")
        if name.startswith("merged_analysis_"):
            prefix = "failure_dashboard_" + name[len("merged_analysis_") :]
        else:
            prefix = "failure_dashboard_" + name
        reports_dir = args.output.parent if args.output else DEFAULT_OUT_FAILURES.parent
        out_fail = reports_dir / f"{prefix}_failures.html"
        out_all = reports_dir / f"{prefix}_all.html"

        ds_fail = build_dataset(
            annotated,
            str(args.db_root),
            failures_only=True,
            run_sql=not args.no_sql_preview,
            preview_limit=args.preview_limit,
        )
        ds_all = build_dataset(
            annotated,
            str(args.db_root),
            failures_only=False,
            run_sql=False,
            preview_limit=args.preview_limit,
        )
        write_html(ds_fail, out_fail, True)
        write_html(ds_all, out_all, False)
        print(f"Wrote {out_fail} ({len(ds_fail['items'])} items)")
        print(f"Wrote {out_all} ({len(ds_all['items'])} items)")
        if args.vercel_sync:
            sync_to_vercel(out_fail, out_all)
        return

    out = args.output or (
        DEFAULT_OUT_ALL if args.include_passes else DEFAULT_OUT_FAILURES
    )
    write_html(dataset, out, failures_only)
    print(f"Wrote {out} ({len(dataset['items'])} items)")
    if args.vercel_sync and not args.include_passes:
        all_path = DEFAULT_OUT_ALL if DEFAULT_OUT_ALL.is_file() else out.parent / "failure_dashboard_v3_all.html"
        if all_path.is_file():
            sync_to_vercel(out, all_path)
        else:
            print("warning: --vercel-sync skipped all.html (run with --both first)")


if __name__ == "__main__":
    main()
