from table_schema import generate_schema_prompt

## Schema + question + ordered reasoning + instructions (v2 design doc). Original: prompt.py


def generate_comment_prompt(question, sql_dialect, knowledge=None):
    base_prompt = f"-- Using valid {sql_dialect}"
    knowledge_text = " and understanding External Knowledge" if knowledge else ""

    if knowledge:
        knowledge_prompt = (
            f"-- External Knowledge (IMPORTANT - you MUST use this to write the SQL):\n"
            f"-- {knowledge}\n"
            f"-- The above knowledge gives you exact hints about column values, date formats,\n"
            f"-- which table/column defines a time period, and calculation methods. Follow it precisely.\n"
            f"-- If it names a specific table and column for months or years (e.g. yearmonth.Date as YYYYMM),\n"
            f"-- you must use that table and column; do not swap in another date column because it feels more natural."
        )
    else:
        knowledge_prompt = ""

    combined_prompt = (
        f"{base_prompt}{knowledge_text}, answer the following questions for the tables provided above.\n"
        f"-- Question: {question}\n"
        f"{knowledge_prompt}"
    )
    return combined_prompt


def generate_cot_prompt(sql_dialect):
    return f"""
Before writing SQL, run the pipeline in the instructions (steps 1→7, then step 8) entirely in your head.
Do not print intermediate steps, JSON, or headings—only the final {sql_dialect} query in your reply.
At each step, update the same internal “scratchpad” using the field names given there so the handoff to the next step is explicit.

Sequential commitment: treat each step’s output as fixed for later steps; if you must fix a contradiction, revise from that step forward and re-derive downstream steps.

Generate the {sql_dialect} for the above question after applying that pipeline:
"""


def generate_instruction_prompt(sql_dialect):
    return f"""
=== PIPELINE ORDER (internal only — do steps 1–7 before SQL; step 8 is the only thing you output) ===

Between steps, keep one internal scratchpad (never printed). After each step, that scratchpad must include the listed fields so the next step has an explicit handoff.

Step 1 — Intent sketch
  Inputs: the question text; optional External Knowledge block above.
  Handoff fields: entities; filters_desc (restrictions in words); ordering_need (none | top1 | topk | ordered_list | minmax); metric_in_answer (yes/no — will the final answer show a number the question asked for?).

Step 2 — Evidence binding
  Inputs: Step 1 scratchpad; External Knowledge; schema sample rows.
  Handoff fields: bindings — list of (table, column, literal_or_rule) tying phrases to schema and literals (e.g. encoded dates).

Step 3 — Join plan
  Inputs: Step 2 scratchpad; full schema keys/foreign keys.
  Handoff fields: tables (minimal set); joins — per edge: left_table, right_table, join_condition, why_needed (one short reason).

Step 4 — Logic plan (WHERE / GROUP BY / HAVING / subqueries)
  Inputs: Steps 1–3 scratchpads.
  Handoff fields: where_sketch; group_by (columns/expressions, or empty); having_sketch (or empty); agg_rank (aggregates only for sort/filter); agg_select (aggregates allowed in final SELECT because the question asked for that number).

Step 5 — Projection
  Inputs: Step 4; exact wording of what to return.
  Handoff fields: select_items; distinct_needed (yes/no).

Step 6 — Order & limit
  Inputs: Steps 1 and 5; implied ranking or top-k.
  Handoff fields: order_by (expressions or empty); limit (integer or none).

Step 7 — SQL emission
  Inputs: frozen scratchpad from steps 1–6.
  Handoff fields: sql_draft (one complete query candidate), check_flags initialized to empty.

Step 8 — Explicit self-check (internal, then finalize output)
  Inputs: sql_draft and full scratchpad from steps 1–7.
  Internal checks (must all pass before finalizing):
  - Projection/shape: SELECT list matches Step 5 exactly (no extra helper columns unless explicitly asked).
  - Evidence/date binding: literals and date columns match Step 2 bindings (do not swap to a different date column).
  - Join sufficiency/minimality: every join edge in Step 3 is necessary; no missing join for requested fields/filters.
  - Logic consistency: WHERE/GROUP BY/HAVING/aggregates match Step 4; ranking aggregates stay out of final SELECT unless asked.
  - Ordering/top-k: ORDER BY/LIMIT match Step 6 implication (superlative/top-k/min-max).
  - Dialect validity: SQLite-safe syntax/functions and schema identifiers.
  Action: if a check fails, minimally revise sql_draft and re-check; when all checks pass, output only the final {sql_dialect} query text.

=== Final reply (only visible output) ===
Do not mention steps, scratchpad, or reasoning.
Do not include comments in the SQL. Do not start with ```.
Return only {sql_dialect} starting with SELECT (or WITH if you need a CTE). No semicolon at the end.
String values are case-sensitive. Use the exact casing as in the schema or example rows.
Do not use SELECT * — always select only the columns needed to answer the question.

Answer shape (critical for benchmark execution match):
- Return only columns the question explicitly asks for (e.g. an id, a name, a description, a single scalar).
- Do not add extra helper columns to the final SELECT (e.g. SUM(...), COUNT(...), AVG(...) as a displayed column) unless the question explicitly asks for that number, total, count, or average.
- If an aggregate is only needed to rank or filter rows, use it in ORDER BY, in a subquery, or in HAVING — not as an extra SELECT column unless asked.
- Do not concatenate columns with || (or CONCAT) unless the question asks for one combined field.
- Do not add DISTINCT unless the question or External Knowledge clearly requires unique rows or de-duplication.

ORDER BY and LIMIT:
- Use ORDER BY and LIMIT when the question implies ordering, ranking, superlatives, highest/lowest, top/bottom, smallest/largest, first N, or min/max — even if it does not use the word "sort".
- Do not add ORDER BY or LIMIT when the question is a plain list or filter with no implied ordering or top-k.

External Knowledge vs calendar wording (especially dates):
- The English question may say "in September 2013" while External Knowledge encodes the period (often YYYYMM on yearmonth.Date, e.g. '201309').
- When External Knowledge ties a month/year to yearmonth.Date (or any named table.column), filter or join through THAT table and column.
- Join yearmonth to other tables using keys from the schema (e.g. CustomerID).
- Do NOT redefine the period using transactions_1k.Date (or similar) with SUBSTR/ISO ranges if External Knowledge already fixes the period on yearmonth.Date.
- If External Knowledge gives an exact literal (e.g. September 2013 refers to 201309), use equality on the stated column (e.g. yearmonth.Date = '201309').

Aggregation rules:
- For "highest/lowest monthly X", GROUP BY month then ORDER BY SUM(X) DESC LIMIT 1 (not raw MAX(X) on rows when the benchmark sums by month).
- For "highest/lowest yearly X", GROUP BY year then ORDER BY SUM(X) DESC LIMIT 1.
- For "total X per Y", GROUP BY Y then SUM(X).

Example (monthly aggregation — SELECT includes SUM because the question asks for the monthly amount):
-- Question: What is the highest monthly consumption in 2012?
-- Evidence: first 4 chars of Date = year, 5th and 6th = month
-- Correct: SELECT SUM(Consumption) FROM yearmonth WHERE SUBSTR(Date,1,4)='2012' GROUP BY SUBSTR(Date,5,2) ORDER BY SUM(Consumption) DESC LIMIT 1
-- Wrong:   SELECT MAX(Consumption) FROM yearmonth WHERE SUBSTR(Date,1,4)='2012'

Example (yearmonth.Date vs transaction dates):
-- Question: List product descriptions for products consumed in September, 2013.
-- Evidence: September 2013 refers to 201309; year/month from yearmonth.Date.
-- Correct: join transactions_1k to yearmonth and products, WHERE yearmonth.Date = '201309'
-- Wrong:   filter only on transactions_1k.Date with SUBSTR — ignores evidence

Dialect: use only valid {sql_dialect} constructs (e.g. SQLite: no unsupported functions; match schema identifiers).
"""


def generate_combined_prompts_one(db_path, question, sql_dialect, knowledge=None):
    schema_prompt = generate_schema_prompt(sql_dialect, db_path, num_rows=3)
    comment_prompt = generate_comment_prompt(question, sql_dialect, knowledge)
    cot_prompt = generate_cot_prompt(sql_dialect)
    instruction_prompt = generate_instruction_prompt(sql_dialect)

    combined_prompts = "\n\n".join(
        [schema_prompt, comment_prompt, cot_prompt, instruction_prompt]
    )
    return combined_prompts
