;;; init-local-llm-proof-tests.el --- Tests for region proofreading -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Stand in for the module's dependencies: `llm' supplies the provider struct
;; and the async call, and the gitignored private config names the model.
(cl-defstruct (llm-openrouter (:constructor make-llm-openrouter)))
(cl-defun llm-make-chat-prompt (content &key context &allow-other-keys)
  (list 'prompt content context))
(defun llm-chat-async (&rest _args))
(provide 'llm)
(provide 'llm-openai)

(defvar ml-proofread-chat-model "google/gemini-3.7-flash")
(defun ml-proofread--model-request-params (model)
  (and (equal model "google/gemini-3.7-flash")
       '((provider . ((order . ["a-route"]))))))
(defun ml-proofread--provider (model params)
  (list 'openrouter-provider model params))
(provide 'init-local-proofread)

(load-file
 (expand-file-name "../lisp/init-local-llm-proof.el"
                   (file-name-directory load-file-name)))

(defun init-local-llm-proof-tests--request (&optional aggressive)
  "Return the `llm-chat-async' arguments a proofread of a region sends."
  (let (request)
    (cl-letf (((symbol-function 'llm-chat-async)
               (lambda (&rest args) (setq request args))))
      (with-temp-buffer
        (insert "Please improve this sentence.")
        (set-mark (point-min))
        (goto-char (point-max))
        (activate-mark)
        (let ((transient-mark-mode t))
          (ml-llm-proof (region-beginning) (region-end) aggressive))))
    request))

(ert-deftest init-local-llm-proof-uses-the-private-provider ()
  (let ((request (init-local-llm-proof-tests--request)))
    (should (equal (nth 0 request)
                   '(openrouter-provider "google/gemini-3.7-flash"
                                         ((provider . ((order . ["a-route"])))))))
    (should (equal (nth 1 request)
                   (list 'prompt "Please improve this sentence."
                         ml-llm-proof-gentle-prompt)))))

(ert-deftest init-local-llm-proof-drops-a-route-the-model-does-not-share ()
  "A config model other than the proofread one starts with no parameters."
  (let* ((ml-llm-proof-model "other/model")
         (request (init-local-llm-proof-tests--request)))
    (should (equal (nth 0 request) '(openrouter-provider "other/model" nil)))))

(ert-deftest init-local-llm-proof-polishes-with-a-prefix-argument ()
  (let ((request (init-local-llm-proof-tests--request t)))
    (should (equal (nth 2 (nth 1 request)) ml-llm-proof-aggressive-prompt))))

(ert-deftest init-local-llm-proof-inserts-the-response-at-the-marker ()
  (with-temp-buffer
    (insert "before {proof:g1} after")
    (ml-llm-proof-apply-fix (current-buffer) "{proof:g1}" "corrected")
    (should (equal (buffer-string) "before corrected after"))))

(ert-deftest init-local-llm-proof-colours-what-changed ()
  "The words that differ carry a smerge refinement face."
  (with-temp-buffer
    (insert "<<<<<<< Original\nI have discussed the plan.\n"
            "\n=======\n{proof:g1}\n>>>>>>> Proofread (gentle)\n")
    (ml-llm-proof-apply-fix (current-buffer) "{proof:g1}"
                            "I discussed the plan.")
    (should (member 'smerge-refined-removed
                    (mapcar (lambda (o) (overlay-get o 'font-lock-face))
                            (overlays-in (point-min) (point-max)))))))

(provide 'init-local-llm-proof-tests)
;;; init-local-llm-proof-tests.el ends here
