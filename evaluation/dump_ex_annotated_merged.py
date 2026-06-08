#!/usr/bin/env python3
"""Annotate a merged_analysis-style JSON with per-row EX (execution accuracy) outcomes.

Uses the same result comparison as evaluation_ex.py (set equality of query results).
Distinguishes prediction execution errors, gold execution errors, timeouts, and
result mismatches when prediction runs successfully.

Run from the ``evaluation/`` directory (same as evaluation_ex.py):

  python dump_ex_annotated_merged.py \\
    --merged-json ../mini_dev_data/merged_analysis_gpt52_improved_v1.json \\
    --db-root ../mini_dev_data/dev_databases/ \\
    -o ../mini_dev_data/merged_analysis_gpt52_improved_v1_ex_annotated.json \\
    --num-cpus 8

Optional: ``--limit 50`` for a quick smoke test.
"""
from __future__ import annotations

import argparse
import json
import multiprocessing as mp
import os
from typing import Any

from func_timeout import FunctionTimedOut, func_timeout

from evaluation_utils import connect_db


def _run_ex_detail(
    predicted_sql: str,
    ground_truth: str,
    db_path: str,
    sql_dialect: str,
) -> tuple[int, str | None, str | None]:
    """Returns (ex_pass_as_int, failure_kind, error_detail)."""
    conn = connect_db(sql_dialect, db_path)
    cursor = conn.cursor()
    try:
        try:
            cursor.execute(predicted_sql)
            predicted_res = cursor.fetchall()
        except Exception as e:
            return 0, "pred_error", str(e)
        try:
            cursor.execute(ground_truth)
            ground_truth_res = cursor.fetchall()
        except Exception as e:
            return 0, "gold_error", str(e)
    finally:
        conn.close()

    if set(predicted_res) == set(ground_truth_res):
        return 1, None, None
    return 0, "result_mismatch", None


def _worker(payload: tuple[int, dict[str, Any], str, float, str]) -> dict[str, Any]:
    idx, row, db_root, timeout, sql_dialect = payload
    db_id = row["db_id"]
    db_path = os.path.join(db_root, db_id, f"{db_id}.sqlite")

    def _call() -> tuple[int, str | None, str | None]:
        return _run_ex_detail(
            row["predicted_sql"],
            row["gold_sql"],
            db_path,
            sql_dialect,
        )

    try:
        ex_int, failure_kind, detail = func_timeout(timeout, _call)
    except FunctionTimedOut:
        ex_int, failure_kind, detail = 0, "timeout", None
    except KeyboardInterrupt:
        raise
    except Exception as e:
        ex_int, failure_kind, detail = 0, "worker_error", str(e)

    sql_idx = row.get("sql_idx", idx)
    out = {
        "sql_idx": sql_idx,
        "question_id": row["question_id"],
        "db_id": row["db_id"],
        "difficulty": row["difficulty"],
        "question": row["question"],
        "evidence": row.get("evidence", ""),
        "gold_sql": row["gold_sql"],
        "predicted_sql": row["predicted_sql"],
        "ex_pass": bool(ex_int),
        "failure_kind": failure_kind,
        "error_detail": detail,
    }
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument(
        "--merged-json",
        required=True,
        help="merged_analysis*.json (array of rows with gold_sql, predicted_sql, db_id, ...)",
    )
    ap.add_argument(
        "--db-root",
        required=True,
        help="dev_databases root (contains <db_id>/<db_id>.sqlite)",
    )
    ap.add_argument(
        "-o",
        "--output",
        required=True,
        help="Output JSON path",
    )
    ap.add_argument("--num-cpus", type=int, default=4)
    ap.add_argument("--meta-time-out", type=float, default=30.0)
    ap.add_argument("--sql-dialect", default="SQLite")
    ap.add_argument(
        "--limit",
        type=int,
        default=0,
        help="If > 0, only process the first N rows (smoke test)",
    )
    args = ap.parse_args()

    db_root = os.path.abspath(args.db_root)
    merged_path = os.path.abspath(args.merged_json)

    with open(merged_path, "r", encoding="utf-8") as f:
        rows: list[dict[str, Any]] = json.load(f)

    if args.limit and args.limit > 0:
        rows = rows[: args.limit]

    payloads = [
        (i, rows[i], db_root, args.meta_time_out, args.sql_dialect)
        for i in range(len(rows))
    ]

    if args.num_cpus <= 1:
        results = [_worker(p) for p in payloads]
    else:
        ctx = mp.get_context("spawn")
        with ctx.Pool(processes=args.num_cpus) as pool:
            results = pool.map(_worker, payloads)

    results.sort(key=lambda r: r["sql_idx"])
    passed = sum(1 for r in results if r["ex_pass"])
    n = len(results)
    acc_pct = (passed / n * 100.0) if n else 0.0

    fail_by_kind: dict[str, int] = {}
    for r in results:
        if r["ex_pass"]:
            continue
        fk = r["failure_kind"] or "unknown"
        fail_by_kind[fk] = fail_by_kind.get(fk, 0) + 1

    out_doc = {
        "meta": {
            "merged_json": merged_path,
            "db_root": db_root,
            "num_rows": n,
            "ex_pass_count": passed,
            "ex_accuracy_pct": round(acc_pct, 4),
            "num_cpus": max(1, args.num_cpus),
            "meta_time_out": args.meta_time_out,
            "sql_dialect": args.sql_dialect,
            "failure_kind_counts": dict(
                sorted(fail_by_kind.items(), key=lambda kv: (-kv[1], kv[0]))
            ),
        },
        "results": results,
    }

    out_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_doc, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Wrote {n} rows -> {out_path}")
    print(f"EX accuracy: {acc_pct:.2f}% ({passed}/{n})")
    print("failure_kind_counts (failures only):", out_doc["meta"]["failure_kind_counts"])


if __name__ == "__main__":
    # Required for spawn on macOS / Windows
    mp.freeze_support()
    main()
