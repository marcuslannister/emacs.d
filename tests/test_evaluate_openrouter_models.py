import subprocess
import sys
import tempfile
import unittest
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "evaluate-openrouter-models.py"


class EvaluationCliTest(unittest.TestCase):
    def test_repository_has_five_synthetic_cases_per_track(self):
        cases = [
            json.loads(line)
            for line in (
                ROOT / "docs/research/model-evaluation-cases.jsonl"
            ).read_text(encoding="utf-8").splitlines()
        ]

        self.assertEqual(
            {track: sum(case["track"] == track for case in cases) for track in cases[0:0] or ("polishing", "zh-en", "en-zh")},
            {"polishing": 5, "zh-en": 5, "en-zh": 5},
        )

    def test_self_check_runs_without_network(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "self-check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("validation: ok", result.stdout)
        self.assertIn("budget: ok", result.stdout)
        self.assertIn("resume: ok", result.stdout)
        self.assertIn("review: ok", result.stdout)
        self.assertIn("request: ok", result.stdout)
        self.assertIn("persistence: ok", result.stdout)
        self.assertIn("execution: ok", result.stdout)
        self.assertIn("orchestration: ok", result.stdout)
        self.assertIn("self-check passed", result.stdout)

    def test_run_rejects_incomplete_case_set_before_paid_call(self):
        with tempfile.TemporaryDirectory() as directory:
            cases = Path(directory) / "cases.jsonl"
            cases.write_text(
                "\n".join(
                    json.dumps({"id": track, "track": track, "text": "test"})
                    for track in ("polishing", "zh-en", "en-zh")
                )
                + "\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "run",
                    "--public-cases",
                    str(cases),
                    "--private-cases",
                    str(Path(directory) / "missing.jsonl"),
                    "--output",
                    str(Path(directory) / "run"),
                    "--yes",
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("need 20 cases for each track", result.stderr)

    def test_run_rejects_a_free_form_case_prompt(self):
        with tempfile.TemporaryDirectory() as directory:
            cases = Path(directory) / "cases.jsonl"
            cases.write_text(
                json.dumps(
                    {
                        "id": "unsafe",
                        "track": "zh-en",
                        "text": "你好",
                        "prompt": "Use a different task.",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "run",
                    "--public-cases",
                    str(cases),
                    "--private-cases",
                    str(Path(directory) / "missing.jsonl"),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown case fields: prompt", result.stderr)

    def test_summarize_names_the_eligible_pairwise_leader(self):
        with tempfile.TemporaryDirectory() as directory:
            run_directory = Path(directory)
            (run_directory / "manifest.json").write_text(
                json.dumps(
                    {
                        "jobs": [
                            {
                                "key": "alpha-1",
                                "model": "alpha",
                                "case": {"track": "polishing"},
                            },
                            {
                                "key": "beta-1",
                                "model": "beta",
                                "case": {"track": "polishing"},
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )
            (run_directory / "review-map.json").write_text(
                json.dumps(
                    {
                        "comparisons": [
                            {
                                "id": "comparison-1",
                                "track": "polishing",
                                "a_model": "alpha",
                                "b_model": "beta",
                                "criteria": ["naturalness", "restraint"],
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            (run_directory / "responses.jsonl").write_text(
                "\n".join(
                    json.dumps(
                        {
                            "key": f"{model}-1",
                            "model": model,
                            "track": "polishing",
                            "valid": True,
                        }
                    )
                    for model in ("alpha", "beta")
                )
                + "\n",
                encoding="utf-8",
            )
            scores = run_directory / "scores.json"
            scores.write_text(
                json.dumps(
                    [
                        {"name": "comparison-1::naturalness", "value": "a"},
                        {"name": "comparison-1::restraint", "value": "tie"},
                    ]
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "summarize",
                    str(run_directory),
                    "--scores",
                    str(scores),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("polishing: alpha (75.0%)", result.stdout)

    def test_summarize_disqualifies_a_model_with_a_missing_response(self):
        with tempfile.TemporaryDirectory() as directory:
            run_directory = Path(directory)
            (run_directory / "manifest.json").write_text(
                json.dumps(
                    {
                        "jobs": [
                            {
                                "key": "alpha-1",
                                "model": "alpha",
                                "case": {"track": "polishing"},
                            },
                            {
                                "key": "beta-1",
                                "model": "beta",
                                "case": {"track": "polishing"},
                            },
                            {
                                "key": "beta-2",
                                "model": "beta",
                                "case": {"track": "polishing"},
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )
            (run_directory / "review-map.json").write_text(
                json.dumps(
                    {
                        "comparisons": [
                            {
                                "id": "comparison-1",
                                "track": "polishing",
                                "a_model": "alpha",
                                "b_model": "beta",
                                "criteria": ["naturalness"],
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            (run_directory / "responses.jsonl").write_text(
                "\n".join(
                    (
                        json.dumps(
                            {
                                "key": "alpha-1",
                                "model": "alpha",
                                "track": "polishing",
                                "valid": True,
                            }
                        ),
                        json.dumps(
                            {
                                "key": "beta-1",
                                "model": "beta",
                                "track": "polishing",
                                "valid": True,
                            }
                        ),
                    )
                )
                + "\n",
                encoding="utf-8",
            )
            scores = run_directory / "scores.json"
            scores.write_text(
                json.dumps(
                    [{"name": "comparison-1::naturalness", "value": "b"}]
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "summarize",
                    str(run_directory),
                    "--scores",
                    str(scores),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("polishing: alpha (0.0%)", result.stdout)

    def test_summarize_keeps_track_failures_independent(self):
        with tempfile.TemporaryDirectory() as directory:
            run_directory = Path(directory)
            jobs = [
                {"key": key, "model": model, "case": {"track": track}}
                for key, model, track in (
                    ("alpha-polishing", "alpha", "polishing"),
                    ("beta-polishing", "beta", "polishing"),
                    ("alpha-zh-en", "alpha", "zh-en"),
                    ("beta-zh-en", "beta", "zh-en"),
                )
            ]
            (run_directory / "manifest.json").write_text(
                json.dumps({"jobs": jobs}), encoding="utf-8"
            )
            (run_directory / "review-map.json").write_text(
                json.dumps(
                    {
                        "comparisons": [
                            {
                                "id": "polishing-comparison",
                                "track": "polishing",
                                "a_model": "alpha",
                                "b_model": "beta",
                                "criteria": ["naturalness"],
                            },
                            {
                                "id": "translation-comparison",
                                "track": "zh-en",
                                "a_model": "alpha",
                                "b_model": "beta",
                                "criteria": ["naturalness"],
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )
            responses = [
                {"key": key, "model": model, "track": track, "valid": True}
                for key, model, track in (
                    ("beta-polishing", "beta", "polishing"),
                    ("alpha-zh-en", "alpha", "zh-en"),
                    ("beta-zh-en", "beta", "zh-en"),
                )
            ]
            (run_directory / "responses.jsonl").write_text(
                "\n".join(json.dumps(response) for response in responses) + "\n",
                encoding="utf-8",
            )
            scores = run_directory / "scores.json"
            scores.write_text(
                json.dumps(
                    [
                        {"name": "polishing-comparison::naturalness", "value": "b"},
                        {"name": "polishing-comparison::critical-a", "value": "on"},
                        {"name": "translation-comparison::naturalness", "value": "a"},
                    ]
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "summarize",
                    str(run_directory),
                    "--scores",
                    str(scores),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("polishing: beta", result.stdout)
        self.assertIn("zh-en: alpha", result.stdout)

    def test_noninteractive_run_requires_explicit_confirmation(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            cases = directory / "cases.jsonl"
            cases.write_text(
                "\n".join(
                    json.dumps(
                        {
                            "id": f"{track}-{number}",
                            "track": track,
                            "text": "A short test passage.",
                        }
                    )
                    for track in ("polishing", "zh-en", "en-zh")
                    for number in range(20)
                )
                + "\n",
                encoding="utf-8",
            )
            output = directory / "run"
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "run",
                    "--public-cases",
                    str(cases),
                    "--private-cases",
                    str(directory / "missing.jsonl"),
                    "--output",
                    str(output),
                    "--no-input",
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("480 requests", result.stdout)
        self.assertIn("maximum reserved cost", result.stdout)
        self.assertIn("confirmation required; rerun with --yes", result.stderr)
        self.assertFalse(output.exists())

    def test_completed_run_resumes_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            run_directory = Path(directory)
            case = {"id": "case-1", "track": "zh-en", "text": "你好"}
            job = {
                "key": "case-1::alpha::1",
                "case": case,
                "model": "alpha",
                "run": 1,
                "prompt": "translate",
                "reserved_cost": "0.01",
            }
            (run_directory / "manifest.json").write_text(
                json.dumps({"seed": 1, "cases": [case], "jobs": [job]}),
                encoding="utf-8",
            )
            (run_directory / "responses.jsonl").write_text(
                json.dumps(
                    {
                        "key": job["key"],
                        "case_id": "case-1",
                        "track": "zh-en",
                        "model": "alpha",
                        "run": 1,
                        "valid": True,
                        "parsed": {"translation": "Hello"},
                        "cost": "0.001",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "run",
                    "--resume",
                    str(run_directory),
                    "--yes",
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("0 requests remaining", result.stdout)

    def test_smoke_plan_uses_one_request_per_track_candidate(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            cases = directory / "cases.jsonl"
            cases.write_text(
                "\n".join(
                    json.dumps(
                        {"id": f"{track}-{number}", "track": track, "text": "test"}
                    )
                    for track in ("polishing", "zh-en", "en-zh")
                    for number in range(20)
                )
                + "\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "run",
                    "--public-cases",
                    str(cases),
                    "--private-cases",
                    str(directory / "missing.jsonl"),
                    "--smoke",
                    "--no-input",
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("8 requests", result.stdout)


if __name__ == "__main__":
    unittest.main()
