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
from decimal import Decimal, InvalidOperation
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
POLISHING_INSTRUCTIONS = (
    "Return proofreading diagnostics that match the requested response schema.  "
    "Do not include Markdown, comments, prose, or reasoning outside the structured "
    "response.\n"
    "The top-level response has a diagnostics array.  Each diagnostic has kind, "
    "message, text, range, and suggestions fields.\n"
    "Report every independent problem in Text.  Do not stop after the first problem "
    "in a sentence; when one sentence has multiple misspellings, grammar issues, or "
    "style issues, return one diagnostic per issue.\n"
    "Prefer the smallest exact text range that identifies each issue, and keep "
    "diagnostics separate unless one correction requires a single combined range.\n"
    "For Chinese text, also check adjacent characters that may form one misspelled "
    "word; a diagnostic may cover multiple adjacent characters.\n"
    "Report diagnostics only for the Text section.  Use context before and context "
    "after only to understand the Text; never return ranges or text from context.\n"
    "When Target kind is comment or docstring, check only natural-language prose.  "
    "Never report comment delimiters, string quotes, indentation, program code, or "
    "markup as proofreading problems.\n"
    "Use zero-based chunk-relative offsets; range end is exclusive.\n"
    "The text field must exactly equal the substring selected by range.\n"
    "Use kind values spelling, grammar, style, or other.\n"
    "For suggestions, return practical replacement text in best-first order.  "
    "Include multiple suggestions when several distinct corrections are useful; one "
    "suggestion or an empty suggestions array is acceptable when there is no real "
    "alternative.\n"
    "Use an empty diagnostics array when there are no diagnostics."
)


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
    target = (
        "natural international English with US spelling"
        if case["track"] == "zh-en"
        else "Simplified Chinese"
    )
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
                job = {
                    "key": f"{case['id']}::{model}::{run_number}",
                    "case": case,
                    "model": model,
                    "run": run_number,
                    "prompt": prompt,
                }
                job["reserved_cost"] = str(reserve_request_cost(job, MODEL_PRICES))
                jobs.append(job)
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


def write_json_atomic(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


class OpenRouterRequestError(RuntimeError):
    def __init__(self, message: str, details: dict):
        super().__init__(message)
        self.details = details


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
    attempt_failures = []
    for attempt in range(2):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                body = response.read().decode("utf-8", errors="replace")
                try:
                    result = json.loads(body)
                except json.JSONDecodeError as error:
                    raise OpenRouterRequestError(
                        "OpenRouter returned invalid JSON",
                        {
                            "attempt_failures": attempt_failures,
                            "status": response.status,
                            "body": body,
                        },
                    ) from error
                if not isinstance(result, dict):
                    raise OpenRouterRequestError(
                        "OpenRouter returned a non-object response",
                        {
                            "attempt_failures": attempt_failures,
                            "status": response.status,
                            "body": body,
                        },
                    )
                if attempt_failures:
                    result["_evaluation_attempt_failures"] = attempt_failures
                return result
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            attempt_failures.append(
                {"attempt": attempt + 1, "status": error.code, "body": body}
            )
            retryable = error.code in {408, 429} or error.code >= 500
            if retryable and attempt == 0:
                time.sleep(1)
                continue
            try:
                detail = json.loads(body).get("error", {}).get("message")
            except (json.JSONDecodeError, AttributeError):
                detail = None
            message = f"OpenRouter HTTP {error.code}" + (f": {detail}" if detail else "")
            raise OpenRouterRequestError(
                message, {"attempt_failures": attempt_failures}
            ) from error
        except (urllib.error.URLError, TimeoutError) as error:
            attempt_failures.append(
                {
                    "attempt": attempt + 1,
                    "error_type": type(error).__name__,
                    "error": str(error),
                }
            )
            if attempt == 0:
                time.sleep(1)
                continue
            raise OpenRouterRequestError(
                "OpenRouter request failed after one retry",
                {"attempt_failures": attempt_failures},
            ) from error
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
        raise OpenRouterRequestError(
            "OpenRouter response has no message content",
            {"response": api_response},
        ) from error
    try:
        parsed = validate_structured_response(job["case"]["track"], content, job["case"]["text"])
        valid, validation_error = True, None
    except ValueError as error:
        parsed, valid, validation_error = None, False, str(error)
    usage = api_response.get("usage")
    if not isinstance(usage, dict):
        raise OpenRouterRequestError(
            "OpenRouter response has invalid usage data",
            {"response": api_response},
        )
    try:
        cost = Decimal(str(usage.get("cost", 0)))
    except (InvalidOperation, ValueError) as error:
        raise OpenRouterRequestError(
            "OpenRouter response has invalid cost data",
            {"response": api_response},
        ) from error
    if not cost.is_finite() or cost < 0:
        raise OpenRouterRequestError(
            "OpenRouter response has invalid cost data",
            {"response": api_response},
        )
    failed_attempts = len(api_response.get("_evaluation_attempt_failures", ()))
    unknown_attempt_cost = Decimal(job["reserved_cost"]) / 2 * failed_attempts
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
        "budget_cost": str(min(Decimal(job["reserved_cost"]), cost + unknown_attempt_cost)),
        "usage": usage,
        "service_tier": api_response.get("service_tier"),
        "openrouter_metadata": api_response.get("openrouter_metadata"),
        "attempt_failures": api_response.get("_evaluation_attempt_failures", []),
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
    budget_used = sum(
        (
            Decimal(item.get("budget_cost", item.get("cost", "0")))
            for item in responses + failures
        ),
        Decimal(),
    )
    elapsed_before = float(manifest.get("elapsed_seconds", 0))
    invocation_started = time.monotonic()
    deadline = invocation_started + max(0, time_limit_seconds - elapsed_before)
    stopped_reason = None
    next_job = 0
    in_flight = {}
    interrupted = False

    def record_future(future) -> None:
        nonlocal spent, budget_used
        job = in_flight[future]
        try:
            result = future.result()
        except OpenRouterRequestError as error:
            result = {
                "key": job["key"],
                "case_id": job["case"]["id"],
                "track": job["case"]["track"],
                "model": job["model"],
                "provider": MODELS[job["model"]]["provider"],
                "run": job["run"],
                "cost": "0",
                "budget_cost": job["reserved_cost"],
                "error": str(error),
                "details": error.details,
            }
            append_jsonl(failures_path, result)
            failures.append(result)
        else:
            append_jsonl(responses_path, result)
            responses.append(result)
        spent += Decimal(result["cost"])
        budget_used += Decimal(result["budget_cost"])
        in_flight.pop(future)
        manifest.update(
            {
                "spent_cost": str(spent),
                "budget_used": str(budget_used),
                "completed_requests": len(responses) + len(failures),
                "stopped_reason": stopped_reason,
                "elapsed_seconds": elapsed_before
                + time.monotonic()
                - invocation_started,
            }
        )
        write_json_atomic(run_directory / "manifest.json", manifest)

    try:
        with ThreadPoolExecutor(max_workers=4) as executor:
            while next_job < len(pending) or in_flight:
                while next_job < len(pending) and len(in_flight) < 4:
                    if time.monotonic() >= deadline:
                        stopped_reason = "time_limit"
                        next_job = len(pending)
                        break
                    job = pending[next_job]
                    reserved_in_flight = sum(
                        (
                            Decimal(item["reserved_cost"])
                            for item in in_flight.values()
                        ),
                        Decimal(),
                    )
                    if (
                        budget_used
                        + reserved_in_flight
                        + Decimal(job["reserved_cost"])
                        > cost_limit
                    ):
                        stopped_reason = "cost_limit"
                        next_job = len(pending)
                        break
                    in_flight[executor.submit(execute_job, job, api_key, post)] = job
                    next_job += 1
                if not in_flight:
                    break
                done, _ = wait(in_flight, return_when=FIRST_COMPLETED)
                for future in done:
                    record_future(future)
    except KeyboardInterrupt:
        interrupted = True
        stopped_reason = "interrupted"
        for future in list(in_flight):
            record_future(future)
    finally:
        manifest["stopped_reason"] = stopped_reason
        manifest["elapsed_seconds"] = (
            elapsed_before + time.monotonic() - invocation_started
        )
        write_json_atomic(run_directory / "manifest.json", manifest)
    if interrupted:
        raise KeyboardInterrupt
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
                    "a_key": first["key"],
                    "b_key": second["key"],
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


def build_follow_up_data(
    cases: list[dict],
    responses: list[dict],
    initial_review_map: dict,
    tracks: set[str],
    seed: int,
) -> tuple[dict, list]:
    cases_by_id = {case["id"]: case for case in cases}
    by_case_model = {}
    for response in responses:
        if response.get("valid"):
            by_case_model.setdefault((response["case_id"], response["model"]), []).append(
                response
            )
    randomizer = random.Random(seed)
    private_comparisons = []
    public_comparisons = []
    number = 0
    for initial in initial_review_map["comparisons"]:
        if initial["track"] not in tracks:
            continue
        case = cases_by_id[initial["case_id"]]
        first_options = [
            response
            for response in by_case_model.get(
                (initial["case_id"], initial["a_model"]), []
            )
            if response["key"] != initial["a_key"]
        ]
        second_options = [
            response
            for response in by_case_model.get(
                (initial["case_id"], initial["b_model"]), []
            )
            if response["key"] != initial["b_key"]
        ]
        for first, second in zip(
            sorted(first_options, key=lambda item: item["run"]),
            sorted(second_options, key=lambda item: item["run"]),
        ):
            number += 1
            first_model, second_model = initial["a_model"], initial["b_model"]
            if randomizer.choice((False, True)):
                first_model, second_model = second_model, first_model
                first, second = second, first
            identifier = f"follow-up-{number:04d}"
            private_comparisons.append(
                {
                    "id": identifier,
                    "track": initial["track"],
                    "case_id": initial["case_id"],
                    "a_model": first_model,
                    "b_model": second_model,
                    "a_key": first["key"],
                    "b_key": second["key"],
                    "criteria": initial["criteria"],
                }
            )
            public_comparisons.append(
                {
                    "id": identifier,
                    "track": initial["track"],
                    "source": case["text"],
                    "requirements": case.get("requirements", []),
                    "a": display_output(first),
                    "b": display_output(second),
                    "criteria": initial["criteria"],
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


def reserve_request_cost(job: dict, prices: dict) -> Decimal:
    prompt_price, completion_price = prices[job["model"]]
    request_bytes = len(
        json.dumps(build_request(job), ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    )
    one_attempt = (
        prompt_price * request_bytes + completion_price * MAX_OUTPUT_TOKENS
    ) * Decimal("1.10")
    return one_attempt * 2


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
<label><input type="checkbox" name="{identifier}::unstable-a">Review A for instability</label>
<label><input type="checkbox" name="{identifier}::unstable-b">Review B for instability</label>
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


def score_review_batches(manifest: dict, responses: list[dict], batches: list[tuple]) -> dict:
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
    unstable_models = set()
    for review_map, score_items in batches:
        scores = {item["name"]: item["value"] for item in score_items}
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
                if scores.get(f"{comparison['id']}::unstable-{side}") == "on":
                    unstable_models.add((track, model))
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
        summary["tracks"][track]["critical_models"] = sorted(
            model for critical_track, model in critical_models if critical_track == track
        )
        summary["tracks"][track]["unstable_models"] = sorted(
            model for unstable_track, model in unstable_models if unstable_track == track
        )
    return summary


def summarize_run(
    run_directory: Path,
    scores_path: Path,
    follow_up_scores_path: Path | None,
    second_reviewer_scores_path: Path | None,
) -> dict:
    manifest = json.loads((run_directory / "manifest.json").read_text(encoding="utf-8"))
    review_map = json.loads((run_directory / "review-map.json").read_text(encoding="utf-8"))
    score_items = json.loads(scores_path.read_text(encoding="utf-8"))
    write_json_atomic(run_directory / "scores.json", score_items)
    responses = read_jsonl(run_directory / "responses.jsonl")
    summary = score_review_batches(manifest, responses, [(review_map, score_items)])
    follow_up_tracks = {
        track
        for track, result in summary["tracks"].items()
        if result["close"] or result["critical_models"] or result["unstable_models"]
    }
    close_tracks = {
        track for track, result in summary["tracks"].items() if result["close"]
    }
    summary["follow_up_required"] = sorted(follow_up_tracks)
    summary["follow_up_reviewers_required"] = {
        track: 2 if track in close_tracks else 1 for track in sorted(follow_up_tracks)
    }
    if follow_up_tracks:
        follow_up_map, public_comparisons = build_follow_up_data(
            manifest["cases"],
            responses,
            review_map,
            follow_up_tracks,
            manifest["seed"] + 1,
        )
        write_json_atomic(run_directory / "review-follow-up-map.json", follow_up_map)
        (run_directory / "review-follow-up.html").write_text(
            render_review(public_comparisons, f"model-evaluation-follow-up-{manifest['seed']}"),
            encoding="utf-8",
        )
        second_map = None
        if close_tracks:
            second_map, second_public = build_follow_up_data(
                manifest["cases"],
                responses,
                review_map,
                close_tracks,
                manifest["seed"] + 2,
            )
            write_json_atomic(
                run_directory / "review-follow-up-second-map.json", second_map
            )
            (run_directory / "review-follow-up-second.html").write_text(
                render_review(
                    second_public,
                    f"model-evaluation-follow-up-second-{manifest['seed']}",
                ),
                encoding="utf-8",
            )
        if follow_up_scores_path:
            if close_tracks and not second_reviewer_scores_path:
                raise ValueError("close results require --second-reviewer-scores")
            if not close_tracks and second_reviewer_scores_path:
                raise ValueError("second-reviewer scores are only valid for close results")
            batches = [(review_map, score_items)]
            follow_up_items = json.loads(
                follow_up_scores_path.read_text(encoding="utf-8")
            )
            write_json_atomic(
                run_directory / "follow-up-scores-1.json", follow_up_items
            )
            batches.append((follow_up_map, follow_up_items))
            if close_tracks:
                second_items = json.loads(
                    second_reviewer_scores_path.read_text(encoding="utf-8")
                )
                write_json_atomic(
                    run_directory / "follow-up-scores-2.json", second_items
                )
                batches.append((second_map, second_items))
            summary = score_review_batches(manifest, responses, batches)
            summary["follow_up_required"] = sorted(follow_up_tracks)
            summary["follow_up_reviewers_required"] = {
                track: 2 if track in close_tracks else 1
                for track in sorted(follow_up_tracks)
            }
            summary["follow_up_scores_included"] = {
                track: 2 if track in close_tracks else 1
                for track in sorted(follow_up_tracks)
            }
        elif second_reviewer_scores_path:
            raise ValueError("provide --follow-up-scores before second-reviewer scores")
    elif follow_up_scores_path or second_reviewer_scores_path:
        raise ValueError("follow-up scores were provided but no follow-up is required")
    summary["production_verification"] = "pending"
    (run_directory / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return summary


def self_check() -> None:
    validate_structured_response("zh-en", '{"translation":"Hello"}', "你好")
    validate_structured_response("polishing", '{"diagnostics":[]}', "Correct text.")
    print("validation: ok")
    budget_job = build_jobs(
        [{"id": "budget", "track": "polishing", "text": "test"}]
    )[0]
    assert Decimal(budget_job["reserved_cost"]) < Decimal("0.1")
    print("budget: ok")
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
    print("resume: ok")
    print("orchestration: ok")
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory)

        def fail(body, key):
            raise OpenRouterRequestError(
                "OpenRouter HTTP 503",
                {"attempt_failures": [{"status": 503, "body": "unavailable"}]},
            )

        failure_result = run_jobs(
            directory,
            {"spent_cost": "0"},
            [job],
            "hidden",
            post=fail,
            cost_limit=Decimal("1"),
        )
        assert read_jsonl(directory / "failures.jsonl")[0]["details"][
            "attempt_failures"
        ][0]["body"] == "unavailable"
        assert failure_result["manifest"]["budget_used"] == job["reserved_cost"]
    print("failure preservation: ok")
    with tempfile.TemporaryDirectory() as directory:
        calls = []
        manifest = {"spent_cost": "0", "elapsed_seconds": 1}
        result = run_jobs(
            Path(directory),
            manifest,
            [job],
            "hidden",
            post=lambda body, key: calls.append(body),
            cost_limit=Decimal("1"),
            time_limit_seconds=1,
        )
        assert not calls and result["manifest"]["stopped_reason"] == "time_limit"
    print("cumulative time: ok")


def load_cases(
    public_path: Path, private_path: Path, *, require_full: bool = True
) -> list[dict]:
    cases = []
    counts_by_source = {}
    for source, path in (("public", public_path), ("private", private_path)):
        source_cases = []
        if not path.exists():
            counts_by_source[source] = Counter()
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
            source_cases.append(case)
        cases.extend(source_cases)
        counts_by_source[source] = Counter(case["track"] for case in source_cases)
    if len({case["id"] for case in cases}) != len(cases):
        raise ValueError("case ids must be unique")
    if require_full and any(
        counts_by_source["public"][track] != 5
        or counts_by_source["private"][track] != 15
        for track in TRACKS
    ):
        raise ValueError("need 5 public and 15 private cases for each track")
    if not require_full and any(
        counts_by_source["public"][track] + counts_by_source["private"][track] < 1
        for track in TRACKS
    ):
        raise ValueError("smoke runs need at least one case for each track")
    return cases


def write_review_files(
    run_directory: Path, cases: list[dict], responses: list[dict], seed: int
) -> int:
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
            "budget_used": "0",
            "elapsed_seconds": 0,
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
    print(f"budget used: US${Decimal(result['manifest']['budget_used']):.4f}")
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
    run_parser.add_argument("--resume", type=Path, help="existing run directory to resume")
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
    summarize_parser.add_argument(
        "--follow-up-scores",
        type=Path,
        help="follow-up scores for every affected track",
    )
    summarize_parser.add_argument(
        "--second-reviewer-scores",
        type=Path,
        help="second reviewer's scores for close tracks",
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
                cases = load_cases(
                    args.public_cases,
                    args.private_cases,
                    require_full=not args.smoke,
                )
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
            run_directory = Path(".model-evaluation/runs") / datetime.now(UTC).strftime(
                "%Y%m%dT%H%M%SZ"
            )
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
            summary = summarize_run(
                args.run_directory,
                args.scores,
                args.follow_up_scores,
                args.second_reviewer_scores,
            )
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
            parser.error(str(error))
        for track, result in summary["tracks"].items():
            leader = result["leader"]
            if leader:
                suffix = " — close result" if result["close"] else ""
                print(f"{track}: {leader['model']} ({leader['share']:.1%}){suffix}")
            else:
                print(f"{track}: no eligible model")
        if summary["follow_up_required"] and not summary.get("follow_up_scores_included"):
            tracks = ", ".join(summary["follow_up_required"])
            print(f"follow-up review required: {tracks}")
        if summary.get("follow_up_scores_included"):
            counts = set(summary["follow_up_scores_included"].values())
            description = " and ".join(str(count) for count in sorted(counts))
            noun = "reviewer" if counts == {1} else "reviewers"
            print(f"follow-up scores included from {description} {noun}")
            print("human selection is required; production was not changed")
        print(
            "production verification pending: see the research report's "
            "Production verification section"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted; completed results remain saved.", file=sys.stderr)
        raise SystemExit(130) from None
