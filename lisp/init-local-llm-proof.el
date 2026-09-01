;;; init-local-llm-proof.el --- Proofread the region -*- lexical-binding: t; -*-
;;; Commentary:

;; Proofread selected text with the `llm' package, over the same private
;; OpenAI-compatible endpoint as `init-local-proofread'.
;;
;; The model comes from the gitignored `init-local-proofread-config.el': it
;; follows `ml-proofread-chat-model' unless that file sets `ml-llm-proof-model'
;; to a different one.
;;
;; Adapted from Ben Simon's gptel-proof.el:
;; https://github.com/benjisimon/elisp/blob/main/gptel-proof.el

;;; Code:

(require 'llm)
(require 'llm-openai)
(require 'smerge-mode)
(require 'init-local-proofread)

;; A `defvar' keeps the value the private config already gave this variable, so
;; the fallback below runs only when that config stays quiet.
(defvar ml-llm-proof-model ml-proofread-chat-model
  "Name of the model used by `ml-llm-proof'.
Set in `init-local-proofread-config.el' to proofread selected text
with a model other than `ml-proofread-chat-model'.  It still sends
`ml-proofread-chat-params' with every request.")

(defvar ml-llm-proof-gentle-prompt
  (concat "Proofread the following text for spelling, punctuation, grammar, "
          "and natural international workplace English. Preserve its meaning, "
          "word choice, tone, line breaks, and formatting. Make only necessary "
          "changes. Output only the corrected text.")
  "System prompt that asks for corrections only.")

(defvar ml-llm-proof-aggressive-prompt
  (concat "Polish the following text as natural, clear, concise international "
          "workplace English. Preserve its meaning and factual claims. Prefer "
          "active voice only when it is clearer, and avoid unnecessary rewriting. "
          "Preserve line breaks and formatting where possible. Output only the "
          "corrected text.")
  "System prompt that asks for a freer rewrite.")

(defconst ml-llm-proof-placeholder "…"
  "Text that holds the place of a reply that has not arrived.")

(defun ml-llm-proof-apply-fix (buffer beg end correction)
  "Replace the text between BEG and END in BUFFER with CORRECTION.
BEG and END are markers, so they follow their text through any edit
that lands while the reply is in flight, and no two requests can name
the same place.  Colour the words that differ between the two halves,
so you read the change instead of both texts."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (save-excursion
        (goto-char beg)
        (delete-region beg end)
        (insert correction)
        ;; Point sits in the lower half, so the conflict is the one at point.
        ;; Refinement needs the `diff' program and well-formed markers, and
        ;; neither failure may cost the correction itself.
        (ignore-errors (ml-llm-proof--refine)))))
  (set-marker beg nil)
  (set-marker end nil))

(defun ml-llm-proof--refine ()
  "Colour the words that differ between the halves of the conflict at point.
`smerge-refine' paints both halves with `smerge-refined-change' as soon
as a theme defines that face, which loses the direction of the change,
so drive the same refinement with the added and removed faces instead."
  (smerge-match-conflict)
  (remove-overlays (match-beginning 0) (match-end 0) 'smerge 'refine)
  (smerge-refine-regions (match-beginning 1) (match-end 1)
                         (match-beginning 3) (match-end 3)
                         nil nil
                         '((smerge . refine)
                           (font-lock-face . smerge-refined-removed))
                         '((smerge . refine)
                           (font-lock-face . smerge-refined-added))))

(defun ml-llm-proof (start end &optional aggressive)
  "Proofread the region between START and END.
With prefix argument AGGRESSIVE, polish more freely."
  (interactive "r\nP")
  (unless (use-region-p)
    (user-error "No region selected"))
  (unless ml-llm-proof-model
    (user-error "No model: set `ml-llm-proof-model' in the private proofread config"))
  (let* ((buffer (current-buffer))
         (input (buffer-substring-no-properties start end))
         (start-conflict "<<<<<<< Original\n")
         reply-beg reply-end)
    (save-excursion
      (goto-char start)
      (insert start-conflict)
      (goto-char (+ end (length start-conflict)))
      ;; The blank line keeps Markdown from reading `=======' as a setext
      ;; heading underline, which fontifies the last original line as a
      ;; heading.  `smerge-mode' still parses the conflict, because the
      ;; separator stays bare.  A region that ends mid-line needs one more
      ;; newline to close it, or the blank line is the only one there is.
      (unless (bolp) (insert "\n"))
      (insert "\n=======\n")
      ;; Markers, not a search string: they hold this one place through any
      ;; edit that lands first, and they cannot name another request's place.
      (setq reply-beg (point-marker))
      (insert ml-llm-proof-placeholder)
      ;; Both markers keep the default insertion type, so the closing marker
      ;; stays put when the rest of the block goes in after it.
      (setq reply-end (point-marker))
      (insert (format "\n>>>>>>> Proofread (%s)\n"
                      (if aggressive "aggressive" "gentle"))))
    (llm-chat-async
     (ml-proofread--provider ml-llm-proof-model ml-proofread-chat-params)
     (llm-make-chat-prompt input
                           :context (if aggressive
                                        ml-llm-proof-aggressive-prompt
                                      ml-llm-proof-gentle-prompt))
     (lambda (response)
       (ml-llm-proof-apply-fix buffer reply-beg reply-end response))
     (lambda (err msg)
       (set-marker reply-beg nil)
       (set-marker reply-end nil)
       (message "Proofread error: %s: %s" err msg)))))

(provide 'init-local-llm-proof)
;;; init-local-llm-proof.el ends here
