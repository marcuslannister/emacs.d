# OpenRouter models for translation and English polishing

Verified: 2026-08-23 and 2026-08-24

## Operational choice

Selected on 2026-08-25 for the actual Emacs workflow:

- Use `google/gemini-3.7-flash` through OpenRouter for the context-aware
  Proofread checker and selected-text `ml-llm-proof` command.
- Do not add an automatic fallback before the main workflow needs one.
- Keep `tencent/hy-mt2-30b-a3b` for occasional translation. Do not route normal
  proofreading through the translation model.

This is the user's operational choice, not a benchmark result. Gemini 3.7's
Google Vertex OpenRouter endpoint supports structured output and requires
reasoning, but it did not advertise a temperature parameter on the verification
date. The Emacs configuration therefore uses `low` reasoning and omits
temperature
([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/google/gemini-3.7-flash/endpoints)).

## Result

Treat English-to-English polishing, Chinese-to-English translation, and
English-to-Chinese translation as three separate tasks. For English polishing,
use `openai/gpt-5.6-terra` as the first integration-ready candidate and test it
against `google/gemini-3.7-flash`. Use `openai/gpt-5.6-luna` as the first
lower-cost candidate. For both translation directions, add
`tencent/hy-mt2-30b-a3b` as a specialist candidate. No source proves that it is
the best candidate in either direction.

This is a recommended test order. It is not a proven quality ranking. No
first-party source has a controlled test of these models for restrained English
polishing with this repository's prompt. OpenAI puts Terra in its balanced
intelligence-and-cost tier and Luna in its cost-sensitive tier
([OpenAI model catalog](https://developers.openai.com/api/docs/models)). Google
calls Gemini 3.7 Flash its most capable Flash model, but its published tests are
for broad reasoning, coding, and agent work, not this polishing task
([Gemini 3.7 Flash model card](https://deepmind.google/models/model-cards/gemini-3-7-flash/)).

Terra is first because the current Emacs integration can send a strict JSON
Schema request for it. Gemini 3.7 Flash also supports structured output, but the
installed `llm` metadata does not identify that capability. This is a local
integration limit, not a model limit.

## Provisional test order

| Order | Model | Recommended test use | Assessment |
| --- | --- | --- | --- |
| 1 | `openai/gpt-5.6-terra` | English-to-English proofreading and polishing | **Inference:** best first operational candidate. OpenAI positions Terra above Luna for intelligence, and the current Emacs path sends its schema. No direct polishing result proves that Terra has the best prose. |
| 2 | `google/gemini-3.7-flash` | English-to-English proofreading and polishing | **Inference:** strongest first challenger. Google reports strong broad capability. The current Emacs path cannot send the schema until its model metadata changes ([Google model guide](https://ai.google.dev/gemini-api/docs/latest-model)). |
| 3 | `openai/gpt-5.6-luna` | Lower-cost English polishing | **Inference:** first cost challenger. OpenAI designed it for high-volume, cost-sensitive work. OpenMark's translation result does not prove English-polishing quality. |
| 4 | `google/gemini-3.5-flash-lite` | Fast, inexpensive checks | **Inference:** useful for a cost and latency floor. Google designed it for high-volume, latency-sensitive tasks such as translation, classification, document processing, and extraction. This does not prove nuanced polishing quality ([Google model card](https://deepmind.google/models/model-cards/gemini-3-5-flash-lite/)). |
| 5 | `tencent/hy-mt2-30b-a3b` | Chinese-to-English and English-to-Chinese translation | **Fact:** translation specialist for both languages. **Unverified:** whether it wins in either direction, and its same-language English proofreading quality. Keep it out of the English-polishing rank unless an experimental run performs well. |
| 6 | `deepseek/deepseek-v4-pro-0813` | Open-weight challenger in each separate track | **Fact:** current model and current OpenRouter route family. **Unverified:** English-polishing quality. Test it only after the request uses a schema-capable route and the local metadata is corrected. |

## Verified API and integration facts

Prices are the lowest listed default-tier input/output prices in US dollars per
one million tokens on the verification date. They exclude flex and priority
tiers, large-prompt overrides, and cache prices. The actual route can cost more.
A schema requirement can also remove the cheapest route. Use the response usage
data for the final cost, not this table.

| OpenRouter model | Structured output on OpenRouter | Strict schema in the current Emacs proofreader | Reasoning control | Lowest listed default-tier price |
| --- | --- | --- | --- | --- |
| `openai/gpt-5.6-terra` | Yes on current OpenAI and Azure routes. Some routes do not list it, so require all request parameters. | Yes. The generic GPT-5 metadata match includes `json-response`. | `none`, `low`, `medium` (default), `high`, `xhigh`, `max`. Use `none` as the latency baseline and compare `low` ([OpenAI model page](https://developers.openai.com/api/docs/models/gpt-5.6-terra)). | $2.00 / $12.00 ([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/openai/gpt-5.6-terra/endpoints)) |
| `google/gemini-3.7-flash` | Yes on all routes listed at verification time. | Yes after `init-local-proofread.el` registers the missing installed metadata. | `low`, `medium` (default), `high`; `minimal` is not supported ([Google model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.7-flash)). | $0.375 / $1.875; other default routes list $0.75 / $3.75 ([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/google/gemini-3.7-flash/endpoints)) |
| `openai/gpt-5.6-luna` | Yes on current OpenAI and Azure routes. Some routes do not list it, so require all request parameters. | Yes. The generic GPT-5 metadata match includes `json-response`. | `none`, `low`, `medium` (default), `high`, `xhigh`, `max`. Use `none` as the latency baseline ([OpenAI model page](https://developers.openai.com/api/docs/models/gpt-5.6-luna)). | $0.20 / $1.20 ([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/openai/gpt-5.6-luna/endpoints)) |
| `google/gemini-3.5-flash-lite` | Yes on all routes listed at verification time. | Yes. The installed model entry includes `json-response`. | Thinking is supported. Use `minimal` as the low-latency baseline ([Google model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite)). | $0.30 / $2.50 ([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/google/gemini-3.5-flash-lite/endpoints)) |
| `tencent/hy-mt2-30b-a3b` | Yes on its one listed FP8 route. | No matching installed model entry; `auto` uses prompt-only JSON. | No reasoning control is listed. | $0.074 / $0.295 ([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/tencent/hy-mt2-30b-a3b/endpoints)) |
| `deepseek/deepseek-v4-pro-0813` | Only some routes list `structured_outputs`. `provider.require_parameters` is necessary. | No. The installed DeepSeek V4 entry does not include `json-response`. | The official model card lists `low`, `high`, and `max` ([DeepSeek model card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro-0813)). | $0.66 / $1.98, but that route does not list strict structured output; an eligible route can cost more ([OpenRouter endpoint API](https://openrouter.ai/api/v1/models/deepseek/deepseek-v4-pro-0813/endpoints)) |

OpenRouter's documented request is
`response_format.type: "json_schema"` with `strict: true`. Set
`provider.require_parameters: true` because structured-output support is per
endpoint. OpenRouter also warns that enforcement can differ by provider, so the
evaluation must still validate every response
([structured-output guide](https://openrouter.ai/docs/guides/features/structured-outputs),
[provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)).

## Local integration evidence

The checker builds an OpenAI-compatible provider and uses
`:response-strategy auto` in
[`lisp/init-local-proofread.el`](../../lisp/init-local-proofread.el#L41-L58).
For `auto`, the proofreader selects provider JSON only when `llm-capabilities`
contains `json-response`; otherwise, it selects prompt JSON
([`proofread-llm.el`](../../external-packages/emacs-proofread/lisp/proofread/proofread-llm.el#L944-L958)).

The installed OpenAI adapter converts the proofreader schema to
`response_format.type: "json_schema"` and sets `strict: true`
([`llm-openai.el`](../../elpa-31.0/llm-0.31.3/llm-openai.el#L216-L226)). The
installed model metadata has these results
([`llm-models.el`](../../elpa-31.0/llm-0.31.3/llm-models.el#L138-L142)):

- Terra and Luna match the generic GPT-5 entry, which has `json-response`.
- Gemini 3.5 Flash-Lite has a specific entry with `json-response`.
- Gemini 3.7 Flash has no installed entry; `init-local-proofread.el` registers
  its verified capabilities locally.
- Hy-MT2 has no matching entry.
- DeepSeek V4 Pro has an entry, but it does not have `json-response`.

The production prompt asks for diagnostic objects with exact ranges, messages,
and replacement suggestions. The production schema requires every field and
rejects extra properties
([prompt and schema](../../external-packages/emacs-proofread/lisp/proofread/proofread-llm.el#L251-L315)).

## Hy-MT2 correction

Tencent documents Hy-MT2 as a translation family for 33 languages. Its examples
cover terminology, style, personalization, delimiters, context, and structured
data. This evidence supports a translation test, but it does not support a claim
about same-language proofreading
([official repository](https://github.com/Tencent-Hunyuan/Hy-MT2)).

The license is not one simple Apache 2.0 claim. The base
`Hy-MT2-30B-A3B` weights use the Tencent HY Community License, which excludes use
in the European Union and has other restrictions
([base-weight license](https://huggingface.co/tencent/Hy-MT2-30B-A3B/blob/main/LICENSE.txt)).
Tencent publishes the separate `Hy-MT2-30B-A3B-FP8` weights under Apache 2.0
([FP8 license](https://huggingface.co/tencent/Hy-MT2-30B-A3B-FP8/blob/main/LICENSE.txt)).
OpenRouter labels its current route `tencent/fp8`. Thus, the routed artifact is
an FP8 route, but the broad claim that all Hy-MT2-30B-A3B weights are Apache 2.0
is false.

## Evaluation protocol

The first pilot has these accepted decisions:

- Select one recommended model for each track. Do not change any production
  integration automatically.
- Test a small shortlist first. Add candidates only when the first result is
  close or poor.
- Use mostly redacted real passages plus synthetic edge cases. Do not send
  secrets or sensitive text to OpenRouter.
- Use anonymous human scoring by the user. Add a second bilingual reviewer only
  for a close result. Do not use an LLM judge to select the winner.
- Stop the run at US$4 or 30 minutes and preserve completed results.
- Compare models through OpenRouter directly, then verify each winner through
  its production integration.
- Implement one root-level `evaluate-openrouter-models.py` script with only the
  Python standard library.
- Start with Terra and Gemini 3.7 for English polishing. Start with Terra,
  Gemini 3.7, and Hy-MT2 for each translation direction. Reserve Luna, Gemini
  3.5 Flash-Lite, and DeepSeek for a second stage.
- Run 20 passages per track three times. Review one run first; review the other
  runs only when results are close or unstable. Before the pilot, run a local
  self-check and one paid passage per candidate.
- Require translation responses to contain one `translation` string and no
  extra fields.
- Commit synthetic passages. Keep real passages in a gitignored local file.
- Generate a self-contained anonymous HTML review page that stores scores
  locally and downloads them as JSON.
- Retry one network or rate-limit failure. Do not retry invalid JSON or schema
  violations. A winning candidate must have 100% valid structured responses.
  Preserve failed responses for diagnosis.
- Test English polishing with the production Proofread prompt and diagnostic
  JSON Schema, not with full-passage rewriting.
- Translate into natural international English with US spelling unless the
  source requests another style. Translate Chinese output into Simplified
  Chinese. Preserve register, terminology, markup, names, numbers, and format.
- Read the OpenRouter credential from the existing Emacs `auth-source` entry
  through a subprocess. Never print or save the secret.
- Allow four concurrent requests. Use Terra at `none`, Gemini 3.7 at `low`, and
  Hy-MT2 without reasoning controls. Do not set temperature. Reserve estimated
  maximum cost before scheduling so US$4 is a hard limit. At 30 minutes, stop
  scheduling and let in-progress requests finish before saving.
- Keep raw responses, the run manifest, review page, and scores in a gitignored
  local directory. Commit only synthetic passages and an approved summary.
- Verify the English-polishing winner through the current Proofread integration.
  Leave translation production checks pending until a translation integration
  exists; adding one is outside this evaluation task.
- Commit five synthetic passages per track in
  `docs/research/model-evaluation-cases.jsonl`. Keep fifteen redacted real
  passages per track in `.model-evaluation/cases.local.jsonl`. Require 20 cases
  per track for a full run. Allow polishing context fields and optional explicit
  translation requirements; never send reviewer notes to a model.
- Use one fixed prompt per translation direction plus optional per-case
  requirements. Do not allow per-case free-form prompts.
- Pin one schema-capable upstream provider per candidate for a run and disable
  provider fallback. Record provider unavailability as an infrastructure
  failure instead of changing the test condition.
- Select one of the three outputs per candidate and case with a recorded random
  seed. Compare every candidate pair, randomize A/B order, and collect A, B, or
  tie for each criterion plus a critical-error flag. Reveal identities only
  after scoring.
- Give equal weight to issue detection, suggestion naturalness, meaning
  preservation, and restraint for polishing. Give equal weight to meaning,
  terminology, naturalness, register, and format for translation. Rank eligible
  candidates by head-to-head point share. A criterion win is one point; a tie is
  half a point for each candidate.
- A critical-error flag blocks automatic selection and triggers review of the
  other runs. Results within five percentage points require the other runs and a
  second bilingual reviewer. The final selection remains a human decision.
- Provide `self-check`, `run`, and `summarize` commands. A paid run must show its
  plan and require confirmation. Save after every response. Resume only from an
  explicitly named run directory and never resend completed work or forget
  recorded cost.
- Store each run under `.model-evaluation/runs/<timestamp>/` with its manifest,
  raw responses, failures, anonymous review page, exported scores, and summary.

The pilot method is:

1. Run three separate tracks: English-to-English proofreading and polishing,
   Chinese-to-English translation, and English-to-Chinese translation. Test
   Hy-MT2 in both translation tracks, but do not combine the direction scores.
2. Use 20–30 representative real passages per track. The English-polishing set
   must include correct text, grammar errors, awkward phrasing, technical prose,
   ambiguous text, and text with code or markup. Each translation set must cover
   terminology, register, ambiguity, technical prose, and structured text. Three
   runs per passage can expose output variance, but this sample size is a pilot
   choice, not a statistically proven threshold.
3. Use the current production proofreading prompt and schema without changes.
   Send the schema directly to OpenRouter so stale Emacs metadata does not change
   the model comparison. Use one fixed prompt and schema for Chinese-to-English
   translation and another fixed prompt and schema for English-to-Chinese
   translation.
4. Set `provider.require_parameters: true`. Do not enable response healing. Count
   invalid JSON and schema violations as hard failures in all tracks. In the
   polishing track, also count wrong text ranges and mismatched selected text as
   hard failures.
5. Keep each model's supported reasoning level fixed. Start with Terra and Luna
   at `none`, Gemini 3.7 at `low`, Gemini 3.5 Flash-Lite at `minimal`, and DeepSeek
   at `low`. Test a higher level only when the baseline shows a quality problem.
6. Record wall-clock latency and the response `usage` fields for input, output,
   reasoning tokens, and charged cost
   ([OpenRouter usage accounting](https://openrouter.ai/docs/cookbook/administration/usage-accounting)).
   Send `X-OpenRouter-Metadata: enabled` and record the selected provider, model,
   attempt count, and service tier
   ([router metadata](https://openrouter.ai/docs/guides/features/router-metadata)).
7. Hide model and provider names. Randomize model order and left/right order.
   For English polishing, score issue detection, false positives, suggestion
   naturalness, meaning preservation, and unnecessary rewriting. A correct
   passage must usually produce an empty diagnostic list. For each translation
   direction, score meaning, terminology, target-language naturalness, register,
   and format preservation. Use raters who can judge the target language.
8. Compare Terra and Gemini 3.7 first in the English-polishing track. Add Luna and
   Gemini 3.5 Flash-Lite after that comparison. Add Hy-MT2 to both translation
   tracks. Add DeepSeek only with a schema-capable route. This staged order
   reduces human review work without mixing scores across the three tasks.
9. After selection, correct the local model metadata if necessary and run the
   English-polishing winner through the real Emacs proofreader. The direct
   OpenRouter test does not verify the end-to-end Emacs path. Verify each
   translation winner in its production integration separately.

OpenMark supports the need for task-specific tests, but not the model-quality
order. Its translation benchmark uses keyword and accepted-variant checks and
does not test subjective fluency or naturalness
([OpenMark translation method](https://openmark.ai/best-ai-for-translation)). Its
writing benchmark measures constraint following, not subjective writing quality
([OpenMark writing method](https://openmark.ai/best-ai-for-writing)). Use these
pages only as secondary evidence about OpenMark's own method.

## Production verification

After the human reviewer selects the English-polishing winner:

1. Update only the gitignored `lisp/init-local-proofread-config.el`: use
   `https://openrouter.ai/api/v1/` as the endpoint, `openrouter.ai` as the
   auth-source host, and the selected OpenRouter model ID as the chat model.
   Set `ml-proofread-provider-identity` to a new non-secret value that includes
   the selected model ID, and update `ml-proofread-source-label` to name that
   model. Keep the API key in `auth-source`; never put it in the config file.
2. Restart Emacs so the checker uses a new provider object and cache identity.
3. Run the production Proofread checker on the five committed polishing cases.
   Confirm that the correct case returns no diagnostics, reported ranges select
   the exact source text, suggestions are usable, and no JSON or schema error
   occurs.
4. Record the result in the local Evaluation Run directory. Do not change a
   committed configuration file and do not select a translation integration as
   part of this task.

## Verification limits

No candidate was called during this research. No output quality, schema success
rate, latency, or route stability was measured. OpenRouter routes, prices, and
capabilities can change after the verification date. The recommendations remain
provisional until all three task-specific evaluations are complete.
