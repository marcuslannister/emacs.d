;;; init-local-llm-proof.el --- Proofread the region -*- lexical-binding: t; -*-
;;; Commentary:

;; Proofread selected text with the `llm' package, over the same private
;; OpenRouter endpoint as `init-local-proofread'.
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
(require 'init-local-proofread)

;; A `defvar' keeps the value the private config already gave this variable, so
;; the fallback below runs only when that config stays quiet.
(defvar ml-llm-proof-model ml-proofread-chat-model
  "Name of the model used by `ml-llm-proof'.
Set in `init-local-proofread-config.el' to proofread selected text
with a model other than `ml-proofread-chat-model'.  Its request
parameters come from `ml-proofread--model-request-params'.")

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

(defun ml-llm-proof-apply-fix (buffer marker correction)
  "Replace MARKER in BUFFER with CORRECTION."
  (with-current-buffer buffer
    (goto-char (point-min))
    (when (re-search-forward (regexp-quote marker) nil t)
      (replace-match correction t t))))

(defun ml-llm-proof (start end &optional aggressive)
  "Proofread the region between START and END.
With prefix argument AGGRESSIVE, polish more freely."
  (interactive "r\nP")
  (unless (use-region-p)
    (user-error "No region selected"))
  (unless ml-llm-proof-model
    (user-error "No model: set `ml-llm-proof-model' in the private proofread config"))
  (let* ((marker (format "{proof:%s}" (gensym)))
         (buffer (current-buffer))
         (input (buffer-substring-no-properties start end))
         (start-conflict "<<<<<<< Original\n"))
    (save-excursion
      (goto-char start)
      (insert start-conflict)
      (goto-char (+ end (length start-conflict)))
      ;; The blank line keeps Markdown from reading `=======' as a setext
      ;; heading underline, which fontifies the last original line as a
      ;; heading.  `smerge-mode' still parses the conflict, because the
      ;; separator stays bare.
      (insert (format "\n=======\n%s\n>>>>>>> Proofread (%s)\n"
                      marker (if aggressive "aggressive" "gentle"))))
    (llm-chat-async
     (ml-proofread--provider ml-llm-proof-model
                             (ml-proofread--model-request-params
                              ml-llm-proof-model))
     (llm-make-chat-prompt input
                           :context (if aggressive
                                        ml-llm-proof-aggressive-prompt
                                      ml-llm-proof-gentle-prompt))
     (lambda (response)
       (ml-llm-proof-apply-fix buffer marker response))
     (lambda (err msg)
       (message "Proofread error: %s: %s" err msg)))))

(provide 'init-local-llm-proof)
;;; init-local-llm-proof.el ends here
