#!/usr/bin/env python3
"""Streamlit failure review dashboard for Mini-Dev EX annotated runs."""

from __future__ import annotations

import sys
from pathlib import Path

import streamlit as st

APP_DIR = Path(__file__).resolve().parent
MINI_DEV = APP_DIR.parent
sys.path.insert(0, str(MINI_DEV))

from dashboard.dashboard_data import (  # noqa: E402
    DEFAULT_ANNOTATED,
    DEFAULT_DB_ROOT,
    build_items,
    load_annotated,
    summarize_items,
)

st.set_page_config(
    page_title="Mini-Dev SQL failure review",
    page_icon="📊",
    layout="wide",
)


@st.cache_data(show_spinner="Loading and categorizing…")
def cached_items(
    annotated_path: str,
    db_root: str,
    run_sql: bool,
    preview_limit: int,
) -> list[dict]:
    annotated = load_annotated(Path(annotated_path))
    return build_items(annotated, db_root, run_sql=run_sql, preview_limit=preview_limit)


def render_preview_table(label: str, preview: dict | None) -> None:
    if preview is None:
        return
    if not preview.get("ok"):
        st.error(f"{label}: {preview.get('error', 'execution failed')}")
        return
    suffix = " (more rows exist)" if preview.get("truncated") else ""
    st.caption(f"{label}{suffix}")
    if preview.get("rows") and preview.get("columns"):
        records = [
            dict(zip(preview["columns"], row, strict=False))
            for row in preview["rows"]
        ]
        st.dataframe(records, use_container_width=True, hide_index=True)
    elif preview.get("ok"):
        st.caption("(empty result)")


def filter_items(
    items: list[dict],
    *,
    failures_only: bool,
    difficulty: str,
    category: str,
    failure_kind: str,
    db_id: str,
    search: str,
) -> list[dict]:
    q = search.strip().lower()
    out = []
    for it in items:
        if failures_only and it["ex_pass"]:
            continue
        if difficulty and it["difficulty"] != difficulty:
            continue
        if category and it["auto_category"] != category:
            continue
        if failure_kind and (it.get("failure_kind") or "") != failure_kind:
            continue
        if db_id and it["db_id"] != db_id:
            continue
        if q:
            blob = " ".join(
                [
                    str(it.get("question_id", "")),
                    str(it.get("sql_idx", "")),
                    it.get("question", ""),
                    it.get("evidence", ""),
                    it.get("gold_sql", ""),
                    it.get("predicted_sql", ""),
                    it.get("auto_category", ""),
                ]
            ).lower()
            if q not in blob:
                continue
        out.append(it)
    return out


def main() -> None:
    st.title("Mini-Dev SQL failure review")
    st.caption("Compare gold vs predicted SQL with heuristic failure categories.")

    with st.sidebar:
        st.header("Data")
        annotated_path = st.text_input(
            "Annotated JSON path",
            value=str(DEFAULT_ANNOTATED),
        )
        db_root = st.text_input("Database root", value=str(DEFAULT_DB_ROOT))
        db_available = Path(db_root).is_dir()
        run_sql = st.checkbox(
            "Run SQL previews (local DBs)",
            value=db_available,
            disabled=not db_available,
            help="Requires dev_databases on this machine.",
        )
        preview_limit = st.slider("Preview row limit", 3, 20, 5)

        if st.button("Clear cache"):
            st.cache_data.clear()
            st.rerun()

        st.divider()
        st.header("Filters")
        failures_only = st.checkbox("Failures only", value=True)
        search = st.text_input("Search", placeholder="question, id, sql…")

    path = Path(annotated_path)
    if not path.is_file():
        st.error(f"File not found: {path}")
        st.stop()

    try:
        items = cached_items(
            str(path.resolve()),
            str(Path(db_root).resolve()),
            run_sql,
            preview_limit,
        )
    except Exception as e:
        st.error(f"Failed to load data: {e}")
        st.stop()

    meta = summarize_items(items)
    difficulties = sorted({i["difficulty"] for i in items})
    categories = sorted({i["auto_category"] for i in items if not i["ex_pass"]})
    failure_kinds = sorted(
        {i["failure_kind"] for i in items if i.get("failure_kind")}
    )
    db_ids = sorted({i["db_id"] for i in items})

    with st.sidebar:
        difficulty = st.selectbox("Difficulty", [""] + difficulties, format_func=lambda x: x or "All")
        category = st.selectbox("Category", [""] + categories, format_func=lambda x: x or "All")
        failure_kind = st.selectbox(
            "Failure kind", [""] + failure_kinds, format_func=lambda x: x or "All"
        )
        db_id = st.selectbox("Database", [""] + db_ids, format_func=lambda x: x or "All")

    filtered = filter_items(
        items,
        failures_only=failures_only,
        difficulty=difficulty,
        category=category,
        failure_kind=failure_kind,
        db_id=db_id,
        search=search,
    )

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Showing", len(filtered))
    c2.metric("EX pass (full set)", meta["pass_count"])
    c3.metric("EX fail (full set)", meta["fail_count"])
    acc = (
        100.0 * meta["pass_count"] / meta["total"] if meta["total"] else 0.0
    )
    c4.metric("EX accuracy", f"{acc:.1f}%")

    fail_filtered = [i for i in filtered if not i["ex_pass"]]
    if fail_filtered:
        cat_counts = {}
        for i in fail_filtered:
            cat_counts[i["auto_category"]] = cat_counts.get(i["auto_category"], 0) + 1
        top = sorted(cat_counts.items(), key=lambda x: -x[1])[:8]
        st.write(
            "Top categories in filtered set: "
            + " · ".join(f"`{k}` ({v})" for k, v in top)
        )

    if not filtered:
        st.info("No rows match the current filters.")
        return

    st.divider()
    for it in filtered:
        status = "PASS" if it["ex_pass"] else "FAIL"
        title = (
            f"#{it['sql_idx']} · Q{it['question_id']} · {it['difficulty']} · "
            f"{status} · `{it['auto_category']}` · {it['db_id']}"
        )
        with st.expander(title, expanded=False):
            st.markdown(f"**Question:** {it['question']}")
            if it.get("evidence"):
                st.markdown(f"**Evidence:** {it['evidence']}")
            if not it["ex_pass"]:
                st.markdown(f"**Category reason:** {it['category_reason']}")
                if it.get("failure_kind"):
                    st.markdown(f"**Failure kind:** `{it['failure_kind']}`")

            col_g, col_p = st.columns(2)
            with col_g:
                st.markdown("**Gold SQL**")
                st.code(it["gold_sql"], language="sql")
            with col_p:
                st.markdown("**Predicted SQL**")
                st.code(it["predicted_sql"], language="sql")

            if it.get("gold_preview") or it.get("pred_preview"):
                st.markdown("**Result previews**")
                p1, p2 = st.columns(2)
                with p1:
                    render_preview_table("Gold result", it.get("gold_preview"))
                with p2:
                    render_preview_table("Predicted result", it.get("pred_preview"))


if __name__ == "__main__":
    main()
