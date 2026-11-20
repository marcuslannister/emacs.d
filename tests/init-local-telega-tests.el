;;; init-local-telega-tests.el --- Telega module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-telega-tests.el -f ert-run-tests-batch-and-exit
;; Telega is not loaded: the tests stub what the module calls.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar nn-proxy-port 7897)
(defvar telega-before-auth-hook)
(defvar telega-chat-mode-hook)
(defvar corfu-auto)
(defvar hel-state)
(defvar telega-chat-button-map)
(defvar telega-msg-button-map)
(defvar telega-sticker-button-map)
(defvar telega-story-button-map)
(defvar telega-topic-button-map)

(defconst init-local-telega-tests--module
  (expand-file-name "../user-lisp/init-local-telega.el"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "The module under test.")

(defun init-local-telega-tests--load (system)
  "Load the module as if `system-type' were SYSTEM, with no install."
  (let ((system-type system)
        (use-package-always-defer t)
        (use-package-always-ensure nil)
        (use-package-ensure-function #'ignore))
    (load init-local-telega-tests--module nil t)))

(ert-deftest init-local-telega-sets-no-hook-off-macos ()
  (dolist (system '(windows-nt gnu/linux))
    (makunbound 'telega-before-auth-hook)
    (init-local-telega-tests--load system)
    (should-not (bound-and-true-p telega-before-auth-hook))))

(ert-deftest init-local-telega-sets-the-proxy-hook-on-macos ()
  (makunbound 'telega-before-auth-hook)
  (init-local-telega-tests--load 'darwin)
  (should (memq 'my/telega-proxy telega-before-auth-hook)))

(ert-deftest init-local-telega-chat-enables-corfu-for-manual-completion ()
  (let ((telega-chat-mode-hook nil)
        (corfu-auto t)
        args)
    (init-local-telega-tests--load 'darwin)
    (with-temp-buffer
      (cl-letf (((symbol-function 'telega-completions-setup-capf) #'ignore)
                ((symbol-function 'corfu-mode)
                 (lambda (arg) (setq args (list arg corfu-auto)))))
        (run-hooks 'telega-chat-mode-hook))
      (should (equal args '(1 nil)))
      (should (local-variable-p 'corfu-auto)))
    (should corfu-auto)))

(ert-deftest init-local-telega-proxy-is-socks5-on-the-base-port ()
  (init-local-telega-tests--load 'darwin)
  (let (args)
    (cl-letf (((symbol-function 'telega--addProxy) (lambda (&rest a) (setq args a))))
      (my/telega-proxy))
    (should (equal '(:server "localhost" :port 7897 :type (:@type "proxyTypeSocks5"))
                   (car args)))
    (should (eq 'enable (plist-get (cdr args) :enable-p)))))

(ert-deftest init-local-telega-font-falls-back-to-symbola-when-installed ()
  (require 'warnings)
  (init-local-telega-tests--load 'darwin)
  (let (set warned)
    (cl-letf (((symbol-function 'font-family-list) (lambda (&rest _) '("Symbola" "Menlo")))
              ((symbol-function 'set-fontset-font) (lambda (&rest a) (setq set a)))
              ((symbol-function 'display-warning) (lambda (&rest a) (setq warned a))))
      (my/telega-symbol-font-setup))
    (should (equal '(t unicode "Symbola" nil append) set))
    (should-not warned)))

(ert-deftest init-local-telega-font-warns-and-goes-on-without-symbola ()
  (require 'warnings)
  (init-local-telega-tests--load 'darwin)
  (let (set warned)
    (cl-letf (((symbol-function 'font-family-list) (lambda (&rest _) '("Menlo")))
              ((symbol-function 'set-fontset-font) (lambda (&rest a) (setq set a)))
              ((symbol-function 'display-warning) (lambda (&rest a) (setq warned a))))
      (my/telega-symbol-font-setup))
    (should-not set)
    (should (eq 'init-local-telega (car warned)))))

(ert-deftest init-local-telega-uses-hel-normal-state-for-navigation ()
  (init-local-telega-tests--load 'darwin)
  (let ((telega-chat-button-map (make-sparse-keymap))
        (telega-msg-button-map (make-sparse-keymap))
        (telega-sticker-button-map (make-sparse-keymap))
        (telega-story-button-map (make-sparse-keymap))
        (telega-topic-button-map (make-sparse-keymap))
        calls)
    (keymap-set telega-chat-button-map "h" #'telega-describe-chat)
    (keymap-set telega-msg-button-map "l" #'telega-msg-copy-link)
    (cl-letf (((symbol-function 'hel-set-initial-state)
               (lambda (mode state) (push (cons mode state) calls))))
      (my/telega-hel-setup))
    (should (equal '((telega-chat-mode . normal) (telega-root-mode . normal))
                   calls))
    (dolist (entry `((telega-root-mode ,telega-chat-button-map "h"
                       hel-backward-char telega-describe-chat)
                     (telega-chat-mode ,telega-msg-button-map "l"
                       hel-forward-char telega-msg-copy-link)))
      (pcase-let ((`(,mode ,button-map ,key ,motion ,action) entry))
        (with-temp-buffer
          (setq major-mode mode)
          (use-local-map (make-sparse-keymap))
          (keymap-set (current-local-map) key motion)
          (insert (propertize "x" 'keymap button-map))
          (goto-char (point-min))
          (let ((hel-state 'normal))
            (should (eq (key-binding key) motion)))
          (let ((hel-state 'emacs))
            (should (eq (key-binding key) action))))))))

(ert-deftest init-local-telega-hel-setup-skips-when-hel-is-missing ()
  (init-local-telega-tests--load 'darwin)
  (cl-letf (((symbol-function 'hel-set-initial-state) nil))
    (fmakunbound 'hel-set-initial-state)
    (should-not (my/telega-hel-setup))))

(provide 'init-local-telega-tests)
;;; init-local-telega-tests.el ends here
