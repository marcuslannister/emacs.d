;;; Package --- ai settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(let ((anvil-dir (expand-file-name "external-packages/anvil.el" user-emacs-directory)))
  (when (file-directory-p anvil-dir)
    (add-to-list 'load-path anvil-dir)))

(require 'anvil)
;; anvil-server-commands holds anvil-server-start / -stop etc.  It is
;; autoload-cookied, but manual-install (plain add-to-list + require) does
;; not generate loaddefs, so we require it explicitly.
(require 'anvil-server-commands)
(anvil-enable)
(anvil-server-start)

(setq anvil-modules '(worker eval org file host git proc fs emacs text clipboard data net))

;; Enable optional modules
(setq anvil-optional-modules '(xlsx pdf ide http cron browser))


(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind ("C-c C-'" . claude-code-ide-menu) ; Set your favorite keybinding
  :custom
  (claude-code-ide-terminal-backend 'ghostel)
  :config
  (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools


(provide 'init-local-ai)
;;; init-local-ai.el ends here
