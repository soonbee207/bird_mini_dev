import sqlite3
import json

DB_PATH = "/Users/soonbeehwang/Desktop/mini_dev/mini_dev_data/dev_databases/debit_card_specializing/debit_card_specializing.sqlite"

def inspect_schema(db_path):
    conn = sqlite3.connect(db_path)
    cur  = conn.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    tables = [r[0] for r in cur.fetchall()]

    schema = {}
    for table in tables:
        # Column info: cid, name, type, notnull, default, pk
        cur.execute(f"PRAGMA table_info('{table}')")
        cols = cur.fetchall()

        # Sample 3 rows to see real values
        cur.execute(f"SELECT * FROM '{table}' LIMIT 3")
        sample_rows = cur.fetchall()

        schema[table] = {
            "columns": [
                {
                    "name":    c[1],
                    "type":    c[2],
                    "pk":      bool(c[5]),
                    "notnull": bool(c[3]),
                }
                for c in cols
            ],
            "sample_rows": [list(r) for r in sample_rows]
        }

    conn.close()
    return schema

schema = inspect_schema(DB_PATH)

# ── Pretty print to terminal ──────────────────────────────────────────────────
for table, info in schema.items():
    print(f"\n{'='*50}")
    print(f"TABLE: {table}")
    print(f"{'='*50}")
    print(f"  Columns:")
    for col in info["columns"]:
        pk_tag  = " [PK]" if col["pk"]      else ""
        nn_tag  = " NOT NULL" if col["notnull"] else ""
        print(f"    - {col['name']:<25} {col['type']:<15}{pk_tag}{nn_tag}")
    print(f"\n  Sample rows:")
    col_names = [c["name"] for c in info["columns"]]
    print(f"    {col_names}")
    for row in info["sample_rows"]:
        print(f"    {row}")

# ── Save to JSON ──────────────────────────────────────────────────────────────
out_path = "/Users/soonbeehwang/Desktop/mini_dev/mini_dev_data/schema_debit_card_specializing.json"
with open(out_path, "w") as f:
    json.dump(schema, f, indent=2)
print(f"\n\nSaved → {out_path}")