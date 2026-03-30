import json
import re

data = json.load(open('mini_dev_data/merged_analysis_simple_only.json'))

def extract_columns(sql):
    sql = re.sub(r'--.*', '', sql)
    tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', sql)
    keywords = {'SELECT','FROM','WHERE','JOIN','ON','AND','OR','NOT',
                'GROUP','BY','ORDER','HAVING','LIMIT','INNER','LEFT',
                'RIGHT','OUTER','AS','DISTINCT','COUNT','SUM','AVG',
                'MAX','MIN','CAST','CASE','WHEN','THEN','ELSE','END',
                'LIKE','IN','IS','NULL','REAL','FLOAT','INTEGER','TEXT',
                'BETWEEN','SUBSTR','STRFTIME','IIF','COALESCE','NULLIF',
                'TRUE','FALSE','DESC','ASC','UNION','EXCEPT','EXISTS'}
    return set(t for t in tokens if t.upper() not in keywords and not t.isdigit())

issues = []
for d in data:
    g = d['gold_sql']
    p = d['predicted_sql']

    g_tokens = extract_columns(g)
    p_tokens = extract_columns(p)

    # tokens in gold but missing from predicted
    missing = g_tokens - p_tokens
    # tokens in predicted but not in gold
    extra = p_tokens - g_tokens

    if missing or extra:
        issues.append({
            'question_id': d['question_id'],
            'db_id': d['db_id'],
            'question': d['question'],
            'gold_sql': g,
            'predicted_sql': p,
            'missing_tokens': sorted(missing),
            'extra_tokens': sorted(extra)
        })

print(f'Questions with token mismatches: {len(issues)} / {len(data)}')
print()
for item in issues[:20]:
    print(f'Q{item["question_id"]} [{item["db_id"]}]')
    print(f'  Question : {item["question"]}')
    print(f'  Missing  : {item["missing_tokens"]}')
    print(f'  Extra    : {item["extra_tokens"]}')
    print(f'  Gold     : {item["gold_sql"]}')
    print(f'  Predicted: {item["predicted_sql"][:150]}')
    print()