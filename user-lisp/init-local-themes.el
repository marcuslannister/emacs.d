;;; init-local-themes.el --- Modus Operandi Tinted -*- lexical-binding: t -*-
;;; Commentary:
;; The theme is `modus-operandi-tinted' with a few palette overrides.  The Base's
;; `elegant-world' theme stays in its file but no longer loads (see init.el).
;; Fonts stay with the Base's `nn-font-init'.
;;; Code:

(defvar minibuffer-frame--frame)
(declare-function modus-themes-get-color-value "modus-themes")
(declare-function my/hel-leader-bind "init-local-hel")

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
     ;; The fringe has the text background, so two windows show no darker band
     ;; between them (the Base has wide fringes).
     (fringe unspecified)
     (fg-line-number-inactive "gray50")
     (fg-line-number-active fg-main)
     (bg-line-number-inactive unspecified)
     (bg-line-number-active unspecified)))
  :config
  ;; A 256-color terminal maps ANSI color 0 to the background in some terminals
  ;; (Kitty).  #080808 maps exactly to xterm grayscale slot 232 instead.
  (unless (display-graphic-p)
    (setq modus-operandi-tinted-palette-overrides '((fg-main "#080808"))))
  (load-theme 'modus-operandi-tinted :no-confirm))

;; F5 stays with the debugger of the Base (dape).  The theme toggle is on the leader.
(my/hel-leader-bind "C-c T" #'modus-themes-toggle)

;; The minibuffer frame of the Base takes its background from the `tooltip' face,
;; which Modus draws in a dark beige.  Give it the editor background, as the
;; completion popup of the earlier configuration had.  Real tooltips keep `tooltip'.
(defun my/minibuffer-frame-sync-background (&rest _)
  "Set the background of the minibuffer child frame to the default background.
Do nothing when that frame does not exist."
  (when (and (boundp 'minibuffer-frame--frame) (frame-live-p minibuffer-frame--frame))
    (set-frame-parameter minibuffer-frame--frame 'background-color
                         (face-background 'default (frame-parent minibuffer-frame--frame)))))

;; The minibuffer frame is one line high, and the package grows it only for the
;; candidate list of fido.  A prompt of several lines (the first-run question of
;; Ghostel, `read-multiple-choice') then shows only its last line.  Fit the frame to
;; the prompt when a minibuffer opens.  A long line wraps, so count the wrapped lines.
(defun my/minibuffer-frame-fit-prompt (&rest _)
  "Make the minibuffer child frame tall enough for the whole prompt.
Do nothing when the frame does not exist or the prompt has one line."
  (when (and (boundp 'minibuffer-frame--frame) (frame-live-p minibuffer-frame--frame))
    (let* ((width (max 1 (frame-width minibuffer-frame--frame)))
           (lines (apply #'+ (mapcar (lambda (line) (max 1 (ceiling (string-width line) width)))
                                     (split-string (or (minibuffer-prompt) "") "\n")))))
      (when (> lines 1)
        (set-frame-height minibuffer-frame--frame lines)))))

(with-eval-after-load 'minibuffer-frame
  (advice-add 'minibuffer-frame--init :after #'my/minibuffer-frame-sync-background)
  (advice-add 'minibuffer-frame--setup :after #'my/minibuffer-frame-fit-prompt))
;; A theme change (the toggle) must update a frame that already exists.
(add-hook 'enable-theme-functions #'my/minibuffer-frame-sync-background)

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
