#!/usr/bin/env sh
# Execution accuracy (EX): run predicted SQL and gold SQL on each DB; score 1 if result sets match.
# Run from repo root: sh evaluation/run_mini_dev_sqlite_ex.sh
# Or from evaluation/: sh run_mini_dev_sqlite_ex.sh

cd "$(dirname "$0")" || exit 1

PRED="${1:-../llm/exp_result/turbo_output_kg/predict_mini_dev_openai__gpt-5-2_SQLite.json}"
GOLD="../mini_dev_data/mini_dev_sqlite_gold.sql"
DIFF="../mini_dev_data/mini_dev_sqlite_eval.jsonl"
DB="../mini_dev_data/dev_databases/"
OUT="../eval_result/$(basename "$PRED" .json)_ex.txt"
NUM_CPUS="${NUM_CPUS:-8}"
TIMEOUT="${TIMEOUT:-30.0}"

mkdir -p ../eval_result

echo "Predictions: $PRED"
echo "Gold SQL:    $GOLD"
echo "Difficulty:  $DIFF"
echo "DB root:     $DB"
echo "Log:         $OUT"

# Requires: pip install func-timeout  (and deps from requirements.txt)
python3 -u ./evaluation_ex.py \
  --db_root_path "$DB" \
  --predicted_sql_path "$PRED" \
  --ground_truth_path "$GOLD" \
  --diff_json_path "$DIFF" \
  --num_cpus "$NUM_CPUS" \
  --meta_time_out "$TIMEOUT" \
  --sql_dialect SQLite \
  --output_log_path "$OUT"

echo "Done. See $OUT"
