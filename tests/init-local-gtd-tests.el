;;; init-local-gtd-tests.el --- org-gtd module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-gtd-tests.el -f ert-run-tests-batch-and-exit
;; org-gtd itself is not loaded: the tests stub what the module calls.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar org-agenda-files)
(defvar org-agenda-dim-blocked-tasks)
(defvar org-agenda-sticky)
(defvar org-agenda-mode-map)
(defvar org-capture-after-finalize-hook)
(defvar org-directory)
(defvar org-reverse-note-order)
(defvar org-gtd-archive-location)
(defvar org-gtd-clarify-mode-map)
(defvar org-gtd-directory)
(defvar org-gtd-organize-hooks)
(defvar org-gtd-projects "Projects")
(defvar org-gtd-refile-prompt-for-types)
(defvar org-gtd-refile-to-any-target)
(defvar org-gtd--organize-type)
(defvar my/async-installer-after-install-hook)

(defvar init-local-gtd-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-gtd-tests--keys)))

;; Load with deferral, and without package installs: the module asks for three
;; packages with `:ensure t'.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil)
      (use-package-ensure-function #'ignore))
  (load (expand-file-name "../user-lisp/init-local-gtd.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

;;;; Loading

(ert-deftest init-local-gtd-load-explains-a-missing-package ()
  (let ((my/gtd-unavailable-reason nil))
    (should-not (my/gtd-load))
    (should (equal "the org-gtd package is not installed" my/gtd-unavailable-reason))
    (let ((err (should-error (my/gtd--require) :type 'user-error)))
      (should (string-match-p "org-gtd is not available: the org-gtd package is not installed"
                              (error-message-string err))))))

(ert-deftest init-local-gtd-load-reports-a-broken-package-without-signaling ()
  (let* ((dir (make-temp-file "gtd-test" t))
         (saved-load-path load-path)
         (my/gtd-unavailable-reason nil))
    (unwind-protect
        (progn
          (write-region "(error \"broken package\")\n" nil (expand-file-name "org-gtd.el" dir))
          (setq load-path (cons dir load-path))
          (should-not (my/gtd-load))
          (should (equal "broken package" my/gtd-unavailable-reason)))
      (setq load-path saved-load-path)
      (delete-directory dir t))))

(ert-deftest init-local-gtd-load-is-done-when-the-feature-exists ()
  (let ((saved features))
    (unwind-protect
        (progn (setq features (cons 'org-gtd features))
               (should (my/gtd-load)))
      (setq features saved))))

;;;; Advice

(ert-deftest init-local-gtd-refile-restores-the-project-type ()
  (let ((org-gtd--organize-type nil) seen)
    (my/gtd--refile-project (lambda (&rest _) (setq seen org-gtd--organize-type))
                            org-gtd-projects 'target)
    (should (eq 'project-heading seen))))

(ert-deftest init-local-gtd-refile-leaves-other-types-alone ()
  (let ((org-gtd--organize-type nil) seen)
    (my/gtd--refile-project (lambda (&rest _) (setq seen (list org-gtd--organize-type)))
                            "Actions" 'target)
    (should (equal '(nil) seen))))

(ert-deftest init-local-gtd-refile-keeps-a-type-that-is-set ()
  (let ((org-gtd--organize-type 'single-action) seen)
    (my/gtd--refile-project (lambda (&rest _) (setq seen org-gtd--organize-type))
                            org-gtd-projects 'target)
    (should (eq 'single-action seen))))

(ert-deftest init-local-gtd-organize-files-the-newest-first ()
  (let ((org-reverse-note-order nil) seen)
    (my/gtd--organize-newest-first (lambda (func) (setq seen (list org-reverse-note-order func)))
                                   'a-function)
    (should (equal '(t a-function) seen))
    (should-not org-reverse-note-order)))

(ert-deftest init-local-gtd-project-names-lose-their-faces ()
  (cl-letf (((symbol-function 'org-get-heading)
             (lambda (&rest _) (propertize "Project X" 'face 'org-level-1))))
    (let ((name (my/gtd--plain-project-names (lambda () (org-get-heading nil nil nil nil)))))
      (should (equal "Project X" name))
      (should-not (get-text-property 0 'face name)))))

;;;; Commands

(ert-deftest init-local-gtd-commands-explain-a-missing-package ()
  (let ((my/gtd-unavailable-reason "no package"))
    (cl-letf (((symbol-function 'my/gtd-load) (lambda () nil)))
      (dolist (command '(my/gtd-command-center my/gtd-clarify-item my/gtd-engage
                         my/gtd-show-all-projects))
        (let ((err (should-error (call-interactively command) :type 'user-error)))
          (should (string-match-p "no package" (error-message-string err))))))))

(ert-deftest init-local-gtd-engage-kills-the-stale-agenda-and-is-not-sticky ()
  (let ((org-agenda-sticky t) seen)
    (get-buffer-create "*Org Agenda(g)*")
    (unwind-protect
        (cl-letf (((symbol-function 'my/gtd-load) (lambda () t))
                  ((symbol-function 'org-gtd-engage) (lambda () (setq seen org-agenda-sticky))))
          (my/gtd-engage)
          (should-not (get-buffer "*Org Agenda(g)*"))
          (should-not seen)
          (should org-agenda-sticky))
      (when (get-buffer "*Org Agenda(g)*") (kill-buffer "*Org Agenda(g)*")))))

(ert-deftest init-local-gtd-shows-all-projects-with-one-view-spec ()
  (let (spec)
    (cl-letf (((symbol-function 'my/gtd-load) (lambda () t))
              ((symbol-function 'org-gtd-view-show) (lambda (s) (setq spec s))))
      (my/gtd-show-all-projects))
    (should (equal '((name . "All Projects") (type . project)) spec))))

(ert-deftest init-local-gtd-refresh-rebuilds-the-agenda-files ()
  (let ((org-agenda-files '("old.org")))
    (cl-letf (((symbol-function 'my/org-agenda-files) (lambda () '("new.org"))))
      (my/gtd-refresh-agenda-files 'ignored 'arguments))
    (should (equal '("new.org") org-agenda-files))))

;;;; Setup

(ert-deftest init-local-gtd-settings-apply-and-can-be-undone ()
  (let ((org-directory "/tmp/org/")
        (org-gtd-directory nil)
        (org-gtd-refile-to-any-target t)
        (org-gtd-refile-prompt-for-types nil)
        (org-gtd-archive-location 'something)
        (org-gtd-organize-hooks '(org-set-tags-command))
        (org-agenda-dim-blocked-tasks t)
        (org-capture-after-finalize-hook nil))
    (unwind-protect
        (progn
          (my/gtd--settings)
          (should (equal "/tmp/org/gtd/" org-gtd-directory))
          (should-not org-gtd-refile-to-any-target)
          (should (equal '(single-action project-heading project-task)
                         org-gtd-refile-prompt-for-types))
          (should-not org-gtd-archive-location)
          (should-not org-gtd-organize-hooks)
          (should-not org-agenda-dim-blocked-tasks)
          (should (memq #'my/gtd-refresh-agenda-files org-capture-after-finalize-hook))
          (should (advice-member-p #'my/gtd--refile-project 'org-gtd-refile--do))
          (should (advice-member-p #'my/gtd--organize-newest-first 'org-gtd-organize--call))
          (should (advice-member-p #'my/gtd--plain-project-names
                                   'org-gtd-project--get-marker-at-point))
          (should (advice-member-p #'my/gtd-refresh-agenda-files 'org-gtd-save-buffers)))
      (advice-remove 'org-gtd-refile--do #'my/gtd--refile-project)
      (advice-remove 'org-gtd-organize--call #'my/gtd--organize-newest-first)
      (advice-remove 'org-gtd-project-extend--select-project #'my/gtd--plain-project-names)
      (advice-remove 'org-gtd-project--get-marker-at-point #'my/gtd--plain-project-names)
      (advice-remove 'org-gtd-save-buffers #'my/gtd-refresh-agenda-files))))

(ert-deftest init-local-gtd-binds-the-keys-of-the-org-gtd-maps ()
  (require 'org-agenda)
  (let ((org-gtd-clarify-mode-map (make-sparse-keymap))
        (org-agenda-mode-map (make-sparse-keymap)))
    (my/gtd--bind-keys)
    (should (eq 'org-gtd-organize (keymap-lookup org-gtd-clarify-mode-map "C-c c")))
    (should (eq 'org-gtd-organize (keymap-lookup org-gtd-clarify-mode-map "C-c C-c")))
    (should (eq 'org-gtd-agenda-transient (keymap-lookup org-agenda-mode-map "C-c c")))
    (should (eq 'org-gtd-agenda-transient (keymap-lookup org-agenda-mode-map "C-c .")))))

(ert-deftest init-local-gtd-on-load-applies-settings-keys-and-the-mode-in-order ()
  (let (steps)
    (cl-letf (((symbol-function 'my/gtd--settings) (lambda () (push 'settings steps)))
              ((symbol-function 'my/gtd--bind-keys) (lambda () (push 'keys steps)))
              ((symbol-function 'org-gtd-mode) (lambda (arg) (push (list 'mode arg) steps))))
      (my/gtd--on-load))
    (should (equal '(settings keys (mode 1)) (reverse steps)))))

(ert-deftest init-local-gtd-setup-loads-at-once-in-batch-and-waits-for-the-install ()
  (let ((noninteractive t) (loads 0)
        (my/async-installer-after-install-hook nil))
    (cl-letf (((symbol-function 'my/gtd-load) (lambda () (cl-incf loads) nil)))
      (my/gtd-setup)
      (should (= 1 loads))
      (should (memq #'my/gtd-load my/async-installer-after-install-hook)))))

(ert-deftest init-local-gtd-setup-waits-for-idle-time-in-a-session ()
  (let ((noninteractive nil) timers
        (my/async-installer-after-install-hook nil))
    (cl-letf (((symbol-function 'my/gtd-load) (lambda () nil))
              ((symbol-function 'run-with-idle-timer)
               (lambda (secs repeat fn &rest _) (push (list secs repeat fn) timers))))
      (my/gtd-setup))
    (should (equal '((1 nil my/gtd-load)) timers))))

;;;; Keys

(ert-deftest init-local-gtd-keys-run-defined-commands ()
  (should init-local-gtd-tests--keys)
  (dolist (binding init-local-gtd-tests--keys)
    (should (fboundp (cdr binding)))))

(provide 'init-local-gtd-tests)
;;; init-local-gtd-tests.el ends here
