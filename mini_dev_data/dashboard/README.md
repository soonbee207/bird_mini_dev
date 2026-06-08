# Mini-Dev failure review (Streamlit)

Interactive dashboard for EX-annotated runs: gold vs predicted SQL, auto categories, filters, optional SQLite result previews.

## Local run

From repo root:

```bash
pip install -r mini_dev_data/dashboard/requirements.txt
streamlit run mini_dev_data/dashboard/streamlit_app.py
```

Default data: `mini_dev_data/merged_analysis_v3_8steps_ex_annotated.json`

SQL previews require `mini_dev_data/dev_databases/` (enable in sidebar).

## Share with others (Streamlit Community Cloud)

1. Push repo to GitHub (use a **private** repo if the dataset should not be public).
2. Go to [share.streamlit.io](https://share.streamlit.io) → **New app**.
3. **Main file path:** `mini_dev_data/dashboard/streamlit_app.py`
4. **Requirements:** `mini_dev_data/dashboard/requirements.txt`
5. Deploy and share the URL.

**Note:** On Cloud, local SQLite DBs are usually unavailable — leave **Run SQL previews** unchecked unless you ship `dev_databases` (large) or precompute previews in JSON.

## Regenerate underlying data

After a new predict run:

```bash
cd mini_dev_data/exports
python3 build_merged_analysis_from_predict.py --predict-json <predict.json> -o ../merged_analysis_v4.json
cd ../../evaluation
python3 dump_ex_annotated_merged.py --merged-json ../mini_dev_data/merged_analysis_v4.json \
  --db-root ../mini_dev_data/dev_databases -o ../mini_dev_data/merged_analysis_v4_ex_annotated.json
```

Point the sidebar **Annotated JSON path** at the new file (or change the default in `dashboard_data.py`).

## HTML alternative

Static export (no server): `mini_dev_data/exports/build_failure_dashboard_html.py`
