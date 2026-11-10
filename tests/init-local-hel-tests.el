;;; init-local-hel-tests.el --- Hel module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-hel-tests.el -f ert-run-tests-batch-and-exit
;; These tests do not load Hel.  test-startup.sh checks the real keys after a
;; full startup.
;;; Code:

(require 'ert)
(require 'cl-lib)
;; `display-warning' starts as an autoload; load it before a test stubs it.
(require 'warnings)

;; A bare `defvar' is special only in its own file, so the tests declare the
;; variables that they bind with `let'.
(defvar hel-mode)
(defvar hel-state)
(defvar my/async-installer-after-install-hook nil)
(defvar nn-first-input-hook nil)

(load-file (expand-file-name "../user-lisp/init-local-hel.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

;;;; The leader table

(ert-deftest init-local-hel-leader-keys-are-valid-and-unique ()
  (let (seen)
    (dolist (binding my/hel-leader-bindings)
      (should (key-valid-p (car binding)))
      (should (string-prefix-p "C-c " (car binding)))
      (should-not (member (car binding) seen))
      (push (car binding) seen))))

(ert-deftest init-local-hel-leader-keys-do-not-shadow-each-other ()
  "A key bound to a command cannot also be the prefix of another leader key."
  (dolist (a my/hel-leader-bindings)
    (dolist (b my/hel-leader-bindings)
      (should-not (string-prefix-p (concat (car a) " ") (car b))))))

(ert-deftest init-local-hel-leader-commands-are-symbols-that-exist-or-autoload ()
  ;; test-startup.sh checks `fboundp' after startup; here, only the shape and
  ;; the commands that do not depend on a package.
  (dolist (binding my/hel-leader-bindings)
    (should (symbolp (cdr binding))))
  (dolist (command '(next-buffer rgrep project-find-file recentf-open duplicate-dwim
                     my/delete-window my/save-all-buffers))
    (should (fboundp command))))

(ert-deftest init-local-hel-leader-has-no-keys-for-removed-packages ()
  "The consult family, zoxide, pulsar, and translate are not ported."
  (dolist (binding my/hel-leader-bindings)
    (should-not (string-match-p "\\`\\(consult\\|zoxide\\|pulsar\\|gt-\\|ekp\\|blinko\\)"
                                (symbol-name (cdr binding))))))

(ert-deftest init-local-hel-leader-uses-the-fido-replacements ()
  (let ((table my/hel-leader-bindings))
    (should (eq 'recentf-open (alist-get "C-c r" table nil nil #'equal)))
    (should (eq 'my-rg-current-dir-all (alist-get "C-c s c g" table nil nil #'equal)))
    (should (eq 'project-find-file (alist-get "C-c s c f" table nil nil #'equal)))
    (should (eq 'imenu (alist-get "C-c s c h" table nil nil #'equal)))
    ;; consult-dir has no replacement.
    (should-not (assoc "C-c s c d" table))))

(ert-deftest init-local-hel-leader-window-keys-use-the-local-commands ()
  (should (eq 'my/delete-other-windows (alist-get "C-c w o" my/hel-leader-bindings nil nil #'equal)))
  (should (eq 'my/delete-window (alist-get "C-c w q" my/hel-leader-bindings nil nil #'equal))))

(ert-deftest init-local-hel-leader-bind-adds-replaces-and-binds-when-active ()
  (let ((my/hel-leader-bindings nil)
        calls)
    (cl-letf (((symbol-function 'hel-keymap-global-set)
               (lambda (&rest args) (push args calls))))
      (let ((hel-mode nil))
        (my/hel-leader-bind "C-c z a" #'ignore "C-c z b" #'identity)
        (should-not calls))
      (should (eq 'ignore (alist-get "C-c z a" my/hel-leader-bindings nil nil #'equal)))
      ;; A new definition replaces the old one.
      (let ((hel-mode nil))
        (my/hel-leader-bind "C-c z a" #'identity))
      (should (eq 'identity (alist-get "C-c z a" my/hel-leader-bindings nil nil #'equal)))
      (should (= 2 (length my/hel-leader-bindings)))
      ;; With Hel active, the keys are bound at once in the two states.
      (let ((hel-mode t))
        (my/hel-leader-bind "C-c z c" #'ignore))
      (should (equal '(:state (normal emacs) "C-c z c" ignore) (car calls))))))

;;;; The mode line

(ert-deftest init-local-hel-mode-line-state-names ()
  (let ((hel-state 'normal)) (should (equal "NORMAL" (my/hel-mode-line-state))))
  (let ((hel-state 'insert)) (should (equal "INSERT" (my/hel-mode-line-state))))
  (let ((hel-state 'emacs)) (should (equal "EMACS" (my/hel-mode-line-state))))
  (let ((hel-state 'motion)) (should (equal "MOTION" (my/hel-mode-line-state))))
  (let ((hel-state nil)) (should-not (my/hel-mode-line-state))))

(ert-deftest init-local-hel-mode-line-segment-goes-in-once-after-percent-e ()
  (with-temp-buffer
    (setq-local mode-line-format (list "%e" "  " "branch" "  " "%b"))
    (my/hel--add-mode-line-segment)
    (my/hel--add-mode-line-segment)
    (should (equal (list "%e" "  " my/hel--mode-line-segment "  " "branch" "  " "%b")
                   mode-line-format))))

(ert-deftest init-local-hel-mode-line-segment-leaves-other-formats-alone ()
  (with-temp-buffer
    ;; The global format is nil in the Base, and a buffer without the Base
    ;; mode line must not get a segment.
    (setq-local mode-line-format nil)
    (my/hel--add-mode-line-segment)
    (should-not mode-line-format)
    (setq-local mode-line-format '("x" "y"))
    (my/hel--add-mode-line-segment)
    (should (equal '("x" "y") mode-line-format))))

;;;; Activation and setup

(ert-deftest init-local-hel-activate-does-nothing-when-already-on ()
  (let ((hel-mode t))
    (cl-letf (((symbol-function 'require)
               (lambda (&rest _) (error "nothing may be loaded"))))
      (should (my/hel--activate)))))

(ert-deftest init-local-hel-activate-needs-both-packages ()
  (let ((hel-mode nil)
        configured)
    (let ((orig-require (symbol-function 'require)))
      (cl-letf (((symbol-function 'my/hel--configure) (lambda () (setq configured t)))
                ((symbol-function 'require)
                 (lambda (feature &rest args)
                   (if (eq feature 'hel-leader)
                       nil
                     (if (eq feature 'hel) t (apply orig-require feature args))))))
        (should-not (my/hel--activate))
        (should-not configured)))
    (let ((orig-require (symbol-function 'require)))
      (cl-letf (((symbol-function 'my/hel--configure) (lambda () (setq configured t)))
                ((symbol-function 'require)
                 (lambda (feature &rest args)
                   (if (memq feature '(hel hel-leader))
                       t
                     (apply orig-require feature args)))))
        (should (my/hel--activate))
        (should configured)))))

(ert-deftest init-local-hel-activation-after-install-warns-instead-of-signalling ()
  (let (warnings)
    (cl-letf (((symbol-function 'my/hel--activate) (lambda () (error "boom")))
              ((symbol-function 'display-warning)
               (lambda (type message &rest _) (push (cons type message) warnings))))
      (my/hel--activate-safely))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-hel (car (car warnings))))
    (should (string-match-p "Hel could not start: boom" (cdr (car warnings))))))

(ert-deftest init-local-hel-setup-survives-a-package-that-fails-to-load ()
  "hel.el may exist while one of its own requires fails: warn, leave Hel off."
  (let ((my/async-installer-after-install-hook nil)
        (hel-mode nil)
        result warnings)
    (setq warnings
          (let ((collected nil)
                (orig-require (symbol-function 'require)))
            (cl-letf (((symbol-function 'display-warning)
                       (lambda (type message &rest _) (push (cons type message) collected)))
                      ((symbol-function 'advice-add) #'ignore)
                      ((symbol-function 'my/hel--ensure-dependencies) #'ignore)
                      ((symbol-function 'require)
                       (lambda (feature &rest args)
                         (if (eq feature 'hel)
                             (error "Cannot open load file: pcre2el")
                           (apply orig-require feature args)))))
              (setq result (my/hel-setup)))
            (nreverse collected)))
    ;; The call returned, Hel is off, one warning names the cause, and the
    ;; install hook will try again.
    (should-not hel-mode)
    (should (= 1 (length warnings)))
    (should (string-match-p "Hel could not start: Cannot open load file: pcre2el"
                            (cdr (car warnings))))
    (should (memq 'my/hel--activate-safely my/async-installer-after-install-hook))
    (ignore result)))

(ert-deftest init-local-hel-setup-waits-for-the-install-when-hel-is-missing ()
  (let ((my/async-installer-after-install-hook nil))
    (cl-letf (((symbol-function 'advice-add) #'ignore)
              ((symbol-function 'my/hel--ensure-dependencies) #'ignore)
              ((symbol-function 'my/hel--activate) (lambda () nil)))
      (my/hel-setup))
    (should (memq 'my/hel--activate-safely my/async-installer-after-install-hook)))
  (let ((my/async-installer-after-install-hook nil))
    (cl-letf (((symbol-function 'advice-add) #'ignore)
              ((symbol-function 'my/hel--ensure-dependencies) #'ignore)
              ((symbol-function 'my/hel--activate) (lambda () t)))
      (my/hel-setup))
    (should-not my/async-installer-after-install-hook)))

(provide 'init-local-hel-tests)
;;; init-local-hel-tests.el ends here
