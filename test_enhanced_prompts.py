import json
from schema_graph import load_schemas
from prompt_enhancer import enhance_prompt

# Load schemas and data
schemas = load_schemas("./mini_dev_data/tables.json")

with open("./mini_dev_data/mini_dev_sqlite.json") as f:
    data = json.load(f)

# Test on just 5 queries (you can change this)
test_indices = [0, 1, 2, 100, 200]

for idx in test_indices:
    item = data[idx]
    db_id = item["db_id"]
    question = item["question"]
    gold_sql = item.get("SQL", "N/A")
    
    print(f"\n{'='*70}")
    print(f"Query #{idx} | Database: {db_id}")
    print(f"{'='*70}")
    print(f"Question: {question}")
    print(f"\nGold SQL: {gold_sql[:200]}..." if len(gold_sql) > 200 else f"\nGold SQL: {gold_sql}")
    print(f"\n--- Enhanced Prompt Preview (first 500 chars) ---")
    enhanced = enhance_prompt(question, db_id, schemas)
    print(enhanced[:500] + "..." if len(enhanced) > 500 else enhanced)
    print()
