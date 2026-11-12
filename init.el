;;; -*- lexical-binding: t -*-

;; Font download link
;; [IBM Plex Mono](https://github.com/IBM/plex)
;; [Iosevka SS13](https://github.com/be5invis/Iosevka)
;; [LXGW WenKai Mono](https://github.com/lxgw/LxgwWenKai)
;; [Maple Mono](https://github.com/subframe7536/maple-font)
;; [Sarasa Mono SC](https://github.com/be5invis/Sarasa-Gothic)

(require 'cl-lib)

(use-package nn-init
  :ensure nil
  :init
  (let ((file-name-handler-alist nil))
    (require 'init-builtin)
    (require 'init-display)
    (require 'init-lang)
    (require 'init-editor)
    (require 'init-tools)
    (require 'init-www)
    (require 'init-keybind)
    (require 'init-home)
    ;; emacs.d-nn: the one hook for the Local layer.  It loads last, so it wins
    ;; every overlap.  See docs/adr/0001-fork-b-as-base.md.
    (require 'init-local))

  (defun nn-font-init ()
    ;; emacs.d-nn: use the default monospace font when it has the glyph, so symbols
    ;; in Ghostel and Herdr stay 1 column wide instead of falling back to proportional
    ;; Segoe UI Symbol or Apple Symbols.
    (setq use-default-font-for-symbols t)

    ;; Unicode
    (cl-loop for font in '("Segoe UI" "Arial Unicode MS")
             for spec = (font-spec :family font)
             when (find-font spec)
             return (set-fontset-font t 'unicode spec))
    ;; Symbol
    (cl-loop for font in '("Segoe UI Symbol" "Apple Symbols" "Symbol")
             for spec = (font-spec :family font)
             when (find-font spec)
             return (set-fontset-font t 'symbol spec))
    ;; Emoji
    (cl-loop for font in '("Segoe UI Emoji" "Apple Color Emoji" "Noto Color Emoji")
             for spec = (font-spec :family font)
             when (find-font spec)
             return (set-fontset-font t 'emoji spec))
    ;; Nerd Fonts
    (cl-loop for font in '("Symbols Nerd Font Mono")
             for spec = (font-spec :family font)
             when (find-font spec)
             return (progn
                      (set-fontset-font t '(#xe000 . #xf8ff) spec)
                      (set-fontset-font t '(#xf0000 . #xfffff) spec)))
    ;; Extra
    ;; emacs.d-nn: the same first fonts as the default font below.  Maple Mono NL is not
    ;; installed here, and Apple Symbols then draws box characters with seams.
    (cl-loop for font in (append (if (eq system-type 'windows-nt)
                                     '("Aporetic Sans Mono" "MonoLisa Nerd Font")
                                   '("MonoLisa Nerd Font" "Aporetic Sans Mono"
                                     "AporeticSansMono Nerd Font"))
                                 '("Maple Mono NL NF CN"))
             for spec = (font-spec :family font)
             when (find-font spec)
             return (progn
                      ;; Box Drawing and Block Elements.  emacs.d-nn: the range was up to #x257F only.
                      (set-fontset-font t '(#x2500 . #x259F) spec)
                      ;; Geometric Shapes
                      (set-fontset-font t '(#x25A0 . #x25FF) spec)))
    ;; Chinese
    ;; emacs.d-nn: Maple Mono NF CN first.
    (cl-loop for font in '("Maple Mono NF CN" "LXGW WenKai Mono" "Sarasa Mono SC"
                           "Microsoft YaHei" "DengXian" "Simhei")
             for spec = (font-spec :family font)
             when (find-font spec)
             return (progn
                      (set-fontset-font t 'han spec)
                      ;; Greek letters
                      (set-fontset-font t '(#x0370 . #x03FF) spec)))
    ;; Default
    ;; emacs.d-nn: Windows: Aporetic Sans Mono, then MonoLisa.  macOS and others: MonoLisa,
    ;; then Aporetic (on macOS it is installed as the Nerd Font).  Height 160 on macOS,
    ;; 140 elsewhere.
    (cl-loop for font in (append (if (eq system-type 'windows-nt)
                                     '("Aporetic Sans Mono" "MonoLisa Nerd Font")
                                   '("MonoLisa Nerd Font" "Aporetic Sans Mono"
                                     "AporeticSansMono Nerd Font"))
                                 '("IBM Plex Mono" "JetBrains Mono" "Iosevka SS13"
                                   "Cascadia Mono"))
             for spec = (font-spec :family font)
             when (find-font spec)
             return (set-face-attribute 'default nil :family font
                                        :height (if (eq system-type 'darwin) 160 140)))

    ;; Font Ligature
    ;; (cl-loop for chars in '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "==")
    ;;          for key = (aref chars 0)
    ;;          do (set-char-table-range
    ;;              composition-function-table  key
    ;;              (nconc (char-table-range composition-function-table key)
    ;;                     `(,(vector (regexp-quote chars) 0 'font-shape-gstring)))))
    )

  (defun nn-home-init ()
    (nn-home-create)
    (nn-home-set-margins)
    (nn-home-render)
    (nn-home-show)
    (goto-char (point-min))
    (nn-home-next-line))

  (defun nn-theme-init ()
    (require 'elegant-world-theme)
    (load-theme 'elegant-world t))

  (let ((hook (if (daemonp)
                  'server-after-make-frame-hook
                'after-init-hook)))
    (add-hook hook #'nn-font-init -100)
    (add-hook hook #'nn-home-init -90)
    ;; emacs.d-nn: the theme hook is removed.  user-lisp/init-local-themes.el loads
    ;; modus-operandi-tinted.  `nn-theme-init' stays above, unused, so a later
    ;; Upstream change to it does not conflict.
    ))
