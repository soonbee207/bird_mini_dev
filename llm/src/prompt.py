from table_schema import generate_schema_prompt

## combines schema + question + chain-of-thought + instruction into one big prompt

def generate_comment_prompt(question, sql_dialect, knowledge=None):
    base_prompt = f"-- Using valid {sql_dialect}"
    knowledge_text = " and understanding External Knowledge" if knowledge else ""

    if knowledge:
        knowledge_prompt = (
            f"-- External Knowledge (IMPORTANT - you MUST use this to write the SQL):\n"
            f"-- {knowledge}\n"
            f"-- The above knowledge gives you exact hints about column values, date formats,\n"
            f"-- and calculation methods. Follow it precisely."
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
    return f"\nGenerate the {sql_dialect} for the above question after thinking step by step: "


def generate_instruction_prompt(sql_dialect):
    return f"""
        \nIn your response, you do not need to mention your intermediate steps. 
        Do not include any comments in your response.
        Do not need to start with the symbol ```
        You only need to return the result {sql_dialect} SQL code
        start from SELECT
        Do not add a semicolon at the end of the SQL query.
        String values are case-sensitive. Use the exact casing as it appears in the schema or the example rows.
        Do not add DISTINCT unless the question explicitly asks for unique values.
        Do not add ORDER BY unless the question explicitly asks for sorting.
        Do not add LIMIT unless the question explicitly asks for a specific number of results.
        Do not use SELECT * - always select only the specific columns needed.

        Important aggregation rules:
        - When the question asks for "highest/lowest monthly X", always GROUP BY month then ORDER BY SUM(X) DESC LIMIT 1. Never use MAX(X) directly.
        - When the question asks for "highest/lowest yearly X", always GROUP BY year then ORDER BY SUM(X) DESC LIMIT 1.
        - When the question asks for "total X per Y", always GROUP BY Y then SUM(X).

        Example:
        -- Question: What is the highest monthly consumption in 2012?
        -- Evidence: first 4 chars of Date = year, 5th and 6th chars = month
        -- Correct: SELECT SUM(Consumption) FROM yearmonth WHERE SUBSTR(Date,1,4)='2012' GROUP BY SUBSTR(Date,5,2) ORDER BY SUM(Consumption) DESC LIMIT 1
        -- Wrong:   SELECT MAX(Consumption) FROM yearmonth WHERE SUBSTR(Date,1,4)='2012'
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