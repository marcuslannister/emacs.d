;;; init-local-org.el --- Org settings of the Local layer -*- lexical-binding: t -*-
;;; Commentary:
;; The Base's Org block is removed (see the marker in init-lang.el); this module
;; holds the Org settings that this config keeps.  Loading it only registers
;; `use-package' forms: every setting applies when Org loads.
;;
;; Org files live in `org-directory', ~/org.  A machine without that folder (CI, a
;; new machine) gets an empty agenda and no error.  The state files of Org go in
;; var/, which Git ignores.
;;; Code:

(require 'seq)

(defvar org-directory)
(defvar org-agenda-files)
(declare-function my/hel-leader-bind "init-local-hel")

(defun my/org-agenda-files ()
  "Return the Org files under `org-directory'.
Leave out the Syncthing versions and the GTD inbox.  Return nil when the folder
does not exist."
  (seq-filter
   (lambda (file)
     (not (or (string-match-p "/\\.stversions/" (file-name-directory file))
              (string-suffix-p "/gtd/inbox.org" file))))
   (and (file-directory-p org-directory)
        (directory-files-recursively org-directory "\\.org\\'"))))

(use-package org
  :ensure nil
  :custom
  (org-directory (expand-file-name "~/org/"))
  (org-default-notes-file (expand-file-name "gtd/inbox.org" org-directory))
  (org-agenda-files (my/org-agenda-files))
  (org-persist-directory (locate-user-emacs-file "var/org/persist/"))
  (org-id-locations-file (locate-user-emacs-file "var/org/id-locations.el"))
  ;; The default `org-modules' loads ol-gnus, ol-eww and ol-docview with the first
  ;; Org buffer.  That cost about 1 s, and gnus alone 0.8 s.  Only `ol-info' stays.
  (org-modules '(ol-info))
  ;; Capture and refile set a bookmark at the last note, and Emacs shows a fringe
  ;; mark at each bookmark.  The goto-last commands use a marker first.
  (org-bookmark-names-plist nil)
  (org-use-fast-todo-selection t)
  ;; org-gtd sets NEXT, WAIT, and CNCL.  Without them here, a clarified Project fails
  ;; with "State `NEXT' not valid in this file", because no ~/org file has a #+TODO line.
  (org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)" "|" "DONE(d)" "CNCL(c)")))
  (org-startup-folded 'content)
  (org-startup-indented t)
  (org-startup-truncated nil)
  (org-adapt-indentation nil)
  (org-edit-src-content-indentation 0)
  (org-hide-emphasis-markers t)
  (org-hide-leading-stars t)
  (org-fontify-done-headline t)
  (org-fontify-todo-headline t)
  (org-fontify-whole-heading-line t)
  (org-fontify-quote-and-verse-blocks t)
  (org-pretty-entities t)
  ;; Require braces for scripts, so a plain identifier such as Test_1 does not show
  ;; as a subscript in a heading.
  (org-use-sub-superscripts '{}))

(use-package org-agenda
  :ensure nil
  :custom
  (org-agenda-block-separator (make-string 100 ?─))
  (org-agenda-clockreport-parameter-plist
   '(:maxlevel 5 :fileskip0 t :compact t :narrow 80 :formula %))
  :config
  ;; One extra agenda view: tasks by priority, then the agenda.
  (let ((cmd '("p" "List priority and schedule tasks"
               ((tags-todo "+PRIORITY=\"A\""
                           ((org-agenda-skip-function
                             '(org-agenda-skip-entry-if 'nottodo '("TODO" "NEXT" "WAIT")))
                            (org-agenda-overriding-header "High-priority unfinished tasks:")))
                (tags-todo "+PRIORITY=\"B\""
                           ((org-agenda-skip-function
                             '(let ((skip (org-agenda-skip-entry-if
                                           'nottodo '("TODO" "NEXT" "WAIT"))))
                                (or skip
                                    (unless (string-match-p
                                             "\\[#B\\]" (org-get-heading nil nil nil nil))
                                      (or (outline-next-heading) (point-max))))))
                            (org-agenda-overriding-header "Medium-priority unfinished tasks:")))
                (tags-todo "+PRIORITY=\"C\""
                           ((org-agenda-skip-function
                             '(org-agenda-skip-entry-if 'nottodo '("TODO" "NEXT" "WAIT")))
                            (org-agenda-overriding-header "Low-priority unfinished tasks:")))
                (agenda ""))
               ((org-agenda-compact-blocks nil)))))
    (unless (assoc "p" org-agenda-custom-commands)
      (add-to-list 'org-agenda-custom-commands cmd t))))

(use-package org-modern
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda))
  :custom
  (org-modern-star '("◉" "○" "◈" "◇" "*"))
  ;; Plain TODO words, priorities, timestamps, and statistics cookies.  The 12-wide
  ;; progress bar reads as an empty gray banner next to a short heading.
  (org-modern-todo nil)
  (org-modern-priority nil)
  (org-modern-timestamp nil)
  (org-modern-progress nil)
  (org-modern-tag t))

;; Most Org commands have no autoload before Org loads, and every leader key must
;; run a defined command.  Each entry is a library and its commands.
(dolist (entry '(("org" org-todo org-deadline org-schedule org-priority org-open-at-point
                  org-insert-heading org-insert-subheading)
                 ("org-refile" org-refile)
                 ("org-goto" org-goto)
                 ("org-id" org-id-get-create)
                 ("ol" org-insert-link)))
  (dolist (command (cdr entry))
    (autoload command (car entry) nil t)))

(my/hel-leader-bind
 "C-c o a" #'org-agenda
 "C-c o l" #'org-todo-list
 "C-c o m" #'org-tags-view
 "C-c o v" #'org-search-view
 "C-c o t" #'org-todo
 "C-c o d" #'org-deadline
 "C-c o s" #'org-schedule
 "C-c o r" #'org-refile
 "C-c o p" #'org-priority
 "C-c o G" #'org-goto
 "C-c o o" #'org-open-at-point
 "C-c o i c" #'org-id-get-create
 "C-c o i l" #'org-insert-link
 "C-c o i h" #'org-insert-heading
 "C-c o i s" #'org-insert-subheading)

(provide 'init-local-org)
;;; init-local-org.el ends here
