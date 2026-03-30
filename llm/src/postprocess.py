import re

def postprocess_sql(sql: str) -> str:
    # Rule 1: Remove trailing semicolon
    sql = sql.strip().rstrip(';').strip()
    return sql