;;; init-local-tabs-tests.el --- Tests for init-local-tabs -*- lexical-binding: t -*-
(require 'ert)
(require 'cl-lib)
(require 'use-package)
(setq use-package-ensure-function #'ignore use-package-always-defer t)
(defvar ghostel-keymap-exceptions '("C-c"))
(add-to-list 'load-path (expand-file-name "../user-lisp" (file-name-directory load-file-name)))
(require 'init-local-tabs)

(ert-deftest init-local-tabs-setup-shows-hints-and-starts-the-mode ()
  (let ((tab-bar-tab-hints t) (tab-bar-select-tab-modifiers nil) started)
    ;; The real mode sets the hints to nil, so the stub does the same.
    (cl-letf (((symbol-function 'vim-tab-bar-mode)
               (lambda (arg) (setq started arg tab-bar-tab-hints nil))))
      (my/tabs-setup))
    (should tab-bar-tab-hints)
    (should (= 1 started))
    (should (equal '(meta) tab-bar-select-tab-modifiers))))

(ert-deftest init-local-tabs-keys-are-m-0-to-m-9 ()
  (should (equal '("M-0" "M-1" "M-2" "M-3" "M-4" "M-5" "M-6" "M-7" "M-8" "M-9")
                 my/tabs-select-keys)))

(ert-deftest init-local-tabs-ghostel-keeps-m-digits-for-emacs ()
  (let ((ghostel-keymap-exceptions '("C-c" "M-3")))
    (cl-letf (((symbol-function 'customize-set-variable) (lambda (sym val) (set sym val))))
      (my/tabs-ghostel-exceptions))
    (should (= 10 (seq-count (lambda (k) (member k ghostel-keymap-exceptions)) my/tabs-select-keys)))
    (should (= 11 (length ghostel-keymap-exceptions)))))

(provide 'init-local-tabs-tests)
;;; init-local-tabs-tests.el ends here
