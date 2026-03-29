eval_path='../mini_dev_data/mini_dev_sqlite.json'
dev_path='./output/'
# SQLite DBs from README: ./mini_dev_data/dev_databases/<db_id>/<db_id>.sqlite
db_root_path='../mini_dev_data/dev_databases'
use_knowledge='True'
mode='mini_dev' # dev, train, mini_dev
cot='True'

# API key: AIML (AI/ML API) takes precedence, else OpenAI direct.
YOUR_API_KEY="${AIML_API_KEY:-${OPENAI_API_KEY}}"
# When using AIML only, default to their OpenAI-compatible endpoint unless you set OPENAI_BASE_URL / AIML_API_BASE yourself.
if [ -n "${AIML_API_KEY:-}" ] && [ -z "${OPENAI_BASE_URL:-}" ] && [ -z "${AIML_API_BASE:-}" ]; then
  export OPENAI_BASE_URL="https://api.aimlapi.com/v1"
fi
if [ -z "${YOUR_API_KEY:-}" ]; then
  echo "Error: set AIML_API_KEY or OPENAI_API_KEY in the environment." >&2
  exit 1
fi

# Model id for the API. On AI/ML API (AIML), OpenAI GPT-5.2 is `openai/gpt-5-2` (not `gpt-5.2`).
# Direct OpenAI would use e.g. gpt-5.2 — set OPENAI_BASE_URL to api.openai.com if not using AIML.
engine='openai/gpt-5-2'

# Choose the number of threads to run in parallel, 1 for single thread
num_threads=3

# Choose the SQL dialect to run, e.g. SQLite, MySQL, PostgreSQL
# PLEASE NOTE: You have to setup the database information in table_schema.py 
# if you want to run the evaluation script using MySQL or PostgreSQL
sql_dialect='SQLite'

# Choose the output path for the generated SQL queries
data_output_path='./exp_result/turbo_output/'
data_kg_output_path='./exp_result/turbo_output_kg/'

echo "generate $engine batch, run in $num_threads threads, with knowledge: $use_knowledge, with chain of thought: $cot"
# Requires AIML_API_KEY or OPENAI_API_KEY in the environment.
# Use `python` (not `python3`) so conda/env active in your shell picks the same interpreter as `pip install`.
python -u ./src/gpt_request.py --db_root_path ${db_root_path} --api_key ${YOUR_API_KEY} --mode ${mode} \
--engine ${engine} --eval_path ${eval_path} --data_output_path ${data_kg_output_path} --use_knowledge ${use_knowledge} \
--chain_of_thought ${cot} --num_processes ${num_threads} --sql_dialect ${sql_dialect}