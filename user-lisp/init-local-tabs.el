;;; init-local-tabs.el --- Vim-style tab bar, and M-1 to M-9 to pick a tab -*- lexical-binding: t -*-
;;; Commentary:
;; The tab bar is the built-in `tab-bar', styled by vim-tab-bar (as in the earlier
;; configuration): flat tabs that follow the theme, no close or new button, and the
;; number of each tab before its name.
;;
;; The keys come from the built-in `tab-bar-select-tab-modifiers' set to meta:
;; `M-1' to `M-8' select tab 1 to 8, `M-9' selects the last tab, and `M-0' selects the
;; tab used before.  (The earlier configuration made `M-9' select tab 9; the two
;; differ only with ten or more tabs.)
;;
;; Ghostel binds every M-<printable> key to the terminal, so these keys would never
;; reach Emacs in a terminal buffer.  They are keymap exceptions there.  Char mode
;; still sends them to the terminal, for a program that wants Alt-digit.
;;; Code:

(defvar ghostel-keymap-exceptions)
(declare-function vim-tab-bar-mode "vim-tab-bar")

(defconst my/tabs-select-keys (mapcar (lambda (n) (format "M-%d" n)) (number-sequence 0 9))
  "The tab keys that Ghostel must leave to Emacs.")

(defun my/tabs-setup ()
  "Turn on the Vim-style tab bar with the number of each tab.
The mode sets `tab-bar-tab-hints' to nil, so the hints come after it."
  (vim-tab-bar-mode 1)
  (setq tab-bar-tab-hints t)
  ;; `setopt': the `:set' function of the option defines the keys.
  (setopt tab-bar-select-tab-modifiers '(meta)))

(use-package vim-tab-bar
  :ensure t
  :commands vim-tab-bar-mode
  :hook (after-init . my/tabs-setup))

(defun my/tabs-ghostel-exceptions ()
  "Add the tab keys to `ghostel-keymap-exceptions'.
It must be `customize-set-variable': the option rebuilds the terminal keymap."
  (customize-set-variable
   'ghostel-keymap-exceptions
   (append ghostel-keymap-exceptions
           (seq-remove (lambda (key) (member key ghostel-keymap-exceptions))
                       my/tabs-select-keys))))

(with-eval-after-load 'ghostel (my/tabs-ghostel-exceptions))

(provide 'init-local-tabs)
;;; init-local-tabs.el ends here
