;;; init-local-gtd.el --- org-gtd capture/clarify/organize/engage  -*- lexical-binding: t; -*-
;;; Commentary:
;; org-gtd owns the process.  The topic files under `org-directory' stay the
;; store: clarified single actions and projects are refiled out into them, and
;; org-gtd's views still find them, because org-gtd v4 selects on the ORG_GTD
;; property across `org-agenda-files' and never binds a path (#16).
;;
;; This module owns only `org-gtd-*' settings and its own mode-map keys, so it
;; can be deleted in one step.  Global keys live with every other global key, in
;; `init-local-hel.el'.  When org-gtd is absent the module keeps the inbox path
;; correct, reports why, and leaves the optional settings unchanged.
;;; Code:

(require 'org)

(defvar org-gtd--organize-type)

;; org-gtd is registered in lisp/package-list.el, but async-installer only
;; extends `load-path' during install postprocess.  A clone that already
;; exists is skipped, so the next startup cannot find the library.  Hel,
;; Anvil and proofread do the same local add.
(let ((org-gtd-dir (expand-file-name "external-packages/org-gtd.el"
                                    user-emacs-directory)))
  (when (file-directory-p org-gtd-dir)
    (add-to-list 'load-path org-gtd-dir)))

;; Must be set before `(require 'org-gtd)': org-gtd.el warns when the value
;; is older than 4.0.0, and its defvar default is "1.0.0".
(setq org-gtd-update-ack "4.6.1")

(defconst init-local-gtd--elpa-dependencies
  '((org-edna "1.1.2")
    (f "0.20.0")
    (compat "30.0.0.0")
    (transient "0.11.0")
    (dag-draw "1.0.4"))
  "ELPA packages org-gtd 4.6.1 hard-requires, with minimum versions.")

(defvar init-local-gtd-unavailable-reason nil
  "Why org-gtd support is off, or nil when it is on.")

(defun init-local-gtd--mark-unavailable (reason)
  "Record REASON and leave the optional settings untouched."
  (setq init-local-gtd-unavailable-reason reason)
  (message "init-local-gtd: org-gtd support disabled -- %s" reason))

(defun init-local-gtd--command (command)
  "Run COMMAND, or explain why org-gtd support is off."
  (unless (fboundp command)
    (user-error "org-gtd is not available: %s"
                (or init-local-gtd-unavailable-reason "unknown reason")))
  (call-interactively command))

(defun init-local-gtd-command-center ()
  "Open `org-gtd-command-center', or report why org-gtd is off."
  (interactive)
  (init-local-gtd--command 'org-gtd-command-center))

(defun init-local-gtd-clarify-item ()
  "Clarify the Task at point, or report why org-gtd is off."
  (interactive)
  (init-local-gtd--command 'org-gtd-clarify-item))

(defun init-local-gtd-refresh-agenda-files (&rest _)
  "Rebuild `org-agenda-files' so new GTD files reach the views.
`org-agenda-files' is computed once at load, so the inbox org-gtd creates
on the first capture is invisible to every view until a restart."
  (interactive)
  (when (fboundp 'init-local-org-agenda-files)
    (setq org-agenda-files (init-local-org-agenda-files))))

(defun init-local-gtd--refile-project (orig-fun type refile-target)
  "Prompt for a project destination when ORIG-FUN loses its local type.
org-gtd's project creation temporarily visits the project tasks and leaves
`org-gtd--organize-type' nil before calling `org-gtd-refile--do'.  The
refiler checks that variable instead of TYPE, so restore the project heading
type for this one call."
  (if (and (equal type org-gtd-projects)
           (boundp 'org-gtd--organize-type)
           (null org-gtd--organize-type))
      (let ((org-gtd--organize-type 'project-heading))
        (funcall orig-fun type refile-target))
    (funcall orig-fun type refile-target)))

(defun init-local-gtd-engage ()
  "Open `org-gtd-engage' in its own buffer.
`org-agenda-sticky' is still on, so a leftover `*Org Agenda(g)*' would
otherwise swallow engage.  The `g' view is gone; keep that name dead."
  (interactive)
  (unless (fboundp 'org-gtd-engage)
    (user-error "org-gtd is not available: %s"
                (or init-local-gtd-unavailable-reason "unknown reason")))
  (when-let* ((stale (get-buffer "*Org Agenda(g)*")))
    (kill-buffer stale))
  (let ((org-agenda-sticky nil))
    (org-gtd-engage)))

(defun init-local-gtd--settings ()
  "Apply the org-gtd settings this module owns."
  ;; Obsolete since 4.0.0, but `org-gtd-refile--should-prompt-p' reads it
  ;; FIRST, and its default t disables every prompt.  Load-bearing.
  (setq org-gtd-refile-to-any-target nil
        ;; Prompt for topic-file destinations for actions and projects.
        org-gtd-refile-prompt-for-types
        '(single-action project-heading project-task)
        ;; nil restores plain `org-archive-location', which is what keeps
        ;; software.org_archive working (#16).
        org-gtd-archive-location nil
        ;; The default is (org-set-tags-command), which stops every clarify to
        ;; ask for tags; this store almost never tags a heading (#21).
        org-gtd-organize-hooks nil
        ;; org-edna makes `org-blocker-hook' non-nil, which wakes the agenda
        ;; blocked-task dim pass -- three property reads per entry over the
        ;; recursive ~/org scan, dead here until now (#17).
        org-agenda-dim-blocked-tasks nil)
  ;; After capture, and after organize has refiled (hooks run in the WIP
  ;; buffer *before* `org-gtd-refile--do', so they cannot see a new
  ;; org-gtd-tasks.org).  Both are documented Org / org-gtd seams.
  (add-hook 'org-capture-after-finalize-hook
            #'init-local-gtd-refresh-agenda-files)
  (when (fboundp 'org-gtd-refile--do)
    (advice-add 'org-gtd-refile--do :around
                #'init-local-gtd--refile-project))
  (advice-add 'org-gtd-save-buffers :after
              #'init-local-gtd-refresh-agenda-files))

(defun init-local-gtd--bind-keys ()
  "Bind the keys that belong to org-gtd's own maps.
The global keys live in `init-local-hel.el' with every other global key."
  ;; org-gtd binds C-c C-k (cancel) and C-c d (duplicate) in the clarify buffer,
  ;; but never binds `org-gtd-organize' -- the command that files the Task, and
  ;; the one pressed most.  Offer both C-c c and C-c C-c for it.
  (keymap-set org-gtd-clarify-mode-map "C-c c" #'org-gtd-organize)
  (keymap-set org-gtd-clarify-mode-map "C-c C-c" #'org-gtd-organize)
  ;; C-c c remains the agenda task menu.  C-c . is the org-gtd documented
  ;; alternative and is useful when C-c c has another local meaning.
  (with-eval-after-load 'org-agenda
    (keymap-set org-agenda-mode-map "C-c c" #'org-gtd-agenda-transient)
    (keymap-set org-agenda-mode-map "C-c ." #'org-gtd-agenda-transient)))

(defun init-local-gtd--install-elpa-dependencies ()
  "Install org-gtd 4.6.1's ELPA dependencies, or return a reason string."
  (cond
   ((not (fboundp 'maybe-require-package))
    "package.el helpers are not available")
   (t
    (catch 'missing
      (dolist (spec init-local-gtd--elpa-dependencies)
        (let ((package (car spec))
              (min-version (cadr spec)))
          (unless (maybe-require-package package min-version)
            (throw 'missing
                   (format "the %s package is not installed" package)))))
      nil))))

(defun init-local-gtd--initialize ()
  "Enable org-gtd support, or report why it is off."
  ;; Keep the inbox location correct even when package setup cannot finish.
  (setq org-gtd-directory (expand-file-name "gtd/" org-directory))
  (let ((missing (and (not (version< emacs-version "29.1"))
                      (init-local-gtd--install-elpa-dependencies))))
    (cond
     ((version< emacs-version "29.1")
      (init-local-gtd--mark-unavailable "Emacs 29.1 or newer is required"))
     (missing
      (init-local-gtd--mark-unavailable missing))
     ;; org-gtd arrives through async-installer, not package.el.  Do not
     ;; `maybe-require-package' it: that would pull MELPA and defeat the pin.
     ((not (condition-case nil
               (require 'org-gtd nil t)
             (error nil)))
      (init-local-gtd--mark-unavailable "the org-gtd package is not installed"))
     (t
      (setq init-local-gtd-unavailable-reason nil)
      (init-local-gtd--settings)
      (init-local-gtd--bind-keys)
      (org-gtd-mode 1)))))

(init-local-gtd--initialize)

(provide 'init-local-gtd)
;;; init-local-gtd.el ends here
