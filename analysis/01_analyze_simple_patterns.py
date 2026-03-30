import json

data = json.load(open('mini_dev_data/merged_analysis_simple_only.json'))

patterns = {
    'SELECT *': 0,
    'IIF vs CASE WHEN': 0,
    'Extra semicolon': 0,
    'Extra ORDER BY': 0,
    'Extra LIMIT': 0,
    'Added DISTINCT': 0,
    'Missing DISTINCT': 0,
    'Added NULLIF': 0,
    'Extra columns selected': 0,
    'Extra JOIN': 0,
    'Added COALESCE': 0,
    'Likely correct': 0,
}

flagged = []

for d in data:
    g = d['gold_sql']
    p = d['predicted_sql']
    gu = g.upper()
    pu = p.upper()
    found = []

    if 'SELECT\n  *' in p or 'SELECT *' in p: found.append('SELECT *')
    if 'IIF(' in g and 'IIF(' not in p: found.append('IIF vs CASE WHEN')
    if p.strip().endswith(';'): found.append('Extra semicolon')
    if 'ORDER BY' in pu and 'ORDER BY' not in gu: found.append('Extra ORDER BY')
    if 'LIMIT' in pu and 'LIMIT' not in gu: found.append('Extra LIMIT')
    if 'DISTINCT' in pu and 'DISTINCT' not in gu: found.append('Added DISTINCT')
    if 'DISTINCT' in gu and 'DISTINCT' not in pu: found.append('Missing DISTINCT')
    if 'NULLIF' in pu: found.append('Added NULLIF')
    if 'COALESCE' in pu: found.append('Added COALESCE')

    g_cols = g.split('FROM')[0].replace('SELECT','').strip()
    p_cols = p.split('FROM')[0].replace('SELECT','').strip()
    if len(p_cols.split(',')) > len(g_cols.split(',')) + 1:
        found.append('Extra columns selected')

    g_joins = gu.count('JOIN')
    p_joins = pu.count('JOIN')
    if p_joins > g_joins + 1:
        found.append('Extra JOIN')

    if not found:
        found.append('Likely correct')

    for f in found:
        patterns[f] += 1

    flagged.append({
        'question_id': d['question_id'],
        'db_id': d['db_id'],
        'question': d['question'],
        'patterns': found
    })

print('=== PATTERN COUNTS (148 simple questions) ===')
for k, v in sorted(patterns.items(), key=lambda x: -x[1]):
    bar = '█' * v
    print(f'{k:<25} {v:>3}  {bar}')

print()
correct = [f for f in flagged if f['patterns'] == ['Likely correct']]
issues = [f for f in flagged if f['patterns'] != ['Likely correct']]
print(f'Likely correct : {len(correct)} / 148')
print(f'Has issues     : {len(issues)} / 148')
print()
print('=== QUESTIONS WITH ISSUES (first 15) ===')
for f in issues[:15]:
    print(f'  Q{f["question_id"]:>4} [{f["db_id"]:<25}] {str(f["patterns"]):<40} {f["question"][:55]}')
