import subprocess
import sys
import tempfile
import unittest
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "evaluate-openrouter-models.py"


class EvaluationCliTest(unittest.TestCase):
    @staticmethod
    def _write_complete_cases(directory):
        paths = []
        for name, numbers in (("public", range(5)), ("private", range(5, 20))):
            path = directory / f"{name}.jsonl"
            path.write_text(
                "\n".join(
                    json.dumps(
                        {"id": f"{track}-{number}", "track": track, "text": "test"}
                    )
                    for track in ("polishing", "zh-en", "en-zh")
                    for number in numbers
                )
                + "\n",
                encoding="utf-8",
            )
            paths.append(path)
        return paths

    @staticmethod
    def _run_cli(*args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *(str(arg) for arg in args)],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )

    def test_repository_has_five_synthetic_cases_per_track(self):
        cases = [
            json.loads(line)
            for line in (
                ROOT / "docs/research/model-evaluation-cases.jsonl"
            ).read_text(encoding="utf-8").splitlines()
        ]

        self.assertEqual(
            {
                track: sum(case["track"] == track for case in cases)
                for track in ("polishing", "zh-en", "en-zh")
            },
            {"polishing": 5, "zh-en": 5, "en-zh": 5},
        )

    def test_self_check_runs_without_network(self):
        result = self._run_cli("self-check")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("validation: ok", result.stdout)
        self.assertIn("budget: ok", result.stdout)
        self.assertIn("resume: ok", result.stdout)
        self.assertIn("review: ok", result.stdout)
        self.assertIn("request: ok", result.stdout)
        self.assertIn("persistence: ok", result.stdout)
        self.assertIn("execution: ok", result.stdout)
        self.assertIn("orchestration: ok", result.stdout)
        self.assertIn("failure preservation: ok", result.stdout)
        self.assertIn("cumulative time: ok", result.stdout)
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
            result = self._run_cli(
                "run",
                "--public-cases",
                cases,
                "--private-cases",
                Path(directory) / "missing.jsonl",
                "--yes",
            )
        self.assertEqual(result.returncode, 2)
        self.assertIn("need 5 public and 15 private cases for each track", result.stderr)

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
            result = self._run_cli(
                "run",
                "--public-cases",
                cases,
                "--private-cases",
                Path(directory) / "missing.jsonl",
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
            result = self._run_cli(
                "summarize", run_directory, "--scores", scores
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
            result = self._run_cli(
                "summarize", run_directory, "--scores", scores
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("polishing: alpha (0.0%)", result.stdout)

    def test_summarize_keeps_track_failures_independent(self):
        with tempfile.TemporaryDirectory() as directory:
            run_directory = Path(directory)
            jobs = [
                {
                    "key": f"{model}-{track}-{run}",
                    "model": model,
                    "case": {"track": track},
                }
                for model in ("alpha", "beta")
                for track in ("polishing", "zh-en")
                for run in range(1, 4)
            ]
            cases = [
                {"id": track, "track": track, "text": "source"}
                for track in ("polishing", "zh-en")
            ]
            (run_directory / "manifest.json").write_text(
                json.dumps({"jobs": jobs, "cases": cases, "seed": 1}), encoding="utf-8"
            )
            (run_directory / "review-map.json").write_text(
                json.dumps(
                    {
                        "comparisons": [
                            {
                                "id": "polishing-comparison",
                                "track": "polishing",
                                "case_id": "polishing",
                                "a_model": "alpha",
                                "b_model": "beta",
                                "a_key": "alpha-polishing-2",
                                "b_key": "beta-polishing-1",
                                "criteria": ["naturalness"],
                            },
                            {
                                "id": "translation-comparison",
                                "track": "zh-en",
                                "case_id": "zh-en",
                                "a_model": "alpha",
                                "b_model": "beta",
                                "a_key": "alpha-zh-en-1",
                                "b_key": "beta-zh-en-1",
                                "criteria": ["naturalness"],
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )
            responses = []
            for model in ("alpha", "beta"):
                for track in ("polishing", "zh-en"):
                    for run in range(1, 4):
                        key = f"{model}-{track}-{run}"
                        if key == "alpha-polishing-1":
                            continue
                        responses.append(
                            {
                                "key": key,
                                "case_id": track,
                                "model": model,
                                "track": track,
                                "run": run,
                                "valid": True,
                                "parsed": {"translation": "output"},
                            }
                        )
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
            result = self._run_cli(
                "summarize", run_directory, "--scores", scores
            )
            follow_up_html_exists = (run_directory / "review-follow-up.html").exists()
            follow_up_map_exists = (run_directory / "review-follow-up-map.json").exists()
            follow_up_map = json.loads(
                (run_directory / "review-follow-up-map.json").read_text(encoding="utf-8")
            )
            follow_up_items = [
                {"name": f"{comparison['id']}::{criterion}", "value": "tie"}
                for comparison in follow_up_map["comparisons"]
                for criterion in comparison["criteria"]
            ]
            follow_up_path = run_directory / "reviewer-1.json"
            follow_up_path.write_text(json.dumps(follow_up_items), encoding="utf-8")
            follow_up_result = self._run_cli(
                "summarize",
                run_directory,
                "--scores",
                scores,
                "--follow-up-scores",
                follow_up_path,
            )
            stored_follow_up_scores = (
                run_directory / "follow-up-scores-1.json"
            ).exists()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("polishing: beta", result.stdout)
        self.assertIn("zh-en: alpha", result.stdout)
        self.assertIn("follow-up review required", result.stdout)
        self.assertTrue(follow_up_html_exists)
        self.assertTrue(follow_up_map_exists)
        self.assertEqual(follow_up_result.returncode, 0, follow_up_result.stderr)
        self.assertIn("follow-up scores included from 1 reviewer", follow_up_result.stdout)
        self.assertTrue(stored_follow_up_scores)

    def test_noninteractive_run_requires_explicit_confirmation(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            public_cases, private_cases = self._write_complete_cases(directory)
            result = self._run_cli(
                "run",
                "--public-cases",
                public_cases,
                "--private-cases",
                private_cases,
                "--no-input",
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("480 requests", result.stdout)
        self.assertIn("maximum reserved cost", result.stdout)
        self.assertIn("confirmation required; rerun with --yes", result.stderr)

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
            result = self._run_cli("run", "--resume", run_directory, "--yes")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("0 requests remaining", result.stdout)

    def test_smoke_plan_uses_one_request_per_track_candidate(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            public_cases, private_cases = self._write_complete_cases(directory)
            result = self._run_cli(
                "run",
                "--public-cases",
                public_cases,
                "--private-cases",
                private_cases,
                "--smoke",
                "--no-input",
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("8 requests", result.stdout)


if __name__ == "__main__":
    unittest.main()
