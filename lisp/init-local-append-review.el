;;; init-local-append-review.el --- Append-and-review note in Org -*- lexical-binding: t; -*-
;;; Commentary:
;; Karpathy's append-and-review note: one Org file, new notes go on
;; top, and review moves notes worth keeping back to the top.  The file
;; has top-level sections (Today, Inbox); notes are their children.
;; Research: docs/research/append-and-review-note-org.md
;;; Code:

(defvar org-capture-templates)
(defvar org-reverse-note-order)
(defvar org-refile-targets)
(defvar org-directory)
(declare-function org-refile "org-refile")
(declare-function org-capture "org-capture")
(declare-function org-current-level "org")
(declare-function org-match-sparse-tree "org")

(defvar init-local-append-review-file "notes.org"
  "Append-and-review note file, relative to `org-directory'.")

(with-eval-after-load 'org-capture
  (add-to-list 'org-capture-templates
               `("a" "append-and-review" entry
                 (file+headline ,init-local-append-review-file "Inbox")
                 "* %?" :prepend t)
               t))

(defun init-local-append-review-open ()
  "Open `init-local-append-review-file'."
  (interactive)
  (find-file (expand-file-name init-local-append-review-file org-directory)))

(defun init-local-append-review-show-tag ()
  "Open `init-local-append-review-file' and show only the notes with a tag."
  (interactive)
  (init-local-append-review-open)
  (call-interactively #'org-match-sparse-tree))

(defun init-local-append-review-capture ()
  "Capture a new note at the top of the inbox section."
  (interactive)
  (org-capture nil "a"))

(defun init-local-append-review-to-top ()
  "Move the subtree at point to the top of a top-level section of this file.
Pick its own section to move it back to the top."
  (interactive)
  (unless buffer-file-name
    (user-error "This buffer does not visit a file"))
  (when (eq (org-current-level) 1)
    (user-error "Put point on a note, not on a section"))
  (require 'org-refile)
  (let ((org-reverse-note-order t)
        (org-refile-targets '((nil :level . 1))))
    (org-refile)))

(provide 'init-local-append-review)
;;; init-local-append-review.el ends here
