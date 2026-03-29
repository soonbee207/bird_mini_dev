#!/usr/bin/env python3
import argparse
import json
import os
from openai import OpenAI
from tqdm import tqdm
import time
from concurrent.futures import ThreadPoolExecutor
import concurrent.futures

from prompt import generate_combined_prompts_one


def new_directory(path):
    if not os.path.exists(path):
        os.makedirs(path)


def _uses_new_chat_params(engine: str) -> bool:
    """GPT-5+ / reasoning-style models use max_completion_tokens; omit legacy-only args."""
    e = (engine or "").lower()
    tail = e.split("/")[-1]
    return (
        tail.startswith("gpt-5")
        or tail.startswith("o1")
        or tail.startswith("o3")
        or tail.startswith("o4")
    )


def _engine_for_output_filename(engine: str) -> str:
    """AIML uses ids like openai/gpt-5-2; strip slashes so output paths are valid."""
    return (engine or "").replace("/", "__")


def connect_gpt(engine, prompt, max_tokens, temperature, stop, client):
    MAX_API_RETRY = 10
    for i in range(MAX_API_RETRY):
        time.sleep(2)
        try:
            messages = [
                {"role": "user", "content": prompt},
            ]

            kwargs = {"model": engine, "messages": messages}
            if _uses_new_chat_params(engine):
                kwargs["max_completion_tokens"] = max_tokens
            else:
                kwargs["max_tokens"] = max_tokens
                kwargs["temperature"] = temperature
            if stop:
                kwargs["stop"] = stop

            response = client.chat.completions.create(**kwargs)

            result = response.choices[0].message.content
            break

        except Exception as e:
            result = f"error:{e}"
            print(result)
            time.sleep(4)

    return result


def decouple_question_schema(datasets, db_root_path):
    question_list = []
    db_path_list = []
    knowledge_list = []

    for data in datasets:
        question_list.append(data["question"])
        cur_db_path = db_root_path + "/" + data["db_id"] + "/" + data["db_id"] + ".sqlite"
        db_path_list.append(cur_db_path)
        knowledge_list.append(data["evidence"])

    return question_list, db_path_list, knowledge_list


def generate_sql_file(sql_lst, output_path=None):
    sql_lst.sort(key=lambda x: x[1])
    result = {}

    for i, (sql, _) in enumerate(sql_lst):
        result[i] = sql

    if output_path:
        directory_path = os.path.dirname(output_path)
        new_directory(directory_path)
        json.dump(result, open(output_path, "w"), indent=4)

    return result


def init_client(api_key):
    base_url = os.environ.get("OPENAI_BASE_URL") or os.environ.get("AIML_API_BASE")
    if base_url:
        return OpenAI(api_key=api_key, base_url=base_url)
    return OpenAI(api_key=api_key)


def post_process_response(response, db_path):
    sql = response
    db_id = db_path.split("/")[-1].split(".sqlite")[0]
    sql = f"{sql}\t----- bird -----\t{db_id}"
    return sql


def worker_function(question_data):
    prompt, engine, client, db_path, question, i = question_data

    response = connect_gpt(engine, prompt, 512, 0, ["--", "\n\n", ";", "#"], client)
    sql = post_process_response(response, db_path)

    print(f"Processed {i}th question")

    return sql, i


def collect_response_from_gpt(
    db_path_list,
    question_list,
    api_key,
    engine,
    sql_dialect,
    num_threads=3,
    knowledge_list=None,
):

    client = init_client(api_key)

    tasks = [
        (
            generate_combined_prompts_one(
                db_path=db_path_list[i],
                question=question_list[i],
                sql_dialect=sql_dialect,
                knowledge=knowledge_list[i] if knowledge_list else None,
            ),
            engine,
            client,
            db_path_list[i],
            question_list[i],
            i,
        )
        for i in range(len(question_list))
    ]

    responses = []

    with ThreadPoolExecutor(max_workers=num_threads) as executor:
        future_to_task = {
            executor.submit(worker_function, task): task for task in tasks
        }

        for future in tqdm(
            concurrent.futures.as_completed(future_to_task), total=len(tasks)
        ):
            responses.append(future.result())

    return responses


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("--eval_path", type=str)
    parser.add_argument("--mode", type=str)
    parser.add_argument("--use_knowledge", type=str)
    parser.add_argument("--db_root_path", type=str)
    parser.add_argument("--api_key", type=str, required=True)
    parser.add_argument("--engine", type=str, required=True)
    parser.add_argument("--data_output_path", type=str)
    parser.add_argument("--chain_of_thought", type=str)
    parser.add_argument("--num_processes", type=int)
    parser.add_argument("--sql_dialect", type=str)

    args = parser.parse_args()

    eval_data = json.load(open(args.eval_path, "r"))

    question_list, db_path_list, knowledge_list = decouple_question_schema(
        eval_data, args.db_root_path
    )

    responses = collect_response_from_gpt(
        db_path_list,
        question_list,
        args.api_key,
        args.engine,
        args.sql_dialect,
        args.num_processes,
        knowledge_list if args.use_knowledge == "True" else None,
    )

    output_name = (
        args.data_output_path
        + f"predict_{args.mode}_{_engine_for_output_filename(args.engine)}_{args.sql_dialect}.json"
    )

    generate_sql_file(responses, output_name)

    print("DONE")