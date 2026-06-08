"""Heuristic failure categories for pred vs gold SQL (dashboard + V4 planning)."""

from __future__ import annotations

import re

from enhanced_error_analysis_script import (
    categorize_wrong_result_error,
    extract_aggregation_functions,
    extract_select_columns,
)

_AGG_IN_SELECT = re.compile(r"\b(sum|count|avg|min|max)\s*\(", re.I)


def _select_list(sql: str) -> list[str]:
    return extract_select_columns(sql)


def _agg_funcs_in_select(sql: str) -> set[str]:
    m = re.search(r"select\s+(.*?)\s+from", sql, re.I | re.S)
    if not m:
        return set()
    part = m.group(1)
    found = set()
    for func in ("sum", "count", "avg", "min", "max"):
        if re.search(rf"\b{func}\s*\(", part, re.I):
            found.add(func)
    return found


def categorize_failure_extended(pred_sql: str, gold_sql: str) -> tuple[str, str]:
    """Return (category, reason). Extended rules run before base categorizer."""
    pred = pred_sql or ""
    gold = gold_sql or ""
    pl, gl = pred.lower(), gold.lower()

    if "||" in pl and "||" not in gl:
        return ("extra_concat", "Predicted uses || concatenation; gold does not")

    pred_cols = _select_list(pred)
    gold_cols = _select_list(gold)
    if len(pred_cols) > len(gold_cols):
        pred_aggs = _agg_funcs_in_select(pred)
        gold_aggs = _agg_funcs_in_select(gold)
        extra_aggs = pred_aggs - gold_aggs
        if extra_aggs:
            return (
                "extra_aggregate_in_select",
                f"Predicted SELECT has extra aggregate(s): {sorted(extra_aggs)}",
            )
        return (
            "extra_select_columns",
            f"Predicted SELECT has {len(pred_cols)} columns vs gold {len(gold_cols)}",
        )

    if len(pred_cols) < len(gold_cols):
        return (
            "missing_select_columns",
            f"Predicted SELECT has {len(pred_cols)} columns vs gold {len(gold_cols)}",
        )

    pred_aggs_sel = _agg_funcs_in_select(pred)
    gold_aggs_sel = _agg_funcs_in_select(gold)
    if pred_aggs_sel != gold_aggs_sel:
        return (
            "wrong_aggregation_in_select",
            f"SELECT aggregates differ: pred {pred_aggs_sel} vs gold {gold_aggs_sel}",
        )

    return categorize_wrong_result_error(pred, gold)
