import json
from collections import defaultdict
from pathlib import Path

class SchemaGraph:
    def __init__(self, db_schema: dict):
        self.db_id = db_schema.get("db_id", "unknown")
        self.tables = {}
        self.columns = {}
        self.foreign_keys = []
        self.edges = defaultdict(list)  # table -> [(other_table, from_col, to_col)]
        
        self._parse_schema(db_schema)
    
    def _parse_schema(self, schema: dict):
        table_names = schema.get("table_names", [])
        table_names_orig = schema.get("table_names_original", table_names)
        column_names = schema.get("column_names", [])
        column_names_orig = schema.get("column_names_original", column_names)
        primary_keys = set(schema.get("primary_keys", []))
        foreign_keys = schema.get("foreign_keys", [])
        
        # Build tables
        for idx, (name, orig) in enumerate(zip(table_names, table_names_orig)):
            self.tables[name] = {"idx": idx, "name": name, "original": orig, "columns": []}
        
        # Build columns
        for col_idx, ((table_idx, col_name), (_, col_orig)) in enumerate(zip(column_names, column_names_orig)):
            if table_idx < 0:
                continue
            table_name = table_names[table_idx]
            is_pk = col_idx in primary_keys
            self.columns[col_idx] = {
                "table": table_name,
                "name": col_name,
                "original": col_orig,
                "is_pk": is_pk
            }
            self.tables[table_name]["columns"].append(col_name)
        
        # Build FK edges (bidirectional for join traversal)
        for from_col_idx, to_col_idx in foreign_keys:
            if from_col_idx not in self.columns or to_col_idx not in self.columns:
                continue
            from_col = self.columns[from_col_idx]
            to_col = self.columns[to_col_idx]
            
            self.foreign_keys.append({
                "from_table": from_col["table"],
                "from_col": from_col["name"],
                "to_table": to_col["table"],
                "to_col": to_col["name"]
            })
            
            # Add edges both directions
            self.edges[from_col["table"]].append((to_col["table"], from_col["name"], to_col["name"]))
            self.edges[to_col["table"]].append((from_col["table"], to_col["name"], from_col["name"]))
    
    def get_join_path(self, table1: str, table2: str, max_depth: int = 3) -> list:
        """BFS to find shortest path between two tables."""
        if table1 == table2:
            return [table1]
        
        visited = {table1}
        queue = [(table1, [table1])]
        
        while queue:
            current, path = queue.pop(0)
            if len(path) > max_depth:
                continue
                
            for neighbor, _, _ in self.edges.get(current, []):
                if neighbor == table2:
                    return path + [neighbor]
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append((neighbor, path + [neighbor]))
        
        return []  # No path found
    
    def get_join_sql(self, path: list) -> str:
        """Convert a table path to SQL JOIN clauses."""
        if len(path) < 2:
            return f"FROM {path[0]}" if path else ""
        
        sql = [f"FROM {path[0]}"]
        for i in range(len(path) - 1):
            t1, t2 = path[i], path[i+1]
            # Find the FK between these tables
            for neighbor, from_col, to_col in self.edges.get(t1, []):
                if neighbor == t2:
                    sql.append(f"JOIN {t2} ON {t1}.{from_col} = {t2}.{to_col}")
                    break
        
        return "\n".join(sql)
    
    def print_schema_summary(self):
        """Print a human-readable schema summary."""
        print(f"\n{'='*60}")
        print(f"Database: {self.db_id}")
        print(f"{'='*60}")
        
        print("\nTABLES:")
        for name, info in self.tables.items():
            cols = ", ".join(info["columns"][:5])
            if len(info["columns"]) > 5:
                cols += f", ... (+{len(info['columns'])-5} more)"
            print(f"  {name}: [{cols}]")
        
        print("\nFOREIGN KEYS:")
        for fk in self.foreign_keys:
            print(f"  {fk['from_table']}.{fk['from_col']} -> {fk['to_table']}.{fk['to_col']}")
        
        if not self.foreign_keys:
            print("  (none detected - may need manual definition)")


def load_schemas(tables_json_path: str) -> dict:
    """Load all schemas from tables.json."""
    with open(tables_json_path) as f:
        schemas = json.load(f)
    return {s["db_id"]: SchemaGraph(s) for s in schemas}


if __name__ == "__main__":
    # Test with formula_1
    schemas = load_schemas("./mini_dev_data/tables.json")
    
    # Show formula_1 schema
    f1 = schemas["formula_1"]
    f1.print_schema_summary()
    
    # Find join path between drivers and circuits
    print("\n" + "-"*60)
    print("Example: Join path from 'drivers' to 'circuits'")
    path = f1.get_join_path("drivers", "circuits")
    print(f"Path: {' -> '.join(path)}")
    print(f"SQL:\n{f1.get_join_sql(path)}")
