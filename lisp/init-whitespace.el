;;; init-whitespace.el --- Special handling for whitespace -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(setq-default show-trailing-whitespace nil)


;;; Whitespace

(defun sanityinc/show-trailing-whitespace ()
  "Enable display of trailing whitespace in this buffer."
  (setq-local show-trailing-whitespace t))

(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook hook 'sanityinc/show-trailing-whitespace))

;; (require-package 'whitespace-cleanup-mode)
;; (add-hook 'after-init-hook 'global-whitespace-cleanup-mode)
;; (with-eval-after-load 'whitespace-cleanup-mode
;;   (diminish 'whitespace-cleanup-mode))

(global-set-key [remap just-one-space] 'cycle-spacing)


;;; Visually mark tabs (global)
(with-eval-after-load 'whitespace
  (setq whitespace-style '(face tabs tab-mark))
  (setq whitespace-display-mappings
        '((tab-mark ?\t [?→ ?\t] [?\\ ?\t]))))
(require 'whitespace)
(global-whitespace-mode 1)


(provide 'init-whitespace)
;;; init-whitespace.el ends here
