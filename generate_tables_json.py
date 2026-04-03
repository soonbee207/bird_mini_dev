import sqlite3
import json
from pathlib import Path

db_dir = Path("./mini_dev_data/dev_databases")
schemas = []

for folder in sorted(db_dir.iterdir()):
    if not folder.is_dir():
        continue
    sqlite_files = list(folder.glob("*.sqlite"))
    if not sqlite_files:
        continue
    
    db_path = sqlite_files[0]
    db_id = folder.name
    print(f"Processing: {db_id}")
    
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
    tables = [r[0] for r in cur.fetchall()]
    
    column_names = [[-1, "*"]]
    column_names_original = [[-1, "*"]]
    column_types = ["text"]
    primary_keys = []
    foreign_keys = []
    col_idx_map = {}
    
    for t_idx, table in enumerate(tables):
        cur.execute(f'PRAGMA table_info("{table}")')
        for col in cur.fetchall():
            g_idx = len(column_names)
            col_idx_map[(table.lower(), col[1].lower())] = g_idx
            column_names.append([t_idx, col[1].lower()])
            column_names_original.append([t_idx, col[1]])
            column_types.append("number" if "INT" in col[2].upper() or "REAL" in col[2].upper() else "text")
            if col[5] > 0:
                primary_keys.append(g_idx)
        
        cur.execute(f'PRAGMA foreign_key_list("{table}")')
        for fk in cur.fetchall():
            # Skip if any FK field is None
            if fk[2] is None or fk[3] is None or fk[4] is None:
                continue
            from_key = (table.lower(), fk[3].lower())
            to_key = (fk[2].lower(), fk[4].lower())
            if from_key in col_idx_map and to_key in col_idx_map:
                foreign_keys.append([col_idx_map[from_key], col_idx_map[to_key]])
    
    conn.close()
    
    schemas.append({
        "db_id": db_id,
        "table_names": [t.lower() for t in tables],
        "table_names_original": tables,
        "column_names": column_names,
        "column_names_original": column_names_original,
        "column_types": column_types,
        "primary_keys": primary_keys,
        "foreign_keys": foreign_keys
    })
    print(f"  Tables: {len(tables)}, FKs: {len(foreign_keys)}")

with open("./mini_dev_data/tables.json", "w") as f:
    json.dump(schemas, f, indent=2)

print(f"\nDone! Saved {len(schemas)} schemas to ./mini_dev_data/tables.json")
