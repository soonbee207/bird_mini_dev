#!/usr/bin/env python3
"""Build merged_analysis-style JSON from mini_dev metadata + a predict JSON file.

Uses the same ``\\t----- bird -----\\t`` split as ``evaluation/evaluation_utils.package_sqls``,
so ``predicted_sql`` matches what EX evaluation executes.

Example (57% improved run):

  cd mini_dev_data/exports
  python3 build_merged_analysis_from_predict.py \\
    --predict-json ../../llm/exp_result/gpt52_improved_v1/predict_mini_dev_openai__gpt-5-2_SQLite.json \\
    -o ../merged_analysis_gpt52_improved_v1.json
"""
from __future__ import annotations

import argparse
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.normpath(os.path.join(ROOT, ".."))
DEFAULT_META = os.path.join(DATA_DIR, "mini_dev_sqlite.json")
DEFAULT_PRED = os.path.normpath(
    os.path.join(
        DATA_DIR,
        "..",
        "llm",
        "exp_result",
        "gpt52_improved_v1",
        "predict_mini_dev_openai__gpt-5-2_SQLite.json",
    )
)
DEFAULT_OUT = os.path.join(DATA_DIR, "merged_analysis_gpt52_improved_v1.json")

SEP = "\t----- bird -----\t"


def split_predicted_sql(raw: str) -> str:
    if not isinstance(raw, str):
        return " "
    try:
        sql, _rest = raw.split(SEP, 1)
    except ValueError:
        sql = raw.strip()
    return sql.strip()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--meta-json", default=DEFAULT_META, help="mini_dev_sqlite.json path")
    p.add_argument(
        "--predict-json",
        default=DEFAULT_PRED,
        help="predict_mini_dev_openai__gpt-5-2_SQLite.json path",
    )
    p.add_argument("-o", "--output", default=DEFAULT_OUT, help="Output JSON path")
    args = p.parse_args()

    meta = json.load(open(args.meta_json, "r", encoding="utf-8"))
    pred_raw: dict[str, str] = json.load(
        open(args.predict_json, "r", encoding="utf-8")
    )

    merged: list[dict] = []
    for i, row in enumerate(meta):
        key = str(i)
        if key not in pred_raw:
            raise KeyError(f"predict JSON missing key {key!r}")
        db_id = row["db_id"]
        p_sql = split_predicted_sql(pred_raw[key])
        merged.append(
            {
                "question_id": row["question_id"],
                "db_id": db_id,
                "difficulty": row["difficulty"],
                "question": row["question"],
                "evidence": row.get("evidence", ""),
                "gold_sql": row["SQL"].strip(),
                "predicted_sql": p_sql,
            }
        )

    out_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("Wrote", len(merged), "rows ->", out_path)


if __name__ == "__main__":
    main()
