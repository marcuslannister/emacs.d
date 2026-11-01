;;; init-local-append-review.el --- Append-and-review note in Org -*- lexical-binding: t; -*-
;;; Commentary:
;; Karpathy's append-and-review note: one flat Org file, new notes go on
;; top, and review moves notes worth keeping back to the top.
;; Research: docs/research/append-and-review-note-org.md
;;; Code:

(defvar org-capture-templates)
(defvar org-reverse-note-order)
(declare-function org-refile "org-refile")
(declare-function org-capture "org-capture")

(defvar init-local-append-review-file "append-and-review.org"
  "Append-and-review note file, relative to `org-directory'.")

(with-eval-after-load 'org-capture
  (add-to-list 'org-capture-templates
               `("a" "append-and-review" entry (file ,init-local-append-review-file)
                 "* %?" :prepend t)
               t))

(defun init-local-append-review-capture ()
  "Capture a new note at the top of `init-local-append-review-file'."
  (interactive)
  (org-capture nil "a"))

(defun init-local-append-review-to-top ()
  "Move the subtree at point to the top of the current Org file."
  (interactive)
  (unless buffer-file-name
    (user-error "This buffer does not visit a file"))
  (require 'org-refile)
  (let ((org-reverse-note-order t))
    (org-refile nil nil (list (file-name-nondirectory buffer-file-name)
                              buffer-file-name nil nil))))

(provide 'init-local-append-review)
;;; init-local-append-review.el ends here
