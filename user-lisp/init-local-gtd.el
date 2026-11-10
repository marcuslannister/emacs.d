;;; init-local-gtd.el --- org-gtd capture, clarify, organize, engage -*- lexical-binding: t -*-
;;; Commentary:
;; org-gtd owns the process.  The topic files under `org-directory' stay the store:
;; clarified single actions and projects are refiled out into them, and the views of
;; org-gtd still find them, because org-gtd v4 selects on the ORG_GTD property
;; across `org-agenda-files' and never binds a path.
;;
;; org-gtd comes from a Git pin (see init-local-package-list.el), not from
;; package.el.  It costs about 2 s to load, so this module loads it when Emacs is
;; idle (at once in batch Emacs, so the tests see it), or after the pin installs.
;; Until then its leader keys autoload it.  When it is missing the module explains
;; why in a `user-error' and changes nothing else.
;;
;; The module owns the `org-gtd-*' settings and the keys of org-gtd's own maps.  The
;; leader keys are at the end of this file.
;;; Code:

(require 'cl-lib)

(defvar org-agenda-files)
(defvar org-agenda-dim-blocked-tasks)
(defvar org-agenda-mode-map)
(defvar org-agenda-sticky)
(defvar org-capture-after-finalize-hook)
(defvar org-directory)
(defvar org-reverse-note-order)
(defvar org-gtd-archive-location)
(defvar org-gtd-clarify-mode-map)
(defvar org-gtd-directory)
(defvar org-gtd-organize-hooks)
(defvar org-gtd-projects)
(defvar org-gtd-refile-prompt-for-types)
(defvar org-gtd-refile-to-any-target)
(defvar org-gtd--organize-type)
(defvar my/async-installer-after-install-hook)
(declare-function org-gtd-engage "org-gtd-engage")
(declare-function org-gtd-mode "org-gtd-mode")
(declare-function org-gtd-view-show "org-gtd-view-language")
(declare-function my/org-agenda-files "init-local-org")
(declare-function my/hel-leader-bind "init-local-hel")

;; Must be set before org-gtd loads: it warns when the value is older than 4.0.0,
;; and its default is "1.0.0".
(defvar org-gtd-update-ack "4.6.1")

;; The libraries that org-gtd 4.6.1 needs, besides Org, the built-in transient
;; (0.13 here, it needs 0.11), and the built-in compat.
(use-package org-edna :ensure t)
(use-package f :ensure t)
(use-package dag-draw :ensure t)

(defvar my/gtd-unavailable-reason nil
  "Why org-gtd is off, or nil when it is on.")

(defun my/gtd-load ()
  "Load org-gtd if it is not loaded.  Return non-nil when it is loaded.
Set `my/gtd-unavailable-reason' when it cannot load.  Never signals."
  (cond
   ((featurep 'org-gtd) t)
   ((condition-case err
        (require 'org-gtd nil t)
      (error (setq my/gtd-unavailable-reason (error-message-string err)) nil))
    (setq my/gtd-unavailable-reason nil)
    t)
   (t
    (unless my/gtd-unavailable-reason
      (setq my/gtd-unavailable-reason "the org-gtd package is not installed"))
    nil)))

(defun my/gtd--require ()
  "Load org-gtd, or signal a `user-error' that gives the reason."
  (unless (my/gtd-load)
    (user-error "org-gtd is not available: %s" my/gtd-unavailable-reason)))

;;;; Commands

(defun my/gtd-command-center ()
  "Open `org-gtd-command-center', or report why org-gtd is off."
  (interactive)
  (my/gtd--require)
  (call-interactively #'org-gtd-command-center))

(defun my/gtd-clarify-item ()
  "Clarify the Task at point, or report why org-gtd is off."
  (interactive)
  (my/gtd--require)
  (call-interactively #'org-gtd-clarify-item))

(defun my/gtd-engage ()
  "Open `org-gtd-engage' in its own buffer.
`org-agenda-sticky' is on, so a leftover `*Org Agenda(g)*' would swallow engage.
The `g' view is gone; keep that name dead."
  (interactive)
  (my/gtd--require)
  (when-let* ((stale (get-buffer "*Org Agenda(g)*")))
    (kill-buffer stale))
  (let ((org-agenda-sticky nil))
    (org-gtd-engage)))

(defun my/gtd-show-all-projects ()
  "Show every Project in an agenda view.
The command center of org-gtd reaches stuck, completed, and missed Projects only;
nothing there lists the whole set.  `project' is a plain type in the view language
of org-gtd, so one spec covers it."
  (interactive)
  (my/gtd--require)
  (org-gtd-view-show '((name . "All Projects")
                       (type . project))))

(defun my/gtd-refresh-agenda-files (&rest _)
  "Rebuild `org-agenda-files', so new GTD files reach the views.
`org-agenda-files' is computed once at load, so the inbox that org-gtd creates on
the first capture is invisible to every view until a restart."
  (interactive)
  (setq org-agenda-files (my/org-agenda-files)))

;;;; Advice

(defun my/gtd--refile-project (orig-fun type refile-target)
  "Prompt for a project destination when ORIG-FUN loses its local type.
The project creation of org-gtd visits the project tasks for a moment and leaves
`org-gtd--organize-type' nil before it calls the refiler.  The refiler checks that
variable and not TYPE, so restore the project heading type for this one call."
  (if (and (equal type org-gtd-projects)
           (boundp 'org-gtd--organize-type)
           (null org-gtd--organize-type))
      (let ((org-gtd--organize-type 'project-heading))
        (funcall orig-fun type refile-target))
    (funcall orig-fun type refile-target)))

(defun my/gtd--organize-newest-first (orig-fun func)
  "Run ORIG-FUN on FUNC, filing the item as the FIRST child of its target.
`org-reverse-note-order' is the knob that `org-refile' reads.  org-gtd refiles from
two call sites, and this is the one point both pass through."
  (let ((org-reverse-note-order t))
    (funcall orig-fun func)))

(defun my/gtd--plain-project-names (orig-fun &rest args)
  "Run ORIG-FUN with ARGS, with plain-text project names.
org-gtd collects project names with `org-get-heading', which keeps the heading
faces.  The prompt then shows each Project in its heading size, overline, and
background."
  (let ((get-heading (symbol-function 'org-get-heading)))
    (cl-letf (((symbol-function 'org-get-heading)
               (lambda (&rest heading-args)
                 (substring-no-properties (apply get-heading heading-args)))))
      (apply orig-fun args))))

;;;; Setup when org-gtd loads

(defun my/gtd--settings ()
  "Apply the org-gtd settings of this module."
  ;; The GTD files, and the inbox, live in the gtd folder of `org-directory'.
  (setq org-gtd-directory (expand-file-name "gtd/" org-directory))
  ;; Obsolete since 4.0.0, but `org-gtd-refile--should-prompt-p' reads it FIRST, and
  ;; its default t disables every prompt.  Load-bearing.
  (setq org-gtd-refile-to-any-target nil
        ;; Prompt for topic-file destinations for actions and projects.
        org-gtd-refile-prompt-for-types '(single-action project-heading project-task)
        ;; nil restores the plain `org-archive-location', which keeps
        ;; software.org_archive working.
        org-gtd-archive-location nil
        ;; The default is (org-set-tags-command), which stops every clarify to ask
        ;; for tags; this store almost never tags a heading.
        org-gtd-organize-hooks nil
        ;; org-edna makes `org-blocker-hook' non-nil, which wakes the agenda
        ;; blocked-task dim pass: three property reads per entry over the recursive
        ;; ~/org scan.  Off.
        org-agenda-dim-blocked-tasks nil)
  ;; After capture, and after organize has refiled.  The hooks of organize run in the
  ;; work buffer BEFORE `org-gtd-refile--do', so they cannot see a new
  ;; org-gtd-tasks.org; the advice on `org-gtd-save-buffers' covers that.
  (add-hook 'org-capture-after-finalize-hook #'my/gtd-refresh-agenda-files)
  (advice-add 'org-gtd-refile--do :around #'my/gtd--refile-project)
  (advice-add 'org-gtd-organize--call :around #'my/gtd--organize-newest-first)
  (dolist (fn '(org-gtd-project-extend--select-project
                org-gtd-project--get-marker-at-point))
    (advice-add fn :around #'my/gtd--plain-project-names))
  (advice-add 'org-gtd-save-buffers :after #'my/gtd-refresh-agenda-files))

(defun my/gtd--bind-keys ()
  "Bind the keys that belong to the own maps of org-gtd."
  ;; org-gtd binds C-c C-k (cancel) and C-c d (duplicate) in the clarify buffer, but
  ;; never `org-gtd-organize': the command that files the Task, and the one pressed
  ;; most.  Offer both C-c c and C-c C-c for it.
  (keymap-set org-gtd-clarify-mode-map "C-c c" #'org-gtd-organize)
  (keymap-set org-gtd-clarify-mode-map "C-c C-c" #'org-gtd-organize)
  ;; C-c c stays the agenda task menu.  C-c . is the alternative that org-gtd
  ;; documents, for a buffer where C-c c has another local meaning.
  (with-eval-after-load 'org-agenda
    (keymap-set org-agenda-mode-map "C-c c" #'org-gtd-agenda-transient)
    (keymap-set org-agenda-mode-map "C-c ." #'org-gtd-agenda-transient)))

(defun my/gtd--on-load ()
  "Set org-gtd up.  Run once, when the library has loaded."
  (my/gtd--settings)
  (my/gtd--bind-keys)
  (org-gtd-mode 1))

(with-eval-after-load 'org-gtd
  (my/gtd--on-load))

;;;; Start

(defun my/gtd-setup ()
  "Load org-gtd when Emacs is idle, or after the pin installs when it is missing.
Never signals."
  (if noninteractive
      (my/gtd-load)
    (run-with-idle-timer 1 nil #'my/gtd-load))
  (unless (featurep 'org-gtd)
    (add-hook 'my/async-installer-after-install-hook #'my/gtd-load)))

;;;; Keys

;; Until org-gtd loads, these autoload it.  Each one is defined by org-gtd.
(dolist (command '(org-gtd-capture org-gtd-process-inbox org-gtd-show-all-next
                   org-gtd-reflect-stuck-projects org-gtd-organize
                   org-gtd-agenda-transient))
  (autoload command "org-gtd" nil t))

(my/hel-leader-bind
 "C-c c" #'my/gtd-command-center
 "C-c o c" #'org-gtd-capture
 "C-c o e" #'my/gtd-engage
 "C-c o k" #'my/gtd-clarify-item
 ;; Org GTD.  The group is discoverable under o g; the single key `org-goto' lives
 ;; at o G.
 "C-c o g c" #'org-gtd-capture
 "C-c o g e" #'my/gtd-engage
 "C-c o g i" #'org-gtd-process-inbox
 "C-c o g k" #'my/gtd-clarify-item
 "C-c o g m" #'my/gtd-command-center
 "C-c o g n" #'org-gtd-show-all-next
 "C-c o g p" #'my/gtd-show-all-projects
 "C-c o g s" #'org-gtd-reflect-stuck-projects
 "C-c o g o" #'org-gtd-organize
 "C-c o g a" #'org-gtd-agenda-transient)

(provide 'init-local-gtd)
;;; init-local-gtd.el ends here
