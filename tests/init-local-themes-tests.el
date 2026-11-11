;;; init-local-themes-tests.el --- Theme module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-themes-tests.el -f ert-run-tests-batch-and-exit
;; The theme is not loaded here: the tests stub the frame functions.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar minibuffer-frame--frame)

(defvar init-local-themes-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-themes-tests--keys)))

;; Load without package installs.  The module demands modus-themes, so give it a fake
;; feature, and stub `load-theme' so no theme loads.
(let ((use-package-always-ensure nil)
      (use-package-ensure-function #'ignore)
      (themes nil))
  (provide 'modus-themes)
  (unwind-protect
      (cl-letf (((symbol-function 'load-theme) (lambda (theme &rest _) (push theme themes))))
        (load (expand-file-name "../user-lisp/init-local-themes.el"
                                (file-name-directory (or load-file-name buffer-file-name)))
              nil t)
        (defconst init-local-themes-tests--loaded-themes themes))
    (setq features (delq 'modus-themes features))))

(ert-deftest init-local-themes-loads-modus-operandi-tinted ()
  (should (equal '(modus-operandi-tinted) init-local-themes-tests--loaded-themes)))

(defun init-local-themes-tests--sync (frame-live)
  "Run the sync with a fake child frame.  Return the parameters set, as an alist."
  (let ((minibuffer-frame--frame 'child) set)
    (cl-letf (((symbol-function 'frame-live-p) (lambda (f) (and frame-live (eq f 'child))))
              ((symbol-function 'frame-parent) (lambda (_) 'parent))
              ((symbol-function 'face-background)
               (lambda (face frame) (and (eq face 'default) (eq frame 'parent) "#fbf7f0")))
              ((symbol-function 'set-frame-parameter)
               (lambda (frame param value) (push (list frame param value) set))))
      (my/minibuffer-frame-sync-background))
    set))

(ert-deftest init-local-themes-minibuffer-frame-gets-the-editor-background ()
  (should (equal '((child background-color "#fbf7f0"))
                 (init-local-themes-tests--sync t))))

(ert-deftest init-local-themes-minibuffer-frame-sync-skips-a-missing-frame ()
  (should-not (init-local-themes-tests--sync nil))
  (let ((minibuffer-frame--frame nil))
    (should-not (my/minibuffer-frame-sync-background))))

(ert-deftest init-local-themes-minibuffer-frame-follows-theme-changes ()
  (should (memq #'my/minibuffer-frame-sync-background enable-theme-functions)))

(ert-deftest init-local-themes-minibuffer-frame-init-is-advised-when-the-package-loads ()
  (defun minibuffer-frame--init ())
  (unwind-protect
      (progn
        (provide 'minibuffer-frame)
        (should (advice-member-p #'my/minibuffer-frame-sync-background
                                 'minibuffer-frame--init)))
    (fmakunbound 'minibuffer-frame--init)
    (setq features (delq 'minibuffer-frame features))))

(ert-deftest init-local-themes-toggle-is-on-the-leader-and-not-on-f5 ()
  (should (equal '(("C-c T" . modus-themes-toggle)) init-local-themes-tests--keys)))

(provide 'init-local-themes-tests)
;;; init-local-themes-tests.el ends here
