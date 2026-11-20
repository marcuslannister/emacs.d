;;; init-local-telega.el --- Telega, the Telegram client, on macOS only -*- lexical-binding: t -*-
;;; Commentary:
;; The Base form of telega is removed (init-www.el): `use-package-always-ensure' made it
;; install telega on every machine, and telega does not compile on Windows.  This module
;; brings it back for macOS only.  `:if' skips the whole form, the install included, so no
;; other system installs, hooks, or loads telega.  Telega loads on the first `M-x telega'.
;;
;; telega-server needs TDLib 1.8.66 or newer.  nix-config links it to ~/.local/share/tdlib on
;; the Apple silicon Macs (nixpkgs-unstable; the Intel Mac has none).  With TDLib in place,
;; the first `M-x telega' offers to build the server; build it again after a TDLib update.
;; Telegram needs the proxy of the Base (`nn-proxy-port'), so the proxy is set before login.
;;
;; Telega's default symbols need the Symbola font, which nix-config installs.  It is the
;; fallback for all Unicode, so it also covers odd characters inside messages.
;;; Code:

(defvar nn-proxy-port)
(defvar corfu-auto)
(declare-function corfu-mode "corfu" (&optional arg))
(declare-function telega--addProxy "telega-tdlib")
(declare-function hel-set-initial-state "hel-core")

(defun my/telega-proxy ()
  "Make telega use the local SOCKS5 proxy of the Base (`nn-proxy-port')."
  (telega--addProxy
   `(:server "localhost" :port ,nn-proxy-port :type (:@type "proxyTypeSocks5"))
   :enable-p 'enable))

(defun my/telega-symbol-font-setup ()
  "Use Symbola as the last fallback font, as the telega FAQ advises.
Telega draws symbols (a boost mark, a keyboard, and others) that no font of macOS has, so
Emacs shows a hex box.  Warn and go on when Symbola is not installed."
  (if (member "Symbola" (font-family-list))
      (set-fontset-font t 'unicode "Symbola" nil 'append)
    (display-warning 'init-local-telega
                     "The Symbola font is not installed; some telega symbols show as hex boxes")))

(defun my/telega-hel-button-binding (command)
  "Use the button's COMMAND outside Hel Normal navigation in Telega."
  (unless (and (eq (bound-and-true-p hel-state) 'normal)
               (derived-mode-p 'telega-root-mode 'telega-chat-mode))
    command))

(defun my/telega-hel-setup ()
  "Start Telega buffers in Hel Normal state for navigation."
  (when (fboundp 'hel-set-initial-state)
    (dolist (mode '(telega-root-mode telega-chat-mode))
      (hel-set-initial-state mode 'normal))
    ;; Button keymaps take precedence over Hel's state keymaps at point.
    (dolist (binding '((telega-chat-button-map "h" telega-describe-chat)
                       (telega-msg-button-map "l" telega-msg-copy-link)
                       (telega-sticker-button-map "h" telega-sticker-help)
                       (telega-story-button-map "h" telega-describe-story)
                       (telega-topic-button-map "h" telega-describe-topic)))
      (pcase-let ((`(,map ,key ,command) binding))
        (keymap-set (symbol-value map) key
                    `(menu-item "" ,command :filter my/telega-hel-button-binding))))))

(defun my/telega-chat-popup-setup ()
  "Show completion at the chat input when requested."
  (when (fboundp 'corfu-mode)
    ;; A Telegram lookup can block typing if it runs automatically.
    (setq-local corfu-auto nil)
    (corfu-mode 1)))

(use-package telega
  :if (eq system-type 'darwin)
  :hook ((telega-before-auth . my/telega-proxy)
         (telega-chat-mode . telega-completions-setup-capf)
         (telega-chat-mode . my/telega-chat-popup-setup))
  :custom
  (telega-server-libs-prefix "~/.local/share/tdlib")
  (telega-msg-save-dir "~/Downloads")
  (telega-translate-to-language-by-default "zh")
  :config
  (my/telega-symbol-font-setup)
  (my/telega-hel-setup))

(provide 'init-local-telega)
;;; init-local-telega.el ends here
