;;; init-local-append-review-tests.el --- Append-and-review note tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-append-review-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar org-directory)
(defvar org-reverse-note-order)
(defvar org-refile-targets)
(defvar org-bookmark-names-plist)
(defvar org-capture-templates)
(defvar bookmark-save-flag)

(defvar init-local-append-review-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-append-review-tests--keys)))

;; Load with deferral, so the `use-package' form waits for org-capture.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil))
  (load (expand-file-name "../user-lisp/init-local-append-review.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

(defmacro init-local-append-review-tests--with-notes (content &rest body)
  "Run BODY in a buffer that visits a notes file with CONTENT, in a temp `org-directory'."
  (declare (indent 1))
  `(let* ((dir (file-name-as-directory (make-temp-file "append-review-test" t)))
          (org-directory dir)
          (my/append-review-file "notes.org")
          ;; Refile sets a bookmark, and a bookmark can write a file in the user folder.
          (org-bookmark-names-plist nil)
          (bookmark-save-flag nil)
          (file (expand-file-name "notes.org" dir))
          buf)
     (write-region ,content nil file)
     (unwind-protect
         (progn
           (setq buf (find-file-noselect file))
           (with-current-buffer buf ,@body))
       (when (buffer-live-p buf)
         (with-current-buffer buf (set-buffer-modified-p nil))
         (kill-buffer buf))
       (delete-directory dir t))))

(defconst init-local-append-review-tests--notes
  "* Today\n** old\n* Inbox\n** n1\n** n2\n")

(ert-deftest init-local-append-review-moves-a-note-to-the-top-of-today ()
  (init-local-append-review-tests--with-notes init-local-append-review-tests--notes
    (org-mode)
    (goto-char (point-min))
    (re-search-forward "^\\*\\* n2")
    (my/append-review-to-today)
    (should (equal "* Today\n** n2\n** old\n* Inbox\n** n1\n" (buffer-string)))))

(ert-deftest init-local-append-review-moves-a-note-to-the-top-of-the-inbox ()
  (init-local-append-review-tests--with-notes init-local-append-review-tests--notes
    (org-mode)
    (goto-char (point-min))
    (re-search-forward "^\\*\\* old")
    (my/append-review-to-inbox)
    (should (equal "* Today\n* Inbox\n** old\n** n1\n** n2\n" (buffer-string)))))

(ert-deftest init-local-append-review-refuses-a-section ()
  (init-local-append-review-tests--with-notes init-local-append-review-tests--notes
    (org-mode)
    (goto-char (point-min))
    (should-error (my/append-review-to-today) :type 'user-error)
    (should (equal init-local-append-review-tests--notes (buffer-string)))))

(ert-deftest init-local-append-review-refuses-a-buffer-without-a-file ()
  (with-temp-buffer
    (org-mode)
    (insert "* Today\n** old\n")
    (should-error (my/append-review-to-today) :type 'user-error)))

(ert-deftest init-local-append-review-names-a-missing-section ()
  (init-local-append-review-tests--with-notes "* Inbox\n** n1\n"
    (org-mode)
    (goto-char (point-max))
    (forward-line -1)
    (let ((err (should-error (my/append-review-to-today) :type 'user-error)))
      (should (string-match-p "No \"Today\" section" (error-message-string err))))))

(ert-deftest init-local-append-review-asks-for-a-section-with-the-right-order ()
  (let (seen)
    (init-local-append-review-tests--with-notes init-local-append-review-tests--notes
      (org-mode)
      (goto-char (point-min))
      (re-search-forward "^\\*\\* n1")
      (cl-letf (((symbol-function 'org-refile)
                 (lambda (&rest args)
                   (push (list args org-reverse-note-order org-refile-targets) seen))))
        (my/append-review-to-top)
        (my/append-review-to-bottom)))
    (should (equal '((nil t ((nil :level . 1)))
                     (nil nil ((nil :level . 1))))
                   (reverse seen)))))

(ert-deftest init-local-append-review-registers-the-capture-template ()
  (require 'org-capture)
  (let ((template (assoc "a" org-capture-templates)))
    (should template)
    (should (equal '(file+headline "notes.org" "Inbox") (nth 3 template)))
    (should (member :prepend template))))

(ert-deftest init-local-append-review-keys-run-defined-commands ()
  (should init-local-append-review-tests--keys)
  (dolist (binding init-local-append-review-tests--keys)
    (should (fboundp (cdr binding)))))

(provide 'init-local-append-review-tests)
;;; init-local-append-review-tests.el ends here
