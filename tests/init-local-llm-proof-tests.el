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
(defvar ml-proofread-chat-params '((provider . ((order . ["a-route"])))))
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

(ert-deftest init-local-llm-proof-keeps-the-shared-params-for-another-model ()
  "A different config model still sends `ml-proofread-chat-params'."
  (let* ((ml-llm-proof-model "other/model")
         (request (init-local-llm-proof-tests--request)))
    (should (equal (nth 0 request)
                   '(openrouter-provider "other/model"
                                         ((provider . ((order . ["a-route"])))))))))

(ert-deftest init-local-llm-proof-keeps-a-blank-line-above-the-separator ()
  "Markdown reads `=======' under text as a heading, so it never sits there."
  (dolist (region '("A sentence with no trailing newline."
                    "A sentence that ends with one.\n"))
    (with-temp-buffer
      (insert region)
      (set-mark (point-min))
      (goto-char (point-max))
      (activate-mark)
      (cl-letf (((symbol-function 'llm-chat-async) #'ignore))
        (let ((transient-mark-mode t))
          (ml-llm-proof (region-beginning) (region-end))))
      (goto-char (point-min))
      (should (search-forward "\n\n=======\n" nil t)))))

(ert-deftest init-local-llm-proof-polishes-with-a-prefix-argument ()
  (let ((request (init-local-llm-proof-tests--request t)))
    (should (equal (nth 2 (nth 1 request)) ml-llm-proof-aggressive-prompt))))

(defun init-local-llm-proof-tests--placeholder (before after)
  "Insert BEFORE, the placeholder, and AFTER, and return its two markers."
  (insert before)
  (let ((beg (point-marker)))
    (insert ml-llm-proof-placeholder)
    (let ((end (point-marker)))
      (insert after)
      (list beg end))))

(ert-deftest init-local-llm-proof-replaces-the-placeholder ()
  (with-temp-buffer
    (let ((place (init-local-llm-proof-tests--placeholder "before " " after")))
      (ml-llm-proof-apply-fix (current-buffer) (nth 0 place) (nth 1 place)
                              "corrected")
      (should (equal (buffer-string) "before corrected after")))))

(ert-deftest init-local-llm-proof-follows-an-edit-above-the-placeholder ()
  "Text typed before the reply arrives moves the place with it."
  (with-temp-buffer
    (let ((place (init-local-llm-proof-tests--placeholder "before " " after")))
      (goto-char (point-min))
      (insert "TYPED WHILE WAITING\n")
      (ml-llm-proof-apply-fix (current-buffer) (nth 0 place) (nth 1 place)
                              "corrected")
      (should (equal (buffer-string)
                     "TYPED WHILE WAITING\nbefore corrected after")))))

(ert-deftest init-local-llm-proof-survives-a-killed-buffer ()
  "A reply for a buffer that is gone reports no error."
  (let (place buffer)
    (with-temp-buffer
      (setq buffer (current-buffer))
      (setq place (init-local-llm-proof-tests--placeholder "before " " after")))
    (should-not (buffer-live-p buffer))
    (ml-llm-proof-apply-fix buffer (nth 0 place) (nth 1 place) "corrected")))

(ert-deftest init-local-llm-proof-colours-what-changed ()
  "The words that differ carry a smerge refinement face."
  (with-temp-buffer
    (let ((place (init-local-llm-proof-tests--placeholder
                  "<<<<<<< Original\nI have discussed the plan.\n\n=======\n"
                  "\n>>>>>>> Proofread (gentle)\n")))
      (ml-llm-proof-apply-fix (current-buffer) (nth 0 place) (nth 1 place)
                              "I discussed the plan.")
      (should (member 'smerge-refined-removed
                      (mapcar (lambda (o) (overlay-get o 'font-lock-face))
                              (overlays-in (point-min) (point-max))))))))

(provide 'init-local-llm-proof-tests)
;;; init-local-llm-proof-tests.el ends here
