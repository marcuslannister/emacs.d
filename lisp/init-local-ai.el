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

;; Both lists must be set *before* `anvil-enable', which reads them to decide
;; what to load.  When they were set after it, `anvil-enable' saw the defaults
;; instead: `anvil-modules' defaults to a list that includes `org' (anvil.el:62),
;; so the org module loaded despite being left out below, and
;; `anvil-optional-modules' defaults to nil, so none of the optional ones loaded
;; at all.
;;
;; `org' is left out on purpose.  Its tools wrote to ~/org files independently
;; of the interactive buffers visiting the same files, which raced with them and
;; caused repeated Syncthing sync-conflict storms.
(setq anvil-modules '(worker eval file host git proc fs emacs text clipboard data net))

;; Enable optional modules.
;;
;; `state' is listed ahead of `shell-filter' and `context' because both
;; `(require 'anvil-state)' for their SQLite-backed blob store; loading it
;; first means its own `anvil-state-enable' has run before they do.
;; It needs Emacs 29+ with SQLite, which this build has.
;;
;; `disclosure' adds the Layer-2 `file-read-snippet' that `file-outline' and
;; `file-read' already point at in their own descriptions.  Its org-index
;; handler is referenced only in comments — the module itself requires just
;; cl-lib, anvil-server, and anvil-uri — so enabling it does NOT pull in the
;; org module or touch ~/org files.
;;
;; `shell-filter' adds shell-run / shell-filter / shell-tee-get / shell-gain;
;; `context' adds context-compress / -retrieve / -stats.
(setq anvil-optional-modules
      '(xlsx pdf http cron browser state shell-filter context disclosure))

(anvil-enable)
(anvil-server-start)


(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind ("C-c C-'" . claude-code-ide-menu) ; Set your favorite keybinding
  :custom
  (claude-code-ide-terminal-backend 'ghostel)
  (claude-code-ide-cli-extra-flags "--dangerously-skip-permissions")
  (claude-code-ide-use-ide-diff nil) ; no auto-ediff; diffs show in terminal. Toggle via menu (i), takes effect next session
  :config
  (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools


;; Proofread: context-aware LLM proofreading.  The endpoint is private, so the
;; feature lives in its own module backed by a gitignored config file.
(require 'init-local-proofread nil t)


(provide 'init-local-ai)
;;; init-local-ai.el ends here
