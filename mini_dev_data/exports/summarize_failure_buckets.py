#!/usr/bin/env python3
"""Summarize failure categories by difficulty for V4 Step 2/3."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))

from failure_categorizer import categorize_failure_extended  # noqa: E402

JOIN_CATS = {
    "missing_join",
    "extra_join",
    "wrong_join_condition",
    "missing_table",
    "extra_table",
    "wrong_columns_selected",
}
PROJECTION_CATS = {
    "extra_select_columns",
    "extra_aggregate_in_select",
    "missing_select_columns",
    "extra_concat",
    "missing_distinct",
    "extra_distinct",
    "wrong_aggregation_in_select",
}
EVIDENCE_CATS = {
    "wrong_where_condition",
    "missing_where_clause",
    "extra_where_clause",
    "missing_substr_date_extraction",
    "wrong_substr_usage",
}


def manual_bucket(category: str) -> str:
    if category in JOIN_CATS or "join" in category or "table" in category:
        return "join_table_path"
    if category in PROJECTION_CATS or "select" in category or "concat" in category:
        return "projection_shape"
    if category in EVIDENCE_CATS or "where" in category or "substr" in category:
        return "evidence_date"
    if category in ("unknown_logical_error", "wrong_aggregation_function", "wrong_group_by_columns"):
        return "logic_grain"
    if category in ("pred_error", "timeout", "gold_error", "worker_error"):
        return "execution"
    return "other"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--annotated-json", type=Path, required=True)
    ap.add_argument("-o", "--output", type=Path, default=None)
    args = ap.parse_args()

    with open(args.annotated_json, encoding="utf-8") as f:
        doc = json.load(f)

    fails = [r for r in doc["results"] if not r.get("ex_pass")]
    by_diff_cat: dict[str, Counter] = defaultdict(Counter)
    by_diff_bucket: dict[str, Counter] = defaultdict(Counter)

    for r in fails:
        diff = r["difficulty"]
        if r.get("failure_kind") == "result_mismatch":
            cat, _ = categorize_failure_extended(
                r.get("predicted_sql", ""), r.get("gold_sql", "")
            )
        else:
            cat = r.get("failure_kind") or "failure"
        by_diff_cat[diff][cat] += 1
        by_diff_bucket[diff][manual_bucket(cat)] += 1

    summary = {
        "total_failures": len(fails),
        "by_difficulty_category": {d: dict(c.most_common()) for d, c in by_diff_cat.items()},
        "by_difficulty_bucket": {d: dict(c.most_common()) for d, c in by_diff_bucket.items()},
    }

    # Recommend track from moderate+challenging buckets
    mc = Counter()
    for d in ("moderate", "challenging"):
        mc.update(by_diff_bucket.get(d, {}))
    top_bucket = mc.most_common(1)[0][0] if mc else "other"
    track_map = {
        "join_table_path": "v4_hybrid_ra",
        "projection_shape": "v3_1_projection",
        "evidence_date": "v3_1_evidence",
        "logic_grain": "v4_hybrid_ra",
    }
    summary["recommended_track"] = track_map.get(top_bucket, "v4_hybrid_ra")
    summary["recommended_track_reason"] = (
        f"Dominant moderate+challenging bucket: {top_bucket} ({mc[top_bucket]} of {sum(mc.values())})"
    )

    text = json.dumps(summary, indent=2)
    print(text)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
        print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
