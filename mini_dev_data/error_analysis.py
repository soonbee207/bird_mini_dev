import json
import sqlite3
import os
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────
GROUND_TRUTH_PATH = "/Users/soonbeehwang/Desktop/mini_dev/mini_dev_data/mini_dev_sqlite_pretty.json"
#PREDICT_PATH      = "/Users/soonbeehwang/Desktop/mini_dev/llm/exp_result/gpt52_improved_v1/predict_mini_dev_openai__gpt-5-2_SQLite.json"
#PREDICT_PATH = "/Users/soonbeehwang/Desktop/mini_dev/llm/exp_result/test10_v2_output/predict_mini_dev_openai__gpt-5-2_SQLite.json"
#PREDICT_PATH = "/Users/soonbeehwang/Desktop/mini_dev/llm/exp_result/test50_output/predict_mini_dev_openai__gpt-5-2_SQLite.json"
PREDICT_PATH = "/Users/soonbeehwang/Desktop/mini_dev/llm/exp_result/gpt52_improved_v1/predict_mini_dev_openai__gpt-5-2_SQLite.json"
DB_DIR            = "/Users/soonbeehwang/Desktop/mini_dev/mini_dev_data/dev_databases"
OUTPUT_PATH       = "/Users/soonbeehwang/Desktop/mini_dev/mini_dev_data/error_analysis.json"

# ── Error taxonomy ────────────────────────────────────────────────────────────
# Assigned automatically where possible; rest marked "manual_review"
def classify_error(gold_result, pred_result, pred_sql, gold_sql, error_msg):
    if error_msg:
        msg = error_msg.lower()
        if "no such table" in msg:
            return "wrong_table_name"
        if "no such column" in msg:
            return "wrong_column_name"
        if "syntax error" in msg:
            return "syntax_error"
        return "execution_error"

    if pred_result == gold_result:
        return "correct"

    # Heuristic checks on SQL text
    gold_lower, pred_lower = gold_sql.lower(), pred_sql.lower()

    # Check if predicted SQL is missing GROUP BY when gold has it
    if "group by" in gold_lower and "group by" not in pred_lower:
        return "logic_error_missing_groupby"

    # Check if predicted SQL is missing SUBSTR / date extraction
    if "substr" in gold_lower and "substr" not in pred_lower:
        return "logic_error_wrong_date_extraction"

    # Check if aggregation function differs
    gold_aggs = set(w for w in ["sum","avg","count","min","max"] if w in gold_lower)
    pred_aggs = set(w for w in ["sum","avg","count","min","max"] if w in pred_lower)
    if gold_aggs != pred_aggs:
        return "logic_error_wrong_aggregation"

    return "wrong_result_manual_review"

# ── Schema loader ─────────────────────────────────────────────────────────────
def get_schema(db_path):
    conn = sqlite3.connect(db_path)
    cur  = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    schema = {}
    for t in tables:
        cur.execute(f"PRAGMA table_info('{t}')")
        schema[t] = [r[1].lower() for r in cur.fetchall()]  # lowercase for comparison
    conn.close()
    return schema  # e.g. {"customers": ["customerid","segment","currency"], ...}

def check_hallucination(pred_sql, schema):
    """Return list of genuinely hallucinated names. Ignores aliases, CTEs, keywords."""
    import re
    all_tables  = set(schema.keys())
    all_columns = set(col for cols in schema.values() for col in cols)
    pred_lower  = pred_sql.lower()

    # Collect all alias definitions so we don't flag them
    aliases = set(re.findall(r'(?:as\s+)([a-z_][a-z0-9_]*)', pred_lower))
    aliases |= set(re.findall(r'(?:from|join)\s+[a-z_][a-z0-9_]*\s+([a-z_][a-z0-9_]*)\b', pred_lower))
    aliases |= set(re.findall(r'with\s+([a-z_][a-z0-9_]*)\s+as\s*\(', pred_lower))

    sql_keywords = {
        "select","from","where","join","on","group","order","by","as","with",
        "and","or","not","in","is","null","limit","having","case","when","union",
        "then","else","end","sum","avg","count","min","max","cast","substr","cross",
        "like","between","distinct","inner","left","right","outer","asc","desc",
        "all","any","exists","over","partition","nullif","coalesce","trim",
        "upper","lower","replace","round","strftime","date","time","real",
        "integer","text","float","int","varchar","boolean","true","false"
    }

    hallucinated = []

    # Check table names after FROM/JOIN only
    used_tables = re.findall(r'(?:from|join)\s+([a-z_][a-z0-9_]*)', pred_lower)
    for t in used_tables:
        if t not in all_tables and t not in aliases and t not in sql_keywords and t != "sqlite_sequence":
            hallucinated.append({"type": "table", "name": t})

    # Check column names via dot notation only (most reliable)
    used_cols = re.findall(r'[a-z_][a-z0-9_]*\.([a-z_][a-z0-9_]*)', pred_lower)
    for c in used_cols:
        if c not in all_columns and c not in sql_keywords:
            hallucinated.append({"type": "column", "name": c})

    return hallucinated

# ── Execute SQL safely ────────────────────────────────────────────────────────
def run_sql(db_path, sql, timeout_sec=30):
    import threading
    result = [None, None]
    def _run():
        try:
            conn = sqlite3.connect(db_path)  # connection created inside thread
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute(sql)
            result[0] = [tuple(r) for r in cur.fetchall()]
            conn.close()
        except Exception as e:
            result[1] = str(e)
    t = threading.Thread(target=_run)
    t.start()
    t.join(timeout=timeout_sec)
    if t.is_alive():
        return None, f"timeout after {timeout_sec}s"
    return result[0], result[1]

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    with open(GROUND_TRUTH_PATH) as f: merged  = json.load(f)
    with open(PREDICT_PATH)      as f: predict = json.load(f)

    merged = merged[:50]  # TODO: remove this line to run on all 500

    # Build predicted SQL lookup: index → sql string
    # predict file format: {"0": "SELECT ... ----- bird ----- db_id", ...}
    pred_lookup = {}
    for idx_str, val in predict.items():
        parts = val.split("\t----- bird -----\t")
        pred_sql = parts[0].strip()
        pred_lookup[int(idx_str)] = pred_sql

    results = []
    stats = {"correct": 0, "total": 0, "by_difficulty": {}, "by_error_type": {}}

    for i, item in enumerate(merged):
        qid        = item.get("question_id", i)
        db_id      = item["db_id"]
        difficulty = item.get("difficulty", "unknown")
        question   = item["question"]
        gold_sql   = item["SQL"]
        pred_sql   = pred_lookup.get(i, "")

        db_path = os.path.join(DB_DIR, db_id, f"{db_id}.sqlite")
        schema  = get_schema(db_path)
        hallucinated = check_hallucination(pred_sql, schema)

        print(f"Running question {i+1}/10: {qid}")
        print(f"  [{i+1}/10] q{qid} ({difficulty})")
        gold_result, gold_err = run_sql(db_path, gold_sql)
        pred_result, pred_err = run_sql(db_path, pred_sql)
        if pred_err: print(f"    pred_err: {pred_err[:120]}")
        if gold_err: print(f"    gold_err: {gold_err[:120]}")

        error_type = classify_error(
            gold_result, pred_result, pred_sql, gold_sql,
            pred_err or ""
        )
        # Override with hallucination if detected and result is wrong
        if hallucinated and error_type != "correct":
            types = [h["type"] for h in hallucinated]
            if "table"  in types: error_type = "hallucinated_table"
            elif "column" in types: error_type = "hallucinated_column"

        is_correct = (error_type == "correct")

        # Stats
        stats["total"] += 1
        if is_correct:
            stats["correct"] += 1
        stats["by_difficulty"].setdefault(difficulty, {"correct": 0, "total": 0})
        stats["by_difficulty"][difficulty]["total"] += 1
        if is_correct:
            stats["by_difficulty"][difficulty]["correct"] += 1
        stats["by_error_type"][error_type] = stats["by_error_type"].get(error_type, 0) + 1

        results.append({
            "question_id":  qid,
            "db_id":        db_id,
            "difficulty":   difficulty,
            "question":     question,
            "gold_sql":     gold_sql,
            "predicted_sql": pred_sql,
            "gold_result":  str(gold_result),
            "pred_result":  str(pred_result),
            "gold_error":   gold_err,
            "pred_error":   pred_err,
            "error_type":   error_type,
            "hallucinated": hallucinated,  # e.g. [{"type": "column", "name": "foo"}]
            "is_correct":   is_correct,
        })

    # ── Summary ───────────────────────────────────────────────────────────────
    accuracy = stats["correct"] / stats["total"] * 100 if stats["total"] else 0
    print(f"\n{'='*50}")
    print(f"Overall accuracy : {accuracy:.1f}%  ({stats['correct']}/{stats['total']})")
    print(f"\nBy difficulty:")
    for diff, s in sorted(stats["by_difficulty"].items()):
        acc = s["correct"] / s["total"] * 100 if s["total"] else 0
        print(f"  {diff:<15} {acc:5.1f}%  ({s['correct']}/{s['total']})")
    print(f"\nError breakdown:")
    for etype, cnt in sorted(stats["by_error_type"].items(), key=lambda x: -x[1]):
        print(f"  {etype:<40} {cnt}")
    print(f"{'='*50}\n")

    # ── Save ──────────────────────────────────────────────────────────────────
    output = {"stats": stats, "accuracy_pct": round(accuracy, 2), "results": results}
    with open(OUTPUT_PATH, "w") as f:
        json.dump(output, f, indent=2)
    print(f"Saved → {OUTPUT_PATH}")

if __name__ == "__main__":
    main()