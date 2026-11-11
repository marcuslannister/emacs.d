;;; init-local-tabs-tests.el --- Tests for init-local-tabs -*- lexical-binding: t -*-
(require 'ert)
(require 'cl-lib)
(require 'use-package)
(setq use-package-ensure-function #'ignore use-package-always-defer t)
(defvar ghostel-keymap-exceptions '("C-c"))
(add-to-list 'load-path (expand-file-name "../user-lisp" (file-name-directory load-file-name)))
(require 'init-local-tabs)

(ert-deftest init-local-tabs-m-digits-select-the-numbered-tab ()
  (dolist (n (number-sequence 1 9))
    (let (selected)
      (cl-letf (((symbol-function 'tab-bar-select-tab) (lambda (k) (setq selected k))))
        (call-interactively (keymap-lookup global-map (format "M-%d" n))))
      (should (= n selected)))))

(ert-deftest init-local-tabs-setup-shows-hints-and-starts-the-mode ()
  (let ((tab-bar-tab-hints t) started)
    ;; The real mode sets the hints to nil, so the stub does the same.
    (cl-letf (((symbol-function 'vim-tab-bar-mode)
               (lambda (arg) (setq started arg tab-bar-tab-hints nil))))
      (my/tabs-setup))
    (should tab-bar-tab-hints)
    (should (= 1 started))))

(ert-deftest init-local-tabs-ghostel-keeps-m-digits-for-emacs ()
  (let ((ghostel-keymap-exceptions '("C-c" "M-3")))
    (cl-letf (((symbol-function 'customize-set-variable) (lambda (sym val) (set sym val))))
      (my/tabs-ghostel-exceptions))
    (should (= 9 (seq-count (lambda (k) (member k ghostel-keymap-exceptions)) my/tabs-select-keys)))
    (should (= 10 (length ghostel-keymap-exceptions)))))

(provide 'init-local-tabs-tests)
;;; init-local-tabs-tests.el ends here
