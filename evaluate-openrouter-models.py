#!/usr/bin/env python3
"""Run the local OpenRouter model evaluation."""

import argparse
import html
import itertools
import json
import os
import random
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path


TRACKS = ("polishing", "zh-en", "en-zh")
CASES_PER_TRACK = 20
RUNS_PER_CASE = 3
HARD_COST_LIMIT = Decimal("4.00")
MAX_OUTPUT_TOKENS = 1024
OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_ENDPOINTS_URL = "https://openrouter.ai/api/v1/models/{model}/endpoints"
VERSION = "1.0"
DIAGNOSTIC_KEYS = {"kind", "message", "text", "range", "suggestions"}
DIAGNOSTIC_KINDS = {"spelling", "grammar", "style", "other"}
MODEL_PRICES = {
    "openai/gpt-5.6-terra": (Decimal("0.000002"), Decimal("0.000012")),
    "google/gemini-3.7-flash": (Decimal("0.000000375"), Decimal("0.000001875")),
    "tencent/hy-mt2-30b-a3b": (Decimal("0.000000074"), Decimal("0.000000295")),
}
PROOFREAD_SCHEMA = {
    "type": "object",
    "properties": {
        "diagnostics": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": sorted(DIAGNOSTIC_KINDS)},
                    "message": {"type": "string"},
                    "text": {"type": "string"},
                    "range": {
                        "type": "object",
                        "properties": {
                            "beg": {"type": "integer"},
                            "end": {"type": "integer"},
                        },
                        "required": ["beg", "end"],
                        "additionalProperties": False,
                    },
                    "suggestions": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["kind", "message", "text", "range", "suggestions"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["diagnostics"],
    "additionalProperties": False,
}
TRANSLATION_SCHEMA = {
    "type": "object",
    "properties": {"translation": {"type": "string"}},
    "required": ["translation"],
    "additionalProperties": False,
}
MODELS = {
    "openai/gpt-5.6-terra": {"provider": "openai", "reasoning": "none"},
    "google/gemini-3.7-flash": {
        "provider": "google-vertex/global",
        "reasoning": "low",
    },
    "tencent/hy-mt2-30b-a3b": {"provider": "tencent/fp8", "reasoning": None},
}
MODELS_BY_TRACK = {
    "polishing": ("openai/gpt-5.6-terra", "google/gemini-3.7-flash"),
    "zh-en": tuple(MODELS),
    "en-zh": tuple(MODELS),
}
CRITERIA = {
    "polishing": ("issue_detection", "naturalness", "meaning", "restraint"),
    "zh-en": ("meaning", "terminology", "naturalness", "register", "format"),
    "en-zh": ("meaning", "terminology", "naturalness", "register", "format"),
}
POLISHING_INSTRUCTIONS = """Return proofreading diagnostics that match the requested response schema.  Do not include Markdown, comments, prose, or reasoning outside the structured response.
The top-level response has a diagnostics array.  Each diagnostic has kind, message, text, range, and suggestions fields.
Report every independent problem in Text.  Do not stop after the first problem in a sentence; when one sentence has multiple misspellings, grammar issues, or style issues, return one diagnostic per issue.
Prefer the smallest exact text range that identifies each issue, and keep diagnostics separate unless one correction requires a single combined range.
For Chinese text, also check adjacent characters that may form one misspelled word; a diagnostic may cover multiple adjacent characters.
Report diagnostics only for the Text section.  Use context before and context after only to understand the Text; never return ranges or text from context.
When Target kind is comment or docstring, check only natural-language prose.  Never report comment delimiters, string quotes, indentation, program code, or markup as proofreading problems.
Use zero-based chunk-relative offsets; range end is exclusive.
The text field must exactly equal the substring selected by range.
Use kind values spelling, grammar, style, or other.
For suggestions, return practical replacement text in best-first order.  Include multiple suggestions when several distinct corrections are useful; one suggestion or an empty suggestions array is acceptable when there is no real alternative.
Use an empty diagnostics array when there are no diagnostics."""


def build_prompt(case: dict) -> str:
    if case["track"] == "polishing":
        language = case.get("language", "English")
        return f"""Proofread the following text.

{POLISHING_INSTRUCTIONS}

Language: {json.dumps(language, ensure_ascii=False)}
Major mode: {case.get('major_mode', 'text-mode')}
Target kind: {case.get('target_kind', 'prose')}

Context before:
{case.get('context_before', '')}

Text:
{case['text']}

Context after:
{case.get('context_after', '')}
"""
    target = "natural international English with US spelling" if case["track"] == "zh-en" else "Simplified Chinese"
    requirements = case.get("requirements", [])
    requirement_text = "\n".join(f"- {item}" for item in requirements)
    if requirement_text:
        requirement_text = f"\nRequirements:\n{requirement_text}\n"
    return f"""Translate the source text into {target}.
Preserve meaning, register, terminology, markup, names, numbers, and formatting.
Return only the structured translation response.{requirement_text}
Source text:
{case['text']}"""


def build_jobs(cases: list[dict]) -> list[dict]:
    jobs = []
    for case in cases:
        prompt = build_prompt(case)
        for model in MODELS_BY_TRACK[case["track"]]:
            for run_number in range(1, RUNS_PER_CASE + 1):
                jobs.append(
                    {
                        "key": f"{case['id']}::{model}::{run_number}",
                        "case": case,
                        "model": model,
                        "run": run_number,
                        "prompt": prompt,
                        "reserved_cost": str(reserve_cost(model, prompt)),
                    }
                )
    return jobs


def smoke_jobs(cases: list[dict]) -> list[dict]:
    first_case_ids = {}
    for case in cases:
        first_case_ids.setdefault(case["track"], case["id"])
    return [
        job
        for job in build_jobs(cases)
        if job["run"] == 1 and job["case"]["id"] == first_case_ids[job["case"]["track"]]
    ]


def build_request(job: dict) -> dict:
    track = job["case"]["track"]
    schema = PROOFREAD_SCHEMA if track == "polishing" else TRANSLATION_SCHEMA
    schema_name = "proofread_diagnostics" if track == "polishing" else "translation"
    model = job["model"]
    request = {
        "model": model,
        "messages": [{"role": "user", "content": job["prompt"]}],
        "max_tokens": MAX_OUTPUT_TOKENS,
        "stream": False,
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": schema_name, "strict": True, "schema": schema},
        },
        "provider": {
            "order": [MODELS[model]["provider"]],
            "allow_fallbacks": False,
            "require_parameters": True,
        },
    }
    reasoning = MODELS[model]["reasoning"]
    if reasoning is not None:
        request["reasoning"] = {"effort": reasoning, "exclude": True}
    return request


def append_jsonl(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")
        stream.flush()
        os.fsync(stream.fileno())


def write_json_atomic(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def post_openrouter(request_body: dict, api_key: str) -> dict:
    request = urllib.request.Request(
        OPENROUTER_CHAT_URL,
        data=json.dumps(request_body, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "X-OpenRouter-Metadata": "enabled",
        },
        method="POST",
    )
    for attempt in range(2):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            retryable = error.code in {408, 429} or error.code >= 500
            if retryable and attempt == 0:
                time.sleep(1)
                continue
            try:
                detail = json.loads(error.read().decode("utf-8")).get("error", {}).get("message")
            except (UnicodeDecodeError, json.JSONDecodeError, AttributeError):
                detail = None
            raise RuntimeError(
                f"OpenRouter HTTP {error.code}" + (f": {detail}" if detail else "")
            ) from error
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt == 0:
                time.sleep(1)
                continue
            raise RuntimeError("OpenRouter request failed after one retry") from error
    raise AssertionError("unreachable")


def verify_endpoints(models: set[str]) -> dict:
    prices = {}
    for model in sorted(models):
        url = OPENROUTER_ENDPOINTS_URL.format(model=model)
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                endpoints = json.load(response)["data"]["endpoints"]
        except (OSError, KeyError, json.JSONDecodeError) as error:
            raise RuntimeError(f"cannot read OpenRouter endpoints for {model}") from error
        provider = MODELS[model]["provider"]
        endpoint = next((item for item in endpoints if item.get("tag") == provider), None)
        if not endpoint:
            raise RuntimeError(f"provider {provider} is unavailable for {model}")
        supported = set(endpoint.get("supported_parameters", ()))
        if not {"response_format", "structured_outputs"} <= supported:
            raise RuntimeError(f"provider {provider} lacks structured output for {model}")
        try:
            prices[model] = (
                Decimal(endpoint["pricing"]["prompt"]),
                Decimal(endpoint["pricing"]["completion"]),
            )
        except (KeyError, TypeError) as error:
            raise RuntimeError(f"provider {provider} has no usable price for {model}") from error
    return prices


def read_openrouter_key() -> str:
    expression = """(progn
  (require 'auth-source)
  (let ((key (auth-source-pick-first-password :host \"openrouter.ai\")))
    (unless key (kill-emacs 3))
    (princ key)))"""
    try:
        result = subprocess.run(
            [os.environ.get("EMACS", "emacs"), "-Q", "--batch", "--eval", expression],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("cannot read the OpenRouter auth-source entry") from error
    key = result.stdout.strip()
    if result.returncode or not key:
        raise RuntimeError("cannot read the OpenRouter auth-source entry")
    return key


def execute_job(job: dict, api_key: str, post=post_openrouter) -> dict:
    started = time.monotonic()
    api_response = post(build_request(job), api_key)
    try:
        content = api_response["choices"][0]["message"]["content"]
        if not isinstance(content, str):
            raise TypeError("content is not a string")
    except (KeyError, IndexError, TypeError) as error:
        raise RuntimeError("OpenRouter response has no message content") from error
    try:
        parsed = validate_structured_response(job["case"]["track"], content, job["case"]["text"])
        valid, validation_error = True, None
    except ValueError as error:
        parsed, valid, validation_error = None, False, str(error)
    usage = api_response.get("usage") or {}
    cost = Decimal(str(usage.get("cost", 0)))
    return {
        "key": job["key"],
        "case_id": job["case"]["id"],
        "track": job["case"]["track"],
        "model": job["model"],
        "provider": MODELS[job["model"]]["provider"],
        "run": job["run"],
        "valid": valid,
        "validation_error": validation_error,
        "parsed": parsed,
        "latency_seconds": round(time.monotonic() - started, 3),
        "cost": str(cost),
        "usage": usage,
        "service_tier": api_response.get("service_tier"),
        "openrouter_metadata": api_response.get("openrouter_metadata"),
        "response": api_response,
    }


def run_jobs(
    run_directory: Path,
    manifest: dict,
    jobs: list[dict],
    api_key: str,
    *,
    post=post_openrouter,
    cost_limit: Decimal = HARD_COST_LIMIT,
    time_limit_seconds: int = 1800,
) -> dict:
    responses_path = run_directory / "responses.jsonl"
    failures_path = run_directory / "failures.jsonl"
    responses = read_jsonl(responses_path)
    failures = read_jsonl(failures_path)
    completed = {item["key"] for item in responses + failures}
    pending = [job for job in jobs if job["key"] not in completed]
    spent = sum((Decimal(item.get("cost", "0")) for item in responses + failures), Decimal())
    deadline = time.monotonic() + time_limit_seconds
    stopped_reason = None
    next_job = 0
    in_flight = {}
    with ThreadPoolExecutor(max_workers=4) as executor:
        while next_job < len(pending) or in_flight:
            while next_job < len(pending) and len(in_flight) < 4:
                if time.monotonic() >= deadline:
                    stopped_reason = "time_limit"
                    next_job = len(pending)
                    break
                job = pending[next_job]
                reserved_in_flight = sum(
                    (Decimal(item["reserved_cost"]) for item in in_flight.values()), Decimal()
                )
                if spent + reserved_in_flight + Decimal(job["reserved_cost"]) > cost_limit:
                    stopped_reason = "cost_limit"
                    next_job = len(pending)
                    break
                in_flight[executor.submit(execute_job, job, api_key, post)] = job
                next_job += 1
            if not in_flight:
                break
            done, _ = wait(in_flight, return_when=FIRST_COMPLETED)
            for future in done:
                job = in_flight.pop(future)
                try:
                    result = future.result()
                except RuntimeError as error:
                    result = {
                        "key": job["key"],
                        "case_id": job["case"]["id"],
                        "track": job["case"]["track"],
                        "model": job["model"],
                        "provider": MODELS[job["model"]]["provider"],
                        "run": job["run"],
                        "cost": "0",
                        "error": str(error),
                    }
                    append_jsonl(failures_path, result)
                    failures.append(result)
                else:
                    append_jsonl(responses_path, result)
                    responses.append(result)
                spent += Decimal(result["cost"])
                manifest.update(
                    {
                        "spent_cost": str(spent),
                        "completed_requests": len(responses) + len(failures),
                        "stopped_reason": stopped_reason,
                    }
                )
                write_json_atomic(run_directory / "manifest.json", manifest)
    manifest["stopped_reason"] = stopped_reason
    write_json_atomic(run_directory / "manifest.json", manifest)
    return {"responses": responses, "failures": failures, "manifest": manifest}


def display_output(response: dict) -> str:
    return json.dumps(response["parsed"], ensure_ascii=False, indent=2)


def build_review_data(cases: list[dict], responses: list[dict], seed: int) -> tuple[dict, list]:
    by_case_model = {}
    for response in responses:
        if response.get("valid"):
            by_case_model.setdefault((response["case_id"], response["model"]), []).append(response)
    randomizer = random.Random(seed)
    private_comparisons = []
    public_comparisons = []
    comparison_number = 0
    for case in cases:
        selected = {}
        for model in MODELS_BY_TRACK[case["track"]]:
            options = by_case_model.get((case["id"], model), [])
            if options:
                selected[model] = randomizer.choice(sorted(options, key=lambda item: item["run"]))
        for first_model, second_model in itertools.combinations(selected, 2):
            comparison_number += 1
            first, second = selected[first_model], selected[second_model]
            if randomizer.choice((False, True)):
                first_model, second_model = second_model, first_model
                first, second = second, first
            identifier = f"comparison-{comparison_number:04d}"
            private_comparisons.append(
                {
                    "id": identifier,
                    "track": case["track"],
                    "case_id": case["id"],
                    "a_model": first_model,
                    "b_model": second_model,
                    "criteria": list(CRITERIA[case["track"]]),
                }
            )
            public_comparisons.append(
                {
                    "id": identifier,
                    "track": case["track"],
                    "source": case["text"],
                    "requirements": case.get("requirements", []),
                    "a": display_output(first),
                    "b": display_output(second),
                    "criteria": list(CRITERIA[case["track"]]),
                }
            )
    return {"seed": seed, "comparisons": private_comparisons}, public_comparisons


def print_plan(jobs: list[dict]) -> None:
    maximum = sum((Decimal(job["reserved_cost"]) for job in jobs), Decimal())
    print(f"Plan: {len(jobs)} requests")
    for track in TRACKS:
        print(f"  {track}: {', '.join(MODELS_BY_TRACK[track])}")
    print(f"maximum reserved cost: US${maximum:.2f}; hard limit: US${HARD_COST_LIMIT:.2f}")


def validate_structured_response(track: str, content: str, source: str) -> dict:
    try:
        value = json.loads(content)
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid JSON: {error.msg}") from error
    if not isinstance(value, dict):
        raise ValueError("response must be an object")
    if track != "polishing":
        if set(value) != {"translation"} or not isinstance(value["translation"], str):
            raise ValueError("translation response must contain only a translation string")
        return value
    if set(value) != {"diagnostics"} or not isinstance(value["diagnostics"], list):
        raise ValueError("polishing response must contain only a diagnostics array")
    for diagnostic in value["diagnostics"]:
        if not isinstance(diagnostic, dict) or set(diagnostic) != DIAGNOSTIC_KEYS:
            raise ValueError("diagnostic fields do not match the schema")
        if diagnostic["kind"] not in DIAGNOSTIC_KINDS:
            raise ValueError("unknown diagnostic kind")
        if not all(isinstance(diagnostic[key], str) for key in ("message", "text")):
            raise ValueError("diagnostic message and text must be strings")
        if not isinstance(diagnostic["suggestions"], list) or not all(
            isinstance(suggestion, str) for suggestion in diagnostic["suggestions"]
        ):
            raise ValueError("diagnostic suggestions must be strings")
        selected_range = diagnostic["range"]
        if not isinstance(selected_range, dict) or set(selected_range) != {"beg", "end"}:
            raise ValueError("diagnostic range fields do not match the schema")
        beg, end = selected_range["beg"], selected_range["end"]
        if (
            not isinstance(beg, int)
            or isinstance(beg, bool)
            or not isinstance(end, int)
            or isinstance(end, bool)
            or not 0 <= beg < end <= len(source)
        ):
            raise ValueError("diagnostic range is outside the source text")
        if diagnostic["text"] != source[beg:end]:
            raise ValueError("diagnostic text does not match its range")
    return value


def reserve_cost(model: str, prompt: str) -> Decimal:
    prompt_price, completion_price = MODEL_PRICES[model]
    prompt_tokens_upper_bound = len(prompt.encode("utf-8"))
    return prompt_price * prompt_tokens_upper_bound + completion_price * MAX_OUTPUT_TOKENS


def reserve_request_cost(job: dict, prices: dict) -> Decimal:
    prompt_price, completion_price = prices[job["model"]]
    request_bytes = len(
        json.dumps(build_request(job), ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    )
    return (
        prompt_price * request_bytes + completion_price * MAX_OUTPUT_TOKENS
    ) * Decimal("1.10")


def pending_job_keys(job_keys: list[str], completed: set[str]) -> list[str]:
    return [key for key in job_keys if key not in completed]


def render_review(comparisons: list[dict], storage_key: str = "model-evaluation-scores") -> str:
    sections = []
    for comparison in comparisons:
        identifier = html.escape(comparison["id"], quote=True)
        source = html.escape(comparison.get("source", ""))
        requirements = html.escape("\n".join(comparison.get("requirements", ())))
        output_a = html.escape(comparison["a"])
        output_b = html.escape(comparison["b"])
        criteria = "".join(
            f"<fieldset><legend>{html.escape(criterion.replace('_', ' ').title())}</legend>"
            f'<label><input type="radio" name="{identifier}::{criterion}" value="a">A</label>'
            f'<label><input type="radio" name="{identifier}::{criterion}" value="b">B</label>'
            f'<label><input type="radio" name="{identifier}::{criterion}" value="tie">Tie</label>'
            "</fieldset>"
            for criterion in comparison.get("criteria", ("overall",))
        )
        sections.append(
            f"""<section data-id="{identifier}">
<h2>{identifier}</h2><h3>Source</h3><pre>{source}</pre>
<h3>Requirements</h3><pre>{requirements}</pre>
<div class="outputs"><div><h3>A</h3><pre>{output_a}</pre></div>
<div><h3>B</h3><pre>{output_b}</pre></div></div>{criteria}
<label><input type="checkbox" name="{identifier}::critical-a">A has a critical error</label>
<label><input type="checkbox" name="{identifier}::critical-b">B has a critical error</label>
</section>"""
        )
    return """<!doctype html><meta charset="utf-8"><title>Blind review</title>
<style>body{font:16px system-ui;max-width:90rem;margin:auto}section{border-top:1px solid #bbb}
pre{white-space:pre-wrap}.outputs{display:grid;grid-template-columns:1fr 1fr;gap:1rem}</style>
<h1>Blind review</h1>""" + "\n".join(sections) + """
<button id="download">Download scores</button><script>
const key={json.dumps(storage_key)};
document.addEventListener('change',()=>localStorage[key]=JSON.stringify(
  [...document.querySelectorAll('input:checked')].map(x=>({name:x.name,value:x.value}))));
for(const x of JSON.parse(localStorage[key]||'[]')){
  const input=document.querySelector(`[name="${CSS.escape(x.name)}"][value="${x.value}"]`);
  if(input)input.checked=true}
download.onclick=()=>{const a=document.createElement('a');
  a.href=URL.createObjectURL(new Blob([localStorage[key]||'[]'],{type:'application/json'}));
  a.download='scores.json';a.click()};
</script>"""


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def summarize_run(run_directory: Path, scores_path: Path) -> dict:
    manifest = json.loads((run_directory / "manifest.json").read_text(encoding="utf-8"))
    review_map = json.loads((run_directory / "review-map.json").read_text(encoding="utf-8"))
    score_items = json.loads(scores_path.read_text(encoding="utf-8"))
    scores = {item["name"]: item["value"] for item in score_items}
    responses = read_jsonl(run_directory / "responses.jsonl")
    expected_by_track_model = {}
    for job in manifest["jobs"]:
        key = (job["case"]["track"], job["model"])
        expected_by_track_model.setdefault(key, set()).add(job["key"])
    valid_keys_by_track_model = {}
    for response in responses:
        if response.get("valid") is True:
            key = (response["track"], response["model"])
            valid_keys_by_track_model.setdefault(key, set()).add(response["key"])
    valid_by_track_model = {
        key: valid_keys_by_track_model.get(key, set()) == expected_keys
        for key, expected_keys in expected_by_track_model.items()
    }
    points = {}
    possible = Counter()
    critical_models = set()
    for comparison in review_map["comparisons"]:
        track = comparison["track"]
        model_a, model_b = comparison["a_model"], comparison["b_model"]
        for model in (model_a, model_b):
            points.setdefault(track, Counter())
            points[track][model] += 0
            possible[(track, model)] += len(comparison["criteria"])
        for criterion in comparison["criteria"]:
            name = f"{comparison['id']}::{criterion}"
            choice = scores.get(name)
            if choice not in {"a", "b", "tie"}:
                raise ValueError(f"missing score for {name}")
            if choice == "a":
                points[track][model_a] += 1
            elif choice == "b":
                points[track][model_b] += 1
            else:
                points[track][model_a] += 0.5
                points[track][model_b] += 0.5
        for side, model in (("a", model_a), ("b", model_b)):
            if scores.get(f"{comparison['id']}::critical-{side}") == "on":
                critical_models.add((track, model))
    summary = {"tracks": {}}
    for track, model_points in points.items():
        ranked = []
        for model, value in model_points.items():
            share = value / possible[(track, model)]
            eligible = valid_by_track_model.get((track, model), False) and (
                track,
                model,
            ) not in critical_models
            ranked.append({"model": model, "share": share, "eligible": eligible})
        ranked.sort(key=lambda item: (item["eligible"], item["share"]), reverse=True)
        eligible = [item for item in ranked if item["eligible"]]
        leader = eligible[0] if eligible else None
        close = len(eligible) > 1 and leader["share"] - eligible[1]["share"] <= 0.05
        summary["tracks"][track] = {"leader": leader, "close": close, "models": ranked}
    (run_directory / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return summary


def self_check() -> None:
    validate_structured_response("zh-en", '{"translation":"Hello"}', "你好")
    validate_structured_response("polishing", '{"diagnostics":[]}', "Correct text.")
    print("validation: ok")
    assert reserve_cost("openai/gpt-5.6-terra", "test") < Decimal("0.02")
    print("budget: ok")
    assert pending_job_keys(["a", "b"], {"a"}) == ["b"]
    print("resume: ok")
    page = render_review([{"id": "case-1", "a": "First", "b": "Second"}])
    assert "Download scores" in page and "openai/" not in page
    print("review: ok")
    job = build_jobs(
        [{"id": "one", "track": "polishing", "text": "Correct text."}]
    )[0]
    request = build_request(job)
    assert request["provider"] == {
        "order": ["openai"],
        "allow_fallbacks": False,
        "require_parameters": True,
    }
    assert request["response_format"]["json_schema"]["strict"] is True
    print("request: ok")
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory)
        append_jsonl(directory / "responses.jsonl", {"key": "one"})
        write_json_atomic(directory / "manifest.json", {"spent": "0"})
        assert read_jsonl(directory / "responses.jsonl") == [{"key": "one"}]
        assert json.loads((directory / "manifest.json").read_text())["spent"] == "0"
    print("persistence: ok")
    fake_response = {
        "choices": [{"message": {"content": '{"diagnostics":[]}'}}],
        "usage": {"cost": 0.001, "prompt_tokens": 10, "completion_tokens": 2},
        "service_tier": "default",
        "openrouter_metadata": {"attempt": 1},
    }
    result = execute_job(job, "hidden", lambda body, key: fake_response)
    assert result["valid"] is True and result["cost"] == "0.001"
    print("execution: ok")
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory)
        calls = []

        def fake_post(body, key):
            calls.append(body["model"])
            return fake_response

        jobs = build_jobs(
            [{"id": "one", "track": "polishing", "text": "Correct text."}]
        )[:2]
        manifest = {"spent_cost": "0", "completed_requests": 0}
        run_jobs(directory, manifest, jobs, "hidden", post=fake_post, cost_limit=Decimal("1"))
        run_jobs(directory, manifest, jobs, "hidden", post=fake_post, cost_limit=Decimal("1"))
        assert len(calls) == 2 and len(read_jsonl(directory / "responses.jsonl")) == 2
    print("orchestration: ok")


def load_cases(paths: list[Path]) -> list[dict]:
    cases = []
    for path in paths:
        if not path.exists():
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            try:
                case = json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {error.msg}") from error
            if not isinstance(case, dict):
                raise ValueError(f"{path}:{line_number}: case must be an object")
            for key in ("id", "track", "text"):
                if not isinstance(case.get(key), str) or not case[key].strip():
                    raise ValueError(f"{path}:{line_number}: {key} must be a non-empty string")
            if case["track"] not in TRACKS:
                raise ValueError(f"{path}:{line_number}: unknown track {case['track']!r}")
            common_fields = {"id", "track", "text", "review_notes"}
            polishing_fields = {
                "language",
                "major_mode",
                "target_kind",
                "context_before",
                "context_after",
            }
            allowed_fields = common_fields | (
                polishing_fields if case["track"] == "polishing" else {"requirements"}
            )
            unknown_fields = sorted(set(case) - allowed_fields)
            if unknown_fields:
                raise ValueError(f"unknown case fields: {', '.join(unknown_fields)}")
            string_fields = (polishing_fields | {"review_notes"}) & set(case)
            if any(not isinstance(case[key], str) for key in string_fields):
                raise ValueError(f"{path}:{line_number}: optional text fields must be strings")
            requirements = case.get("requirements", [])
            if not isinstance(requirements, list) or not all(
                isinstance(requirement, str) and requirement.strip()
                for requirement in requirements
            ):
                raise ValueError(f"{path}:{line_number}: requirements must be non-empty strings")
            cases.append(case)
    if len({case["id"] for case in cases}) != len(cases):
        raise ValueError("case ids must be unique")
    counts = Counter(case["track"] for case in cases)
    if any(counts[track] != CASES_PER_TRACK for track in TRACKS):
        raise ValueError("need 20 cases for each track")
    return cases


def write_review_files(run_directory: Path, cases: list[dict], responses: list[dict], seed: int) -> int:
    review_map, public_comparisons = build_review_data(cases, responses, seed)
    write_json_atomic(run_directory / "review-map.json", review_map)
    (run_directory / "review.html").write_text(
        render_review(public_comparisons, f"model-evaluation-{seed}"), encoding="utf-8"
    )
    return len(public_comparisons)


def paid_run(
    *,
    cases: list[dict],
    jobs: list[dict],
    run_directory: Path,
    manifest: dict | None,
) -> dict:
    prices = verify_endpoints({job["model"] for job in jobs})
    for job in jobs:
        job["reserved_cost"] = str(reserve_request_cost(job, prices))
    maximum = sum((Decimal(job["reserved_cost"]) for job in jobs), Decimal())
    print(f"verified maximum reserved cost: US${maximum:.2f}")
    api_key = read_openrouter_key()
    if manifest is None:
        if run_directory.exists() and any(run_directory.iterdir()):
            raise ValueError(f"run directory is not empty: {run_directory}")
        seed = secrets.randbits(63)
        random.Random(seed).shuffle(jobs)
        manifest = {
            "version": 1,
            "created_at": datetime.now(UTC).isoformat(),
            "seed": seed,
            "cost_limit": str(HARD_COST_LIMIT),
            "time_limit_seconds": 1800,
            "cases": cases,
            "jobs": jobs,
            "providers": {model: settings["provider"] for model, settings in MODELS.items()},
            "prices": {
                model: {"prompt": str(price[0]), "completion": str(price[1])}
                for model, price in prices.items()
            },
            "spent_cost": "0",
            "completed_requests": 0,
        }
        write_json_atomic(run_directory / "manifest.json", manifest)
    else:
        manifest["jobs"] = jobs
        manifest["prices"] = {
            model: {"prompt": str(price[0]), "completion": str(price[1])}
            for model, price in prices.items()
        }
        write_json_atomic(run_directory / "manifest.json", manifest)
    result = run_jobs(run_directory, manifest, jobs, api_key)
    comparison_count = write_review_files(
        run_directory, cases, result["responses"], manifest["seed"]
    )
    print(
        f"saved {len(result['responses'])} responses, {len(result['failures'])} failures, "
        f"and {comparison_count} blind comparisons to {run_directory}"
    )
    print(f"spent: US${Decimal(result['manifest']['spent_cost']):.4f}")
    if result["manifest"].get("stopped_reason"):
        print(f"stopped: {result['manifest']['stopped_reason']}")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare OpenRouter models for proofreading and translation.",
        epilog=(
            "examples:\n"
            "  evaluate-openrouter-models.py self-check\n"
            "  evaluate-openrouter-models.py run --smoke\n"
            "  evaluate-openrouter-models.py run\n"
            "  evaluate-openrouter-models.py summarize RUN_DIR --scores scores.json"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("self-check", help="run offline checks")
    run_parser = commands.add_parser("run", help="run or resume a paid evaluation")
    run_parser.add_argument(
        "--public-cases",
        type=Path,
        default=Path("docs/research/model-evaluation-cases.jsonl"),
        help="tracked synthetic JSONL cases (default: %(default)s)",
    )
    run_parser.add_argument(
        "--private-cases",
        type=Path,
        default=Path(".model-evaluation/cases.local.jsonl"),
        help="gitignored real JSONL cases (default: %(default)s)",
    )
    destination = run_parser.add_mutually_exclusive_group()
    destination.add_argument("--output", type=Path, help="directory for a new run")
    destination.add_argument("--resume", type=Path, help="existing run directory to resume")
    run_parser.add_argument("--smoke", action="store_true", help="run eight smoke requests")
    run_parser.add_argument(
        "--yes", action="store_true", help="confirm paid requests without prompting"
    )
    run_parser.add_argument(
        "--no-input", action="store_true", help="fail instead of prompting"
    )
    summarize_parser = commands.add_parser(
        "summarize", help="score a completed anonymous review"
    )
    summarize_parser.add_argument("run_directory", type=Path, help="completed run directory")
    summarize_parser.add_argument(
        "--scores", type=Path, required=True, help="scores JSON exported by review.html"
    )
    args = parser.parse_args()
    if args.command == "self-check":
        self_check()
        print("self-check passed")
    elif args.command == "run":
        if args.resume:
            if args.smoke:
                parser.error("--smoke cannot be combined with --resume")
            try:
                manifest = json.loads(
                    (args.resume / "manifest.json").read_text(encoding="utf-8")
                )
            except (OSError, json.JSONDecodeError) as error:
                parser.error(f"cannot read resume manifest: {error}")
            completed = {
                item["key"]
                for item in read_jsonl(args.resume / "responses.jsonl")
                + read_jsonl(args.resume / "failures.jsonl")
            }
            jobs = manifest["jobs"]
            remaining = sum(job["key"] not in completed for job in jobs)
            print(f"{remaining} requests remaining")
            if not remaining:
                return 0
            cases = manifest["cases"]
        try:
            if not args.resume:
                cases = load_cases([args.public_cases, args.private_cases])
        except ValueError as error:
            parser.error(str(error))
        if not args.resume:
            jobs = smoke_jobs(cases) if args.smoke else build_jobs(cases)
        print_plan(jobs)
        if args.yes and args.no_input:
            parser.error("--yes and --no-input cannot be combined")
        if not args.yes:
            if args.no_input or not sys.stdin.isatty():
                parser.error("confirmation required; rerun with --yes")
            if input("Proceed with paid requests? [y/N] ").strip().lower() != "y":
                print("Cancelled")
                return 0
        if args.resume:
            run_directory = args.resume
        else:
            run_directory = args.output or Path(".model-evaluation/runs") / datetime.now(
                UTC
            ).strftime("%Y%m%dT%H%M%SZ")
            manifest = None
        try:
            paid_run(
                cases=cases,
                jobs=jobs,
                run_directory=run_directory,
                manifest=manifest,
            )
        except (OSError, RuntimeError, ValueError, KeyError, json.JSONDecodeError) as error:
            parser.error(str(error))
    elif args.command == "summarize":
        try:
            summary = summarize_run(args.run_directory, args.scores)
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
            parser.error(str(error))
        for track, result in summary["tracks"].items():
            leader = result["leader"]
            if leader:
                suffix = " — close result" if result["close"] else ""
                print(f"{track}: {leader['model']} ({leader['share']:.1%}){suffix}")
            else:
                print(f"{track}: no eligible model")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted; completed results remain saved.", file=sys.stderr)
        raise SystemExit(130) from None
