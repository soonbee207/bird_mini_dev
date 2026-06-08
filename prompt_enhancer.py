from schema_graph import SchemaGraph, load_schemas

# Database-specific hints based on your error analysis
DB_HINTS = {
    "formula_1": """CRITICAL DISAMBIGUATION:
- results.position = race finish position (per-race)
- driverStandings.position = championship standing (cumulative)
For "championship" or "standings" queries, use driverStandings, NOT results.""",

    "california_schools": """CRITICAL:
- 'Charter Funding Type' is in the 'frpm' table, NOT 'schools'
- Always JOIN frpm when asking about funding type or eligibility""",

    "superhero": """CASE SENSITIVE VALUES:
- race: 'Human' not 'human'
- attribute_name: 'Strength' not 'strength'
Always match exact case from database.""",
}


def enhance_prompt(question: str, db_id: str, schemas: dict) -> str:
    """Generate an enhanced prompt with schema grounding."""
    
    if db_id not in schemas:
        return f"Database {db_id} not found."
    
    graph = schemas[db_id]
    
    # Build schema context
    lines = []
    lines.append(f"=== Database: {db_id} ===\n")
    
    # Tables and columns
    lines.append("TABLES:")
    for name, info in graph.tables.items():
        cols = ", ".join(info["columns"])
        lines.append(f"  {name}: [{cols}]")
    
    # Foreign keys
    lines.append("\nJOIN RELATIONSHIPS:")
    for fk in graph.foreign_keys:
        lines.append(f"  {fk['from_table']}.{fk['from_col']} -> {fk['to_table']}.{fk['to_col']}")
    
    # Database-specific hints
    if db_id in DB_HINTS:
        lines.append(f"\n{DB_HINTS[db_id]}")
    
    schema_context = "\n".join(lines)
    
    # Build the full prompt
    prompt = f"""{schema_context}

Question: {question}

Generate the SQL query. Use the JOIN RELATIONSHIPS above to determine the correct tables and join paths.
SQL:"""
    
    return prompt


if __name__ == "__main__":
    # Load schemas
    schemas = load_schemas("./mini_dev_data/tables.json")
    
    # Test case from your error report: Query [201]
    question = "Calculate the percentage whereby Hamilton was not at 1st position in the championship since 2010."
    
    print("="*70)
    print("ENHANCED PROMPT DEMO")
    print("="*70)
    print(f"\nOriginal question: {question}\n")
    print("-"*70)
    print(enhance_prompt(question, "formula_1", schemas))
