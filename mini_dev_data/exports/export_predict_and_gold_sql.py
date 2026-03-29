#!/usr/bin/env python3
"""Export gold SQL and predicted SQL as separate text files (same index order, 0..499).

  python export_predict_and_gold_sql.py

Outputs in this directory:
  - mini_dev_gold_sql_only.sql     — one gold query per block (header + SQL)
  - mini_dev_predicted_gpt52_sql_only.sql — GPT-5.2 prediction per block
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(ROOT, ".."))
META = os.path.join(REPO, "mini_dev_sqlite.json")
PRED = os.path.join(
    REPO,
    "..",
    "llm",
    "exp_result",
    "turbo_output_kg",
    "predict_mini_dev_openai__gpt-5-2_SQLite.json",
)
PRED = os.path.normpath(PRED)

SEP = "\t----- bird -----\t"


def main() -> None:
    meta = json.load(open(META, "r"))
    pred_raw = json.load(open(PRED, "r"))

    gold_path = os.path.join(ROOT, "mini_dev_gold_sql_only.sql")
    pr_path = os.path.join(ROOT, "mini_dev_predicted_gpt52_sql_only.sql")

    with open(gold_path, "w", encoding="utf-8") as gf, open(
        pr_path, "w", encoding="utf-8"
    ) as pf:
        for i in range(len(meta)):
            row = meta[i]
            db_id = row["db_id"]
            gold_sql = row["SQL"].strip()

            gf.write(f"-- [{i}] db_id={db_id}\n")
            gf.write(gold_sql + "\n\n")

            key = str(i)
            raw = pred_raw[key]
            if SEP in raw:
                p_sql, rest = raw.split(SEP, 1)
                p_db = rest.strip()
            else:
                p_sql, p_db = raw.strip(), db_id

            pf.write(f"-- [{i}] db_id={p_db}\n")
            pf.write(p_sql.strip() + "\n\n")

    print("Wrote:", gold_path)
    print("Wrote:", pr_path)


if __name__ == "__main__":
    main()
