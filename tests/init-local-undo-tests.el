;;; init-local-undo-tests.el --- Tests for init-local-undo -*- lexical-binding: t -*-
(require 'ert)
(require 'use-package)
;; -Q uses ~/.emacs.d: never install there.
(setq use-package-ensure-function #'ignore use-package-always-defer t)
(defvar nn-first-input-hook nil)
(defvar nn-directory "/tmp/nn-var/")
(add-to-list 'load-path (expand-file-name "../user-lisp" (file-name-directory load-file-name)))
(require 'init-local-undo)

(ert-deftest init-local-undo-session-files-live-under-nn-directory ()
  (should (string-prefix-p nn-directory my/undo-session-directory)))

(ert-deftest init-local-undo-limits-are-the-large-values ()
  (should (= 67108864 (default-value 'undo-limit)))
  (should (< (default-value 'undo-limit) (default-value 'undo-strong-limit)
             (default-value 'undo-outer-limit))))

(ert-deftest init-local-undo-c-r-is-the-builtin-redo ()
  (should (eq 'undo-redo (keymap-lookup global-map "C-r"))))

(provide 'init-local-undo-tests)
;;; init-local-undo-tests.el ends here
