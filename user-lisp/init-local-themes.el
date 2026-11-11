;;; init-local-themes.el --- Modus Operandi Tinted -*- lexical-binding: t -*-
;;; Commentary:
;; The theme is `modus-operandi-tinted' with a few palette overrides.  The Base's
;; `elegant-world' theme stays in its file but no longer loads (see init.el).
;; Fonts stay with the Base's `nn-font-init'.
;;; Code:

(declare-function modus-themes-get-color-value "modus-themes")

(use-package modus-themes
  :ensure t
  :demand t
  :custom
  (modus-themes-italic-constructs nil)
  (modus-themes-bold-constructs t)
  (modus-themes-headings '((1 . (rainbow overline background 1.4))
                           (2 . (rainbow background 1.3))
                           (3 . (rainbow bold 1.2))
                           (t . (semilight 1.1))))
  ;; Colorful foregrounds for the first three heading levels, and quieter line numbers.
  (modus-themes-common-palette-overrides
   '((fg-heading-1 blue-warmer)
     (bg-heading-1 bg-blue-nuanced)
     (overline-heading-1 blue)
     (fg-heading-2 yellow-cooler)
     (fg-heading-3 cyan-cooler)
     (prose-done fg-dim)
     (fg-line-number-inactive "gray50")
     (fg-line-number-active fg-main)
     (bg-line-number-inactive unspecified)
     (bg-line-number-active unspecified)))
  :bind ("<f5>" . modus-themes-toggle)
  :config
  ;; A 256-color terminal maps ANSI color 0 to the background in some terminals
  ;; (Kitty).  #080808 maps exactly to xterm grayscale slot 232 instead.
  (unless (display-graphic-p)
    (setq modus-operandi-tinted-palette-overrides '((fg-main "#080808"))))
  (load-theme 'modus-operandi-tinted :no-confirm))

;; Org TODO words follow the palette.
(with-eval-after-load 'org
  (when (fboundp 'modus-themes-get-color-value)
    (defvar org-todo-keyword-faces)
    (setq org-todo-keyword-faces
          `(("TODO" . (:foreground ,(modus-themes-get-color-value 'green-intense)
                                   :weight bold))
            ("NEXT" . (:foreground ,(modus-themes-get-color-value 'blue) :weight bold))
            ("DONE" . (:foreground ,(modus-themes-get-color-value 'fg-dim) :weight bold))
            ("WAIT" . (:foreground ,(modus-themes-get-color-value 'cyan) :weight bold))
            ("CNCL" . (:foreground ,(modus-themes-get-color-value 'fg-dim)
                                   :weight bold))))))

(provide 'init-local-themes)
;;; init-local-themes.el ends here
