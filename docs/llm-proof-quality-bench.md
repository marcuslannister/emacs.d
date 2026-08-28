# ml-llm-proof quality bench

A manual bench for the region proofreading command in
`lisp/init-local-llm-proof.el`. Use it to judge a model before you set it in
the private `lisp/init-local-proofread-config.el`, and to compare two models on
the same text.

Each case has an input to proofread and, at the bottom, a scoring key: the
mistakes a good pass must fix, and the things it must leave alone. Run the
gentle pass unless the case says otherwise, then score the output against the
key. A model that fixes every listed mistake and touches nothing else scores
full marks.

Load first:

    M-x load-library RET init-local-proofread RET
    M-x load-library RET init-local-llm-proof RET

`M-x ml-llm-proof` on the region, `C-u M-x ml-llm-proof` for the aggressive
pass.

---

## Case 1 — grammar and tense (gentle)

Yesterday I have discussed with the team about the new release plan, and we
decide to postpone it one week. The main reason is that two of test environment
was not ready, and the QA colleagues cannot to finish the regression before
Friday. I will send a mail to inform everyone tomorrow morning, please let me
know if you have any question about this arrangement.

## Case 2 — incident note, must stay factual (gentle)

The bug is happened when user click the export button twice in quick. We are
still investigate the root cause, but we think it related to a race condition
in the download handler. A workaround have been deployed to production at
14:30, and no new report was came in since then.

## Case 3 — wordiness (aggressive)

It is my personal opinion that, at this point in time, we should probably
consider the possibility of maybe reducing the total number of meetings that
are currently being held on a weekly basis, due to the fact that a significant
proportion of the attendees have expressed the view that these meetings are not
always necessarily the most productive use of the time available to them.

## Case 4 — structure must survive (gentle)

Steps to reproduce:

1. Open the setting page and scroll to bottom.
2. Click on "Advanced", than toggle the sync switch.
3. Waiting about ten seconds for the spinner disappear.

Expected: the switch stay on after refresh the page.
Actual: the switch is reset to off, and a error toast is showed.

## Case 5 — restraint (gentle)

The migration ran on Tuesday and finished in 40 minutes. We saw no errors in
the logs, so we kept the old table for one more week as a fallback.

## Case 6 — code must not be touched (gentle)

Select the prose and the block together:

The function below replaces the marker with the correction. Note it search from
the beginning of buffer, so a duplicated marker would be wrong replaced.

```elisp
(defun ml-llm-proof-apply-fix (buffer marker correction)
  "Replace MARKER in BUFFER with CORRECTION."
  (with-current-buffer buffer
    (goto-char (point-min))
    (when (re-search-forward (regexp-quote marker) nil t)
      (replace-match correction t t))))
```

---

# Scoring key

## Case 1 — 7 mistakes

1. `I have discussed` → `I discussed` (past simple with "yesterday")
2. `discussed with the team about` → `discussed ... with the team` (no "about")
3. `we decide` → `we decided`
4. `two of test environment was` → `two of the test environments were`
5. `cannot to finish` → `cannot finish`
6. `any question` → `any questions`
7. comma splice before `please let me know` → full stop or `;`

Must not change: "mail" → "email" is acceptable, but rewriting the arrangement
or adding a greeting is over-reach.

## Case 2 — 6 mistakes, facts frozen

1. `is happened` → `happens` / `occurs`
2. `user click` → `a user clicks`
3. `twice in quick` → `twice in quick succession`
4. `are still investigate` → `are still investigating`
5. `we think it related` → `we think it is related`
6. `have been deployed` → `was deployed`; `no new report was came in` → `no new
   reports have come in`

Must not change: `14:30`, "race condition", "download handler". A model that
softens "we think" into "we have confirmed" fails the case.

## Case 3 — aggressive pass

A good rewrite lands near: *"I think we should hold fewer weekly meetings. Many
attendees say the meetings are not a productive use of their time."*

Score it on: under 30 words, hedges gone ("personal opinion", "at this point in
time", "probably", "maybe", "not always necessarily"), meaning kept, no new
claim invented. The gentle pass on this same paragraph should *not* produce
this — that difference is what tells you the two prompts are wired correctly.

## Case 4 — 6 mistakes, shape frozen

1. `the setting page` → `the settings page`
2. `scroll to bottom` → `scroll to the bottom`
3. `than toggle` → `then toggle`
4. `Waiting about ten seconds for the spinner disappear` → `Wait about ten
   seconds for the spinner to disappear`
5. `the switch stay on after refresh the page` → `the switch stays on after the
   page is refreshed`
6. `a error toast is showed` → `an error toast is shown`

Must not change: the numbered list stays a numbered list, three items, and the
`Expected:` / `Actual:` lines stay on their own lines.

## Case 5 — the null case

Correct English already. A good gentle pass returns it unchanged, or changes at
most one word. Any rewrite here means the prompt is too aggressive, and every
routine edit will arrive with noise you have to review.

## Case 6 — 2 prose mistakes, code frozen

1. `it search from the beginning of buffer` → `it searches from the beginning of
   the buffer`
2. `would be wrong replaced` → `would be replaced incorrectly`

Must not change: a single character inside the fenced block, including the
docstring. This is the case most models fail.

---

# Comparing two models

Set the model in the private config, restart or reload the module, and run the
same six cases:

    ;; lisp/init-local-proofread-config.el
    (setq ml-llm-proof-model "OTHER-MODEL-NAME")

Score each case out of its listed mistakes, then subtract one point per
unwanted change. Cases 5 and 6 separate the good models from the eager ones.
