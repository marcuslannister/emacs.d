;;; init-local-append-review.el --- Append-and-review note in Org -*- lexical-binding: t -*-
;;; Commentary:
;; Karpathy's append-and-review note: one Org file, new notes go on top, and review
;; moves the notes worth keeping back to the top.  The file has top-level sections
;; (Today, Inbox); the notes are their children.  The file is `my/append-review-file'
;; in `org-directory'.
;;; Code:

(defvar org-directory)
(defvar org-reverse-note-order)
(defvar org-refile-targets)
(declare-function org-capture "org-capture")
(declare-function org-current-level "org")
(declare-function org-find-exact-headline-in-buffer "org")
(declare-function org-match-sparse-tree "org")
(declare-function org-refile "org-refile")
(declare-function my/hel-leader-bind "init-local-hel")

(defcustom my/append-review-file "notes.org"
  "File of the append-and-review note, relative to `org-directory'."
  :type 'string
  :group 'org)

(defun my/append-review--path ()
  "Return the absolute name of the append-and-review file."
  (expand-file-name my/append-review-file org-directory))

(use-package org-capture
  :ensure nil
  :config
  (add-to-list 'org-capture-templates
               `("a" "append-and-review" entry
                 (file+headline ,my/append-review-file "Inbox")
                 "* %?" :prepend t)
               t))

(defun my/append-review-open ()
  "Open the append-and-review file."
  (interactive)
  (find-file (my/append-review--path)))

(defun my/append-review-show-tag ()
  "Open the append-and-review file and show only the notes with a tag."
  (interactive)
  (my/append-review-open)
  (call-interactively #'org-match-sparse-tree))

(defun my/append-review-capture ()
  "Capture a new note at the top of the Inbox section."
  (interactive)
  (org-capture nil "a"))

(defun my/append-review--check-note ()
  "Signal a user error unless point is on a note in a file buffer."
  (unless buffer-file-name
    (user-error "This buffer does not visit a file"))
  (when (eq (org-current-level) 1)
    (user-error "Put point on a note, not on a section")))

(defun my/append-review--move (top section)
  "Refile the note at point to a section of the append-and-review file.
TOP non-nil puts it first, else last.  SECTION is a headline, or nil to ask for
one of the top-level sections of the current file."
  (require 'org)
  (require 'org-refile)
  (my/append-review--check-note)
  (let ((org-reverse-note-order top))
    (if (null section)
        (let ((org-refile-targets '((nil :level . 1))))
          (org-refile))
      (let* ((file (my/append-review--path))
             (pos (with-current-buffer (find-file-noselect file)
                    (org-find-exact-headline-in-buffer section))))
        (unless pos (user-error "No \"%s\" section in %s" section file))
        (org-refile nil nil (list section file nil pos))))))

(defun my/append-review-to-top ()
  "Move the subtree at point to the top of a top-level section of this file.
Pick its own section to move it back to the top."
  (interactive)
  (my/append-review--move t nil))

(defun my/append-review-to-bottom ()
  "Move the subtree at point to the bottom of a top-level section of this file."
  (interactive)
  (my/append-review--move nil nil))

(defun my/append-review-to-today ()
  "Refile the note at point to the top of Today in the append-and-review file."
  (interactive)
  (my/append-review--move t "Today"))

(defun my/append-review-to-inbox ()
  "Refile the note at point to the top of Inbox in the append-and-review file."
  (interactive)
  (my/append-review--move t "Inbox"))

;; The tag command has no autoload before Org loads.
(autoload 'org-set-tags-command "org" nil t)

(my/hel-leader-bind
 "C-c n n" #'my/append-review-capture
 "C-c n o" #'my/append-review-open
 "C-c n u" #'my/append-review-to-top
 "C-c n d" #'my/append-review-to-bottom
 "C-c n r t" #'my/append-review-to-today
 "C-c n r i" #'my/append-review-to-inbox
 "C-c n t" #'org-set-tags-command
 "C-c n s" #'my/append-review-show-tag)

(provide 'init-local-append-review)
;;; init-local-append-review.el ends here
