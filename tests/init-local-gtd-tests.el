;;; init-local-gtd-tests.el --- Tests for local org-gtd support -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)

(defvar org-gtd-clarify-mode-map)
(defvar org-gtd-directory)
(defvar org-gtd-update-ack)
(defvar org-gtd-refile-to-any-target)
(defvar org-gtd-refile-prompt-for-types)
(defvar org-gtd-archive-location)
(defvar org-gtd-organize-hooks)
(defvar org-agenda-dim-blocked-tasks)
(defvar org-capture-after-finalize-hook nil)

(load-file (expand-file-name "../lisp/init-local-gtd.el"
                             (file-name-directory load-file-name)))

(defconst init-local-gtd-test--gtd-vars
  '(org-gtd-directory
    org-gtd-refile-to-any-target
    org-gtd-refile-prompt-for-types
    org-gtd-archive-location
    org-gtd-organize-hooks))

(defconst init-local-gtd-test--preloaded-ack "4.6.1")

(defun init-local-gtd-test--clear-gtd-vars ()
  "Forget every `org-gtd-*' setting this module might have written."
  (dolist (var init-local-gtd-test--gtd-vars)
    (makunbound var))
  (setq org-gtd-update-ack "4.6.1")
  (setq init-local-gtd-unavailable-reason nil)
  (setq org-capture-after-finalize-hook
        (remq #'init-local-gtd-refresh-agenda-files
              org-capture-after-finalize-hook))
  (advice-remove 'org-gtd-save-buffers
                 #'init-local-gtd-refresh-agenda-files))

(defun init-local-gtd-test--should-set-directory-only ()
  "Check that only the GTD directory is set when support is unavailable."
  (should (equal (expand-file-name "gtd/" org-directory)
                 org-gtd-directory))
  (dolist (var (cdr init-local-gtd-test--gtd-vars))
    (should-not (boundp var))))

(defmacro init-local-gtd-test-without-package (&rest body)
  "Run BODY with `(require 'org-gtd)' failing."
  (declare (indent 0) (debug t))
  `(let ((orig-require (symbol-function 'require)))
     (cl-letf (((symbol-function 'require)
                (lambda (feature &optional filename noerror)
                  (if (eq feature 'org-gtd)
                      nil
                    (funcall orig-require feature filename noerror)))))
       ,@body)))

(ert-deftest init-local-gtd-absent-package-sets-directory-only ()
  (let ((org-agenda-dim-blocked-tasks t)
        (org-capture-after-finalize-hook nil))
    (init-local-gtd-test--clear-gtd-vars)
    (setq org-gtd-directory "~/gtd/")
    (cl-letf (((symbol-function 'maybe-require-package)
               (lambda (&rest _args) t)))
      (init-local-gtd-test-without-package
        (init-local-gtd--initialize)))
    (should (string-match-p "org-gtd"
                            init-local-gtd-unavailable-reason))
    (init-local-gtd-test--should-set-directory-only)
    (should (eq t org-agenda-dim-blocked-tasks))
    (should-not (memq #'init-local-gtd-refresh-agenda-files
                      org-capture-after-finalize-hook))))

(ert-deftest init-local-gtd-old-emacs-sets-directory-only ()
  (let ((emacs-version "28.2")
        (org-agenda-dim-blocked-tasks t))
    (init-local-gtd-test--clear-gtd-vars)
    (init-local-gtd--initialize)
    (should (string-match-p "29\\.1"
                            init-local-gtd-unavailable-reason))
    (init-local-gtd-test--should-set-directory-only)
    (should (eq t org-agenda-dim-blocked-tasks))))

(ert-deftest init-local-gtd-missing-elpa-dependency-sets-directory-only ()
  (let ((org-agenda-dim-blocked-tasks t))
    (init-local-gtd-test--clear-gtd-vars)
    (cl-letf (((symbol-function 'maybe-require-package)
               (lambda (package &rest _args)
                 (not (eq package 'f)))))
      (init-local-gtd--initialize))
    (should (string-match-p "\\bf\\b"
                            init-local-gtd-unavailable-reason))
    (init-local-gtd-test--should-set-directory-only)
    (should (eq t org-agenda-dim-blocked-tasks))))

(ert-deftest init-local-gtd-applies-settings-when-present ()
  (skip-unless (not (version< emacs-version "29.1")))
  (let ((org-directory (file-name-as-directory
                        (make-temp-file "gtd-org" t)))
        (org-agenda-dim-blocked-tasks t)
        (org-gtd-clarify-mode-map (make-sparse-keymap))
        (org-capture-after-finalize-hook nil)
        (mode-arg nil))
    (unwind-protect
        (progn
          (unless (fboundp 'org-gtd-mode)
            (defun org-gtd-mode (&optional arg)
              "Test stub for `org-gtd-mode'."
              (setq mode-arg arg)))
          (unless (fboundp 'org-gtd-organize)
            (defun org-gtd-organize ()))
          (unless (fboundp 'org-gtd-agenda-transient)
            (defun org-gtd-agenda-transient ()))
          (provide 'org-gtd)
          (init-local-gtd-test--clear-gtd-vars)
          (cl-letf (((symbol-function 'maybe-require-package)
                     (lambda (&rest _args) t))
                    ((symbol-function 'org-gtd-mode)
                     (lambda (&optional arg)
                       (setq mode-arg arg))))
            (init-local-gtd--initialize))
          (should (null init-local-gtd-unavailable-reason))
          (should (equal (expand-file-name "gtd/" org-directory)
                         org-gtd-directory))
          (should (equal init-local-gtd-test--preloaded-ack
                         org-gtd-update-ack))
          (should (null org-gtd-refile-to-any-target))
          (should (equal '(single-action project-heading project-task)
                         org-gtd-refile-prompt-for-types))
          (should (cl-every #'symbolp org-gtd-refile-prompt-for-types))
          (should (null org-gtd-archive-location))
          (should (null org-gtd-organize-hooks))
          (should (null org-agenda-dim-blocked-tasks))
          (should (memq #'init-local-gtd-refresh-agenda-files
                        org-capture-after-finalize-hook))
          (should (advice-member-p #'init-local-gtd-refresh-agenda-files
                                   'org-gtd-save-buffers))
          (should (eq #'org-gtd-organize
                      (lookup-key org-gtd-clarify-mode-map (kbd "C-c C-c"))))
          (should (eq 1 mode-arg)))
      (delete-directory org-directory t))))

(ert-deftest init-local-gtd-refresh-rebuilds-agenda-files ()
  (let ((org-agenda-files nil)
        (called nil))
    (cl-letf (((symbol-function 'init-local-org-agenda-files)
               (lambda ()
                 (setq called t)
                 '("a.org"))))
      (init-local-gtd-refresh-agenda-files)
      (should called)
      (should (equal '("a.org") org-agenda-files)))))

(ert-deftest init-local-gtd-refresh-is-noop-without-agenda-helper ()
  (should-not (fboundp 'init-local-org-agenda-files))
  (let ((org-agenda-files '("keep.org")))
    (init-local-gtd-refresh-agenda-files)
    (should (equal '("keep.org") org-agenda-files))))

(ert-deftest init-local-gtd-engage-kills-leftover-g-buffer ()
  (skip-unless (not (version< emacs-version "29.1")))
  (let ((stale (get-buffer-create "*Org Agenda(g)*")))
    (unwind-protect
        (progn
          (defun org-gtd-engage ())
          (init-local-gtd-engage)
          (should-not (buffer-live-p stale)))
      (when (buffer-live-p stale)
        (kill-buffer stale)))))

(ert-deftest init-local-gtd-wrappers-explain-when-unavailable ()
  (setq init-local-gtd-unavailable-reason "the org-gtd package is not installed")
  (fmakunbound 'org-gtd-command-center)
  (should-error (init-local-gtd-command-center) :type 'user-error)
  (fmakunbound 'org-gtd-clarify-item)
  (should-error (init-local-gtd-clarify-item) :type 'user-error))
