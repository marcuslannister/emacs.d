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
;;; Code:

(defvar nn-proxy-port)
(declare-function telega--addProxy "telega-tdlib")

(defun my/telega-proxy ()
  "Make telega use the local SOCKS5 proxy of the Base (`nn-proxy-port')."
  (telega--addProxy
   `(:server "localhost" :port ,nn-proxy-port :type (:@type "proxyTypeSocks5"))
   :enable-p 'enable))

(use-package telega
  :if (eq system-type 'darwin)
  :hook ((telega-before-auth . my/telega-proxy)
         (telega-chat-mode . telega-completions-setup-capf))
  :custom
  (telega-server-libs-prefix "~/.local/share/tdlib")
  (telega-msg-save-dir "~/Downloads")
  (telega-translate-to-language-by-default "zh"))

(provide 'init-local-telega)
;;; init-local-telega.el ends here
