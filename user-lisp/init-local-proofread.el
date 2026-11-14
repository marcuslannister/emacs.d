;;; init-local-proofread.el --- Proofread selected text -*- lexical-binding: t -*-
;;; Commentary:
;; SPC g p keeps the original and inserts a suggestion in a merge conflict.
;; A prefix argument asks for a freer rewrite.  Only the selected text is sent.
;; Endpoint settings live in the ignored init-local-proofread-config.el file.
;;; Code:

(declare-function my/hel-leader-bind "init-local-hel")
(declare-function auth-source-pick-first-password "auth-source")
(declare-function make-llm-openai-compatible "llm-openai")
(declare-function llm-make-chat-prompt "llm")
(declare-function llm-chat-async "llm")
(declare-function llm-models-match "llm-models")
(declare-function llm-models-add "llm-models")
(declare-function smerge-match-conflict "smerge-mode")
(declare-function smerge-refine-regions "smerge-mode")

(use-package llm
  :ensure t
  :defer t)

(defvar my/proofread-endpoint-url nil "OpenAI-compatible base URL, ending in a slash.")
(defvar my/proofread-auth-host nil "Host of the API key in auth-source.")
(defvar my/proofread-auth-user "apikey" "User of the API key in auth-source.")
(defvar my/proofread-chat-model nil "Default proofreading model.")
(defvar my/proofread-model nil "Optional model override for selected text.")
(defvar my/proofread-chat-params nil "Non-standard parameters sent to the model.")
(defvar my/proofread-model-metadata nil "Optional arguments for `llm-models-add'.")

(defconst my/proofread-gentle-prompt
  (concat "Correct spelling, punctuation, and grammar in this text. Use natural "
          "international workplace English. Keep the meaning, tone, word choice, "
          "line breaks, and formatting. Change only what is necessary. "
          "Return only the corrected text."))

(defconst my/proofread-aggressive-prompt
  (concat "Rewrite this text in clear, concise international workplace English. "
          "Keep its meaning and factual claims. Use active voice when it improves "
          "clarity. Keep line breaks and formatting where possible. "
          "Return only the revised text."))

(defun my/proofread--reply (buffer beg end response)
  "Insert RESPONSE between markers BEG and END in BUFFER, then release them."
  (unwind-protect
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          ;; Do not overwrite text that the user changed while waiting.
          (if (not (equal (buffer-substring-no-properties beg end) "…"))
              (display-warning 'init-local-proofread
                               "Proofread reply skipped: the placeholder changed.")
            (save-excursion
              (goto-char beg)
              (atomic-change-group
                (delete-region beg end)
                (insert response))
              ;; Refinement needs an external diff program.  Keep the reply if it fails.
              (ignore-errors
                (require 'smerge-mode)
                (smerge-match-conflict)
                (smerge-refine-regions
                 (match-beginning 1) (match-end 1) (match-beginning 3) (match-end 3)
                 nil nil
                 '((smerge . refine) (font-lock-face . smerge-refined-removed))
                 '((smerge . refine) (font-lock-face . smerge-refined-added))))))))
    (set-marker beg nil)
    (set-marker end nil)))

(defun my/proofread-region (start end &optional aggressive)
  "Proofread the selected text between START and END.
With prefix argument AGGRESSIVE, ask for a freer rewrite.
The selected text is sent to the endpoint in the private configuration."
  (interactive "r\nP")
  (unless (use-region-p)
    (user-error "Select text to proofread"))
  (barf-if-buffer-read-only)
  (load (locate-user-emacs-file "user-lisp/init-local-proofread-config.el") t t)
  (unless (and my/proofread-endpoint-url
               (or my/proofread-model my/proofread-chat-model))
    (user-error "Set the endpoint and model in init-local-proofread-config.el"))
  (unless (require 'llm-openai nil t)
    (user-error "Install the llm package to use proofreading"))
  (require 'auth-source)
  (when (and my/proofread-model-metadata
             (not (llm-models-match (or my/proofread-model my/proofread-chat-model))))
    (apply #'llm-models-add my/proofread-model-metadata))
  (let* ((buffer (current-buffer))
         (provider (make-llm-openai-compatible
                    :url my/proofread-endpoint-url
                    :key (lambda ()
                           (auth-source-pick-first-password
                            :host my/proofread-auth-host :user my/proofread-auth-user))
                    :chat-model (or my/proofread-model my/proofread-chat-model)
                    :default-chat-non-standard-params my/proofread-chat-params))
         (prompt (llm-make-chat-prompt
                  (buffer-substring-no-properties start end)
                  :context (if aggressive my/proofread-aggressive-prompt
                             my/proofread-gentle-prompt)))
         beg finish)
    (save-excursion
      (atomic-change-group
        (goto-char end)
        (unless (bolp) (insert "\n"))
        ;; A blank line prevents Markdown from treating the separator as a heading.
        (insert "\n=======\n")
        (setq beg (point-marker))
        (insert "…")
        (setq finish (point-marker))
        (insert (format "\n>>>>>>> Proofread (%s)\n" (if aggressive "aggressive" "gentle")))
        (goto-char start)
        (insert "<<<<<<< Original\n")))
    (let ((failure (lambda (kind message)
                     (my/proofread--reply buffer beg finish
                                          (format "Proofread error: %s: %s" kind message)))))
      (condition-case err
          (llm-chat-async provider prompt
                          (lambda (text) (my/proofread--reply buffer beg finish text))
                          failure)
        (error (funcall failure (car err) (error-message-string err)))))))

(my/hel-leader-bind "C-c g p" #'my/proofread-region)

(provide 'init-local-proofread)
;;; init-local-proofread.el ends here
