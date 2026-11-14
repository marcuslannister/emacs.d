;;; init-local-proofread-tests.el --- Proofreading tests -*- lexical-binding: t -*-
;;; Commentary:
;; Run in batch Emacs.  Requests are stubbed; no text leaves this process.
;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'warnings)
(require 'auth-source)
(require 'smerge-mode)

(defmacro use-package (&rest _) nil)
(defvar my/proofread-test-bindings nil)
(defun my/hel-leader-bind (key command)
  (push (cons key command) my/proofread-test-bindings))
(defun make-llm-openai-compatible (&rest args) args)
(defun llm-make-chat-prompt (&rest args) args)
(defun llm-chat-async (&rest _))
(provide 'llm-openai)

(load-file (expand-file-name "../user-lisp/init-local-proofread.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(defmacro my/proofread-test-with-region (&rest body)
  "Run BODY with a selected region and test-only endpoint settings."
  (declare (indent 0))
  `(let ((my/proofread-endpoint-url "https://example.test/v1/")
         (my/proofread-chat-model "test-model")
         (my/proofread-model nil)
         (my/proofread-chat-params '((temperature . 0.2)))
         (my/proofread-model-metadata nil)
         (user-emacs-directory (expand-file-name "missing-proofread-tests/"
                                                 temporary-file-directory))
         (transient-mark-mode t))
     (with-temp-buffer
       (insert "This are a test.")
       (set-mark (point-min))
       (activate-mark)
       ,@body)))

(ert-deftest init-local-proofread-leader-command ()
  (should (eq (cdr (assoc "C-c g p" my/proofread-test-bindings)) #'my/proofread-region)))

(ert-deftest init-local-proofread-request-and-prefix ()
  (dolist (aggressive '(nil t))
    (my/proofread-test-with-region
      (let ((my/proofread-model "override") request)
        (cl-letf (((symbol-function 'llm-chat-async)
                   (lambda (&rest args) (setq request args))))
          (my/proofread-region (point-min) (point-max) aggressive))
        (should (equal (plist-get (car request) :chat-model) "override"))
        (should (equal (plist-get (car request) :default-chat-non-standard-params)
                       my/proofread-chat-params))
        (should (functionp (plist-get (car request) :key)))
        (should (equal (cadr request)
                       (list "This are a test." :context
                             (if aggressive my/proofread-aggressive-prompt
                               my/proofread-gentle-prompt))))
        (should (string-match-p "This are a test\\.\n\n=======\n…" (buffer-string)))
        (goto-char (point-min))
        (insert "Edit before reply\n")
        (funcall (nth 2 request) "This is a test.")
        (should (string-prefix-p "Edit before reply\n<<<<<<< Original\n" (buffer-string)))
        (should (string-match-p "=======\nThis is a test\\.\n>>>>>>>" (buffer-string)))
        (should (member 'smerge-refined-removed
                        (mapcar (lambda (o) (overlay-get o 'font-lock-face))
                                (overlays-in (point-min) (point-max)))))))))

(ert-deftest init-local-proofread-trailing-newline ()
  (my/proofread-test-with-region
    (insert "\n")
    (my/proofread-region (point-min) (point-max))
    (should (string-match-p "test\\.\n\n=======\n" (buffer-string)))))

(ert-deftest init-local-proofread-requires-region-and-settings ()
  (my/proofread-test-with-region
    (deactivate-mark)
    (should-error (my/proofread-region (point-min) (point-max)) :type 'user-error)
    (activate-mark)
    (let ((my/proofread-endpoint-url nil))
      (should-error (my/proofread-region (point-min) (point-max)) :type 'user-error))
    (should (equal (buffer-string) "This are a test."))))

(ert-deftest init-local-proofread-error-keeps-original ()
  (dolist (synchronous '(nil t))
    (my/proofread-test-with-region
      (cl-letf (((symbol-function 'llm-chat-async)
                 (lambda (_provider _prompt _success failure)
                   (if synchronous (error "offline") (funcall failure 'network "offline")))))
        (my/proofread-region (point-min) (point-max)))
      (should (string-match-p "<<<<<<< Original\nThis are a test\\." (buffer-string)))
      (should (string-match-p "Proofread error: .*offline" (buffer-string))))))

(ert-deftest init-local-proofread-reply-does-not-overwrite-user-edit ()
  (my/proofread-test-with-region
    (let (reply warned)
      (cl-letf (((symbol-function 'llm-chat-async)
                 (lambda (_provider _prompt success _failure) (setq reply success)))
                ((symbol-function 'display-warning) (lambda (&rest _) (setq warned t))))
        (my/proofread-region (point-min) (point-max))
        (goto-char (point-min))
        (search-forward "…")
        (delete-char -1)
        (insert "My edit")
        (funcall reply "Correction")
        (should warned)
        (should (string-match-p "My edit" (buffer-string)))
        (should-not (string-match-p "Correction" (buffer-string)))))))

(ert-deftest init-local-proofread-reply-for-killed-buffer ()
  (let (reply)
    (my/proofread-test-with-region
      (cl-letf (((symbol-function 'llm-chat-async)
                 (lambda (_provider _prompt success _failure) (setq reply success))))
        (my/proofread-region (point-min) (point-max))))
    (funcall reply "Correction")))

(provide 'init-local-proofread-tests)
;;; init-local-proofread-tests.el ends here
