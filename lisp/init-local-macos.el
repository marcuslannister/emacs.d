;;; Package --- macOS specific settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; macOS specific key bindings
(setq mac-option-modifier 'meta)
(setq mac-command-modifier 'super)

;; Install sis
(use-package sis
  :ensure t
  :config
  ;; Configure input sources based on platform
  (when *is-a-mac*
    (sis-ism-lazyman-config
     "com.apple.keylayout.ABC"
     "im.rime.inputmethod.Squirrel.Hans")

    ;; Set cursor colors for different input sources
    (setq sis-default-cursor-color "#b81e19") ; English input source
    (setq sis-other-cursor-color "#b81e19") ; Other input source (change as needed)

    ;; Enable global modes
    (sis-global-cursor-color-mode t)
    (sis-global-respect-mode t)
    (sis-global-context-mode t)

    ;; Auto-switch to other input source when entering Evil insert mode
    (add-hook 'evil-insert-state-entry-hook #'sis-set-other)
    (add-hook 'evil-insert-state-exit-hook #'sis-set-english)))

(use-package appine
  :ensure t
  :vc (:url "https://github.com/chaoswork/appine")
  :defer t
  :custom
  (appine-use-for-org-links t)
  :bind (("C-x a a" . appine)
         ("C-x a u" . appine-open-url)
         ("C-x a o" . appine-open-file)))

(provide 'init-local-macos)
;;; init-local-macos.el ends here
