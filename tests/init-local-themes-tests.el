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
  (defun minibuffer-frame--setup ())
  (unwind-protect
      (progn
        (provide 'minibuffer-frame)
        (should (advice-member-p #'my/minibuffer-frame-sync-background
                                 'minibuffer-frame--init))
        (should (advice-member-p #'my/minibuffer-frame-fit-prompt
                                 'minibuffer-frame--setup)))
    (fmakunbound 'minibuffer-frame--init)
    (fmakunbound 'minibuffer-frame--setup)
    (setq features (delq 'minibuffer-frame features))))

(defun init-local-themes-tests--fit (prompt width &optional frame-live parent-height)
  "Return the height set for PROMPT in a child frame WIDTH characters wide, or nil.
PARENT-HEIGHT is the height of the parent frame; the default is a tall one."
  (let ((minibuffer-frame--frame 'child) height)
    (cl-letf (((symbol-function 'frame-live-p) (lambda (f) (and (eq f 'child) (or frame-live t))))
              ((symbol-function 'frame-width) (lambda (_) width))
              ((symbol-function 'frame-parent) (lambda (_) 'parent))
              ((symbol-function 'frame-height) (lambda (_) (or parent-height 100)))
              ((symbol-function 'minibuffer-prompt) (lambda () prompt))
              ((symbol-function 'set-frame-height) (lambda (_f h) (setq height h))))
      (my/minibuffer-frame-fit-prompt))
    height))

(ert-deftest init-local-themes-minibuffer-frame-fits-a-multi-line-prompt ()
  (should (= 7 (init-local-themes-tests--fit "Not found.\n\n  [d] one\n  [c] two\n  [s] three\n\nChoice: " 80))))

(ert-deftest init-local-themes-minibuffer-frame-counts-wrapped-lines ()
  ;; A 25-character line in a 10-wide frame takes 3 lines, and the last line takes 1.
  (should (= 4 (init-local-themes-tests--fit (concat (make-string 25 ?x) "\nChoice: ") 10))))

(ert-deftest init-local-themes-minibuffer-frame-fit-stops-at-half-the-parent ()
  ;; 12 lines of prompt, parent 20 lines high: the cap is 10.
  (let ((prompt (concat (mapconcat #'identity (make-list 11 "line") "\n") "\nChoice: ")))
    (should (= 10 (init-local-themes-tests--fit prompt 80 nil 20)))
    (should (= 12 (init-local-themes-tests--fit prompt 80 nil 30)))))

(ert-deftest init-local-themes-minibuffer-frame-leaves-a-one-line-prompt-alone ()
  (should-not (init-local-themes-tests--fit "Find file: " 80))
  (should-not (init-local-themes-tests--fit nil 80)))

(ert-deftest init-local-themes-minibuffer-frame-fit-skips-a-missing-frame ()
  (let ((minibuffer-frame--frame nil))
    (should-not (my/minibuffer-frame-fit-prompt))))

(ert-deftest init-local-themes-toggle-is-on-the-leader-and-not-on-f5 ()
  (should (equal '(("C-c T" . modus-themes-toggle)) init-local-themes-tests--keys)))

(provide 'init-local-themes-tests)
;;; init-local-themes-tests.el ends here
