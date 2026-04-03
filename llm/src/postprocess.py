import re
import sqlite3

# ── Option 3: Output normalizer ───────────────────────────────────────────────
# Trims extra selected columns based on what the question semantically asks for.
# Runs on the SQL string before saving, so no DB execution needed.

# Keywords that suggest a single-entity answer
_SINGLE_ID_PATTERNS   = re.compile(r'\b(who|which customer|which client)\b', re.I)
_SINGLE_DATE_PATTERNS = re.compile(r'\b(which year|which month|when)\b', re.I)
_SINGLE_NUM_PATTERNS  = re.compile(r'\b(what is the (ratio|difference|average|total|count|number|percentage|amount))\b', re.I)

def normalize_select_columns(sql: str, question: str) -> str:
    """
    If the question asks for a single entity (who/which year/what is the ratio etc.)
    and the predicted SQL selects multiple columns, trim to just the first column.
    This fixes spurious column selection (e.g. returning CustomerID + SUM(Consumption)
    when only CustomerID was asked for).
    """
    sql = sql.strip()

    # Only apply to SELECT statements
    if not sql.upper().startswith("SELECT"):
        return sql

    # Check if question implies single-column answer
    is_single = (
        _SINGLE_ID_PATTERNS.search(question)
        or _SINGLE_DATE_PATTERNS.search(question)
        or _SINGLE_NUM_PATTERNS.search(question)
    )
    if not is_single:
        return sql

    # Parse SELECT columns — find everything between SELECT and FROM
    match = re.match(r'(SELECT\s+)(.*?)(\s+FROM\s+)', sql, re.IGNORECASE | re.DOTALL)
    if not match:
        return sql

    select_kw   = match.group(1)   # "SELECT "
    cols_str    = match.group(2)   # "y.CustomerID, SUM(y.Consumption) AS TotalConsumption"
    rest        = sql[match.end(2):]  # " FROM yearmonth ..."

    # Split on commas that are NOT inside parentheses
    depth, current, cols = 0, [], []
    for ch in cols_str:
        if ch == '(':  depth += 1
        elif ch == ')': depth -= 1
        if ch == ',' and depth == 0:
            cols.append(''.join(current).strip())
            current = []
        else:
            current.append(ch)
    if current:
        cols.append(''.join(current).strip())

    if len(cols) <= 1:
        return sql  # already single column, nothing to trim

    # Keep only the first column
    trimmed_sql = f"{select_kw}{cols[0]}{rest}"
    print(f"[postprocess] Trimmed {len(cols)} columns → 1 for question: '{question[:60]}'")
    return trimmed_sql


# ── Option 2: Schema validator ────────────────────────────────────────────────
# Checks predicted SQL for hallucinated table/column names against actual schema.

def get_schema(db_path: str) -> dict:
    """Returns {table_name: [col1, col2, ...]} all lowercase."""
    conn = sqlite3.connect(db_path)
    cur  = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    schema = {}
    for t in tables:
        cur.execute(f"PRAGMA table_info('{t}')")
        schema[t.lower()] = [r[1].lower() for r in cur.fetchall()]
    conn.close()
    return schema

def check_hallucination(sql: str, schema: dict) -> list:
    """
    Returns list of genuinely hallucinated names found in sql.
    Ignores: aliases, CTE names, subquery aliases, SQL keywords.
    e.g. [{"type": "table", "name": "foo"}, {"type": "column", "name": "bar"}]
    """
    sql_lower = sql.lower()
    all_tables  = set(schema.keys())
    all_columns = set(col for cols in schema.values() for col in cols)

    # Collect all alias definitions so we don't flag them as hallucinations:
    # covers: FROM x AS y, JOIN x y, ) AS y, WITH cte AS (
    aliases = set(re.findall(r'(?:as\s+)([a-z_][a-z0-9_]*)', sql_lower))
    # also catch implicit aliases: FROM yearmonth y  JOIN customers c
    aliases |= set(re.findall(r'(?:from|join)\s+[a-z_][a-z0-9_]*\s+([a-z_][a-z0-9_]*)\b', sql_lower))
    # CTE names: WITH cte_name AS (
    aliases |= set(re.findall(r'with\s+([a-z_][a-z0-9_]*)\s+as\s*\(', sql_lower))

    sql_keywords = {
        "select","from","where","join","on","group","order","by","as","with",
        "and","or","not","in","is","null","limit","having","case","when","union",
        "then","else","end","sum","avg","count","min","max","cast","substr","cross",
        "like","between","distinct","inner","left","right","outer","asc","desc",
        "all","any","exists","over","partition","rows","range","nullif","coalesce",
        "trim","upper","lower","replace","round","strftime","date","time","real",
        "integer","text","float","int","varchar","boolean","true","false"
    }

    issues = []

    # Check table names after FROM/JOIN — skip if it's an alias or keyword
    used_tables = re.findall(r'(?:from|join)\s+([a-z_][a-z0-9_]*)', sql_lower)
    for t in used_tables:
        if t not in all_tables and t not in aliases and t not in sql_keywords and t != "sqlite_sequence":
            issues.append({"type": "table", "name": t})

    # Check column names after dot notation only (alias.column) — most reliable signal
    used_cols = re.findall(r'[a-z_][a-z0-9_]*\.([a-z_][a-z0-9_]*)', sql_lower)
    for c in used_cols:
        if c not in all_columns and c not in sql_keywords:
            issues.append({"type": "column", "name": c})

    return issues


def build_retry_prompt(original_prompt: str, sql: str, issues: list, schema: dict) -> str:
    """
    Builds a correction prompt telling GPT exactly what was wrong
    and what valid names are available.
    """
    lines = ["The SQL you generated contains invalid names that do not exist in the database schema:"]
    for issue in issues:
        if issue["type"] == "table":
            valid = list(schema.keys())
            lines.append(f"  - Table `{issue['name']}` does not exist. Valid tables: {valid}")
        elif issue["type"] == "column":
            lines.append(f"  - Column `{issue['name']}` does not exist in any table.")

    lines.append("\nValid schema summary:")
    for tbl, cols in schema.items():
        lines.append(f"  {tbl}: {cols}")

    lines.append(f"\nYour incorrect SQL was:\n{sql}")
    lines.append("\nPlease rewrite the SQL using only valid table and column names from the schema above.")
    lines.append("Return only the corrected SQL starting with SELECT, no comments, no semicolon.")

    return original_prompt + "\n\n" + "\n".join(lines)


# ── Main entry point called from gpt_request.py ───────────────────────────────

def postprocess_sql(sql: str, question: str = "", db_path: str = None,
                    original_prompt: str = None, connect_gpt_fn=None,
                    engine: str = None, client=None) -> str:
    """
    Full post-processing pipeline:
      1. Strip semicolon
      2. Normalize columns (Option 3)
      3. Validate schema + retry if hallucination detected (Option 2)
    """
    # Step 1: clean up
    sql = sql.strip().rstrip(';').strip()

    # Step 2: output normalizer
    if question:
        sql = normalize_select_columns(sql, question)

    # Step 3: hallucination check + retry (only if db_path and retry fn provided)
    if db_path and connect_gpt_fn and original_prompt and engine and client:
        schema = get_schema(db_path)
        MAX_RETRIES = 2
        for attempt in range(MAX_RETRIES):
            issues = check_hallucination(sql, schema)
            if not issues:
                break
            print(f"[postprocess] Hallucination detected (attempt {attempt+1}): {issues}")
            retry_prompt = build_retry_prompt(original_prompt, sql, issues, schema)
            raw = connect_gpt_fn(engine, retry_prompt, 512, 0,
                                 ["--", "\n\n", ";", "#"], client)
            sql = raw.strip().rstrip(';').strip()
            print(f"[postprocess] Retried SQL: {sql[:80]}...")

    return sql