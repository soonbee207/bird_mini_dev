"""
Enhanced Error Analysis Script
================================

This script takes existing error_analysis.py output and performs deeper analysis
on the 120 "wrong_result_manual_review" errors to identify specific failure patterns.

Usage:
    python enhanced_error_analysis.py <path_to_error_analysis.json>

Output:
    - Detailed breakdown of logical error types
    - Patterns in hallucinated table names
    - Recommendations for targeted fixes
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path


def extract_table_names(sql):
    """Extract table names from FROM and JOIN clauses"""
    sql_lower = sql.lower()
    tables = set()
    
    # FROM clause
    from_matches = re.findall(r'from\s+([a-z_][a-z0-9_]*)', sql_lower)
    tables.update(from_matches)
    
    # JOIN clause
    join_matches = re.findall(r'join\s+([a-z_][a-z0-9_]*)', sql_lower)
    tables.update(join_matches)
    
    return tables


def extract_where_conditions(sql):
    """Extract WHERE clause conditions"""
    sql_lower = sql.lower()
    match = re.search(r'where\s+(.*?)(?:group|order|limit|having|$)', sql_lower)
    return match.group(1).strip() if match else None


def extract_join_conditions(sql):
    """Extract JOIN ON conditions"""
    sql_lower = sql.lower()
    matches = re.findall(r'on\s+(.*?)(?:where|join|group|order|$)', sql_lower)
    return matches


def extract_select_columns(sql):
    """Extract columns from SELECT clause"""
    sql_lower = sql.lower()
    match = re.search(r'select\s+(.*?)\s+from', sql_lower)
    if match:
        select_part = match.group(1).strip()
        # Split by comma, but be careful with nested functions
        columns = [col.strip() for col in select_part.split(',')]
        return columns
    return []


def extract_group_by_columns(sql):
    """Extract GROUP BY columns"""
    sql_lower = sql.lower()
    match = re.search(r'group\s+by\s+(.*?)(?:having|order|limit|$)', sql_lower)
    if match:
        group_part = match.group(1).strip()
        columns = [col.strip() for col in group_part.split(',')]
        return columns
    return []


def extract_aggregation_functions(sql):
    """Extract aggregation functions used"""
    sql_lower = sql.lower()
    agg_funcs = set()
    
    for func in ['sum', 'avg', 'count', 'min', 'max']:
        if f'{func}(' in sql_lower:
            agg_funcs.add(func)
    
    return agg_funcs


def categorize_wrong_result_error(pred_sql, gold_sql):
    """
    Categorize a 'wrong_result_manual_review' error into a specific type.
    
    Returns:
        (category, reason) tuple
    """
    pred_lower = pred_sql.lower()
    gold_lower = gold_sql.lower()
    
    # 1. Check for missing WHERE clause
    if "where" in gold_lower and "where" not in pred_lower:
        return ("missing_where_clause", "Gold has WHERE, predicted doesn't")
    
    # 2. Check for extra WHERE clause
    if "where" not in gold_lower and "where" in pred_lower:
        return ("extra_where_clause", "Predicted has WHERE, gold doesn't")
    
    # 3. Check for different WHERE conditions
    if "where" in gold_lower and "where" in pred_lower:
        pred_where = extract_where_conditions(pred_sql)
        gold_where = extract_where_conditions(gold_sql)
        if pred_where != gold_where:
            return ("wrong_where_condition", f"WHERE differs: '{pred_where}' vs '{gold_where}'")
    
    # 4. Check for missing JOIN
    if "join" in gold_lower and "join" not in pred_lower:
        return ("missing_join", "Gold has JOIN, predicted doesn't")
    
    # 5. Check for extra JOIN
    if "join" not in gold_lower and "join" in pred_lower:
        return ("extra_join", "Predicted has JOIN, gold doesn't")
    
    # 6. Check for different JOIN conditions
    if "join" in gold_lower and "join" in pred_lower:
        pred_joins = extract_join_conditions(pred_sql)
        gold_joins = extract_join_conditions(gold_sql)
        if pred_joins != gold_joins:
            return ("wrong_join_condition", f"JOIN conditions differ")
    
    # 7. Check for different tables used
    pred_tables = extract_table_names(pred_sql)
    gold_tables = extract_table_names(gold_sql)
    if pred_tables != gold_tables:
        missing = gold_tables - pred_tables
        extra = pred_tables - gold_tables
        if missing:
            return ("missing_table", f"Missing tables: {missing}")
        if extra:
            return ("extra_table", f"Extra tables: {extra}")
    
    # 8. Check for wrong columns selected
    pred_cols = extract_select_columns(pred_sql)
    gold_cols = extract_select_columns(gold_sql)
    if pred_cols != gold_cols:
        return ("wrong_columns_selected", f"SELECT differs: {len(pred_cols)} vs {len(gold_cols)} columns")
    
    # 9. Check for missing GROUP BY
    if "group by" in gold_lower and "group by" not in pred_lower:
        return ("missing_group_by", "Gold has GROUP BY, predicted doesn't")
    
    # 10. Check for extra GROUP BY
    if "group by" not in gold_lower and "group by" in pred_lower:
        return ("extra_group_by", "Predicted has GROUP BY, gold doesn't")
    
    # 11. Check for different GROUP BY columns
    if "group by" in gold_lower and "group by" in pred_lower:
        pred_group = extract_group_by_columns(pred_sql)
        gold_group = extract_group_by_columns(gold_sql)
        if pred_group != gold_group:
            return ("wrong_group_by_columns", f"GROUP BY differs")
    
    # 12. Check for different aggregation functions
    pred_aggs = extract_aggregation_functions(pred_sql)
    gold_aggs = extract_aggregation_functions(gold_sql)
    if pred_aggs != gold_aggs:
        missing_aggs = gold_aggs - pred_aggs
        extra_aggs = pred_aggs - gold_aggs
        if missing_aggs or extra_aggs:
            return ("wrong_aggregation_function", f"Aggs differ: {missing_aggs} missing, {extra_aggs} extra")
    
    # 13. Check for missing DISTINCT
    if "distinct" in gold_lower and "distinct" not in pred_lower:
        return ("missing_distinct", "Gold has DISTINCT, predicted doesn't")
    
    # 14. Check for extra DISTINCT
    if "distinct" not in gold_lower and "distinct" in pred_lower:
        return ("extra_distinct", "Predicted has DISTINCT, gold doesn't")
    
    # 15. Check for missing ORDER BY
    if "order by" in gold_lower and "order by" not in pred_lower:
        return ("missing_order_by", "Gold has ORDER BY, predicted doesn't")
    
    # 16. Check for missing LIMIT
    if "limit" in gold_lower and "limit" not in pred_lower:
        return ("missing_limit", "Gold has LIMIT, predicted doesn't")
    
    # 17. Check for missing SUBSTR (date extraction)
    if "substr" in gold_lower and "substr" not in pred_lower:
        return ("missing_substr_date_extraction", "Gold uses SUBSTR for date, predicted doesn't")
    
    # 18. Check for different SUBSTR usage
    if "substr" in gold_lower and "substr" in pred_lower:
        pred_substrings = re.findall(r'substr\([^)]+\)', pred_lower)
        gold_substrings = re.findall(r'substr\([^)]+\)', gold_lower)
        if pred_substrings != gold_substrings:
            return ("wrong_substr_usage", "SUBSTR usage differs")
    
    # Default
    return ("unknown_logical_error", "Could not determine specific error type")


def analyze_hallucinated_tables(hallucinated_list, schema_tables):
    """
    Analyze patterns in hallucinated table names.
    
    Returns:
        Dictionary with analysis results
    """
    if not hallucinated_list:
        return {}
    
    analysis = {
        "hallucinated_names": [],
        "possible_matches": [],
        "patterns": defaultdict(int)
    }
    
    for item in hallucinated_list:
        if item.get("type") == "table":
            hallucinated_name = item.get("name", "")
            analysis["hallucinated_names"].append(hallucinated_name)
            
            # Find similar table names (fuzzy matching)
            for schema_table in schema_tables:
                # Check for substring matches
                if hallucinated_name in schema_table or schema_table in hallucinated_name:
                    analysis["possible_matches"].append({
                        "hallucinated": hallucinated_name,
                        "possible_match": schema_table,
                        "reason": "substring_match"
                    })
                
                # Check for singular/plural mismatch
                if hallucinated_name.rstrip('s') == schema_table or hallucinated_name == schema_table.rstrip('s'):
                    analysis["possible_matches"].append({
                        "hallucinated": hallucinated_name,
                        "possible_match": schema_table,
                        "reason": "singular_plural_mismatch"
                    })
            
            # Categorize the hallucination pattern
            if len(hallucinated_name) > 20:
                analysis["patterns"]["very_long_name"] += 1
            elif "_" in hallucinated_name and hallucinated_name.count("_") > 2:
                analysis["patterns"]["many_underscores"] += 1
            elif hallucinated_name.startswith("temp_") or hallucinated_name.startswith("tmp_"):
                analysis["patterns"]["temp_prefix"] += 1
            else:
                analysis["patterns"]["other"] += 1
    
    return analysis


def main():
    if len(sys.argv) < 2:
        print("Usage: python enhanced_error_analysis.py <path_to_error_analysis.json>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    # Load the error analysis results
    with open(input_file, 'r') as f:
        data = json.load(f)
    
    results = data.get("results", [])
    
    # Categorize errors
    error_categories = defaultdict(list)
    hallucination_analysis = defaultdict(int)
    
    for result in results:
        error_type = result.get("error_type", "")
        
        # For "wrong_result_manual_review" errors, do deeper analysis
        if error_type == "wrong_result_manual_review":
            pred_sql = result.get("predicted_sql", "")
            gold_sql = result.get("gold_sql", "")
            
            category, reason = categorize_wrong_result_error(pred_sql, gold_sql)
            error_categories[category].append({
                "question_id": result.get("question_id"),
                "reason": reason,
                "predicted_sql": pred_sql[:100] + "..." if len(pred_sql) > 100 else pred_sql,
                "gold_sql": gold_sql[:100] + "..." if len(gold_sql) > 100 else gold_sql
            })
        
        # For hallucinated errors, analyze patterns
        if error_type == "hallucinated_table":
            hallucinated = result.get("hallucinated", [])
            for item in hallucinated:
                if item.get("type") == "table":
                    hallucination_analysis[item.get("name", "unknown")] += 1
    
    # Print summary
    print("\n" + "="*80)
    print("ENHANCED ERROR ANALYSIS SUMMARY")
    print("="*80)
    
    print("\n1. WRONG RESULT MANUAL REVIEW - DETAILED BREAKDOWN")
    print("-" * 80)
    
    total_wrong_result = sum(len(v) for v in error_categories.values())
    print(f"Total 'wrong_result_manual_review' errors: {total_wrong_result}\n")
    
    for category in sorted(error_categories.keys(), key=lambda x: -len(error_categories[x])):
        count = len(error_categories[category])
        percentage = (count / total_wrong_result * 100) if total_wrong_result > 0 else 0
        print(f"{category:<40} {count:3d} ({percentage:5.1f}%)")
    
    print("\n2. TOP HALLUCINATED TABLE NAMES")
    print("-" * 80)
    
    sorted_hallucinations = sorted(hallucination_analysis.items(), key=lambda x: -x[1])
    for table_name, count in sorted_hallucinations[:20]:
        print(f"  {table_name:<40} {count:3d} times")
    
    print("\n3. DETAILED ERROR EXAMPLES")
    print("-" * 80)
    
    for category in sorted(error_categories.keys(), key=lambda x: -len(error_categories[x]))[:5]:
        print(f"\n{category} ({len(error_categories[category])} errors):")
        for example in error_categories[category][:3]:
            print(f"  Q{example['question_id']}: {example['reason']}")
            print(f"    Predicted: {example['predicted_sql']}")
            print(f"    Gold:      {example['gold_sql']}")
    
    # Save detailed report
    output_file = Path(input_file).parent / "enhanced_error_analysis.json"
    report = {
        "summary": {
            "total_wrong_result_errors": total_wrong_result,
            "error_categories": {k: len(v) for k, v in error_categories.items()},
            "hallucinated_tables": dict(sorted_hallucinations)
        },
        "detailed_errors": {k: v for k, v in error_categories.items()},
        "hallucination_patterns": dict(hallucination_analysis)
    }
    
    with open(output_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\n\nDetailed report saved to: {output_file}")
    print("="*80)


if __name__ == "__main__":
    main()