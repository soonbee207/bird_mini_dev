"""Shared logic for failure review dashboards (HTML + Streamlit)."""

from __future__ import annotations

import json
import os
import sqlite3
from collections import Counter
from pathlib import Path

try:
    from func_timeout import FunctionTimedOut, func_timeout
except ImportError:
    func_timeout = None
    FunctionTimedOut = Exception

from failure_categorizer import categorize_failure_extended

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_ANNOTATED = REPO_ROOT / "mini_dev_data/merged_analysis_v3_8steps_ex_annotated.json"
DEFAULT_DB_ROOT = REPO_ROOT / "mini_dev_data/dev_databases"


def load_annotated(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


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


def build_items(
    annotated: dict,
    db_root: str,
    run_sql: bool = False,
    preview_limit: int = 5,
) -> list[dict]:
    return [
        enrich_row(r, db_root, run_sql, preview_limit)
        for r in annotated["results"]
    ]


def summarize_items(items: list[dict]) -> dict:
    fails = [i for i in items if not i["ex_pass"]]
    return {
        "total": len(items),
        "pass_count": sum(1 for i in items if i["ex_pass"]),
        "fail_count": len(fails),
        "by_category": dict(
            Counter(i["auto_category"] for i in fails).most_common()
        ),
        "by_difficulty": dict(Counter(i["difficulty"] for i in items)),
    }
