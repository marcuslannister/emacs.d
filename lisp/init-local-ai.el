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

(setq anvil-modules '(worker eval file host git proc fs emacs text clipboard data net))

;; Enable optional modules
(setq anvil-optional-modules '(xlsx pdf http cron browser))


(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind ("C-c C-'" . claude-code-ide-menu) ; Set your favorite keybinding
  :custom
  (claude-code-ide-terminal-backend 'ghostel)
  (claude-code-ide-cli-extra-flags "--dangerously-skip-permissions")
  (claude-code-ide-use-ide-diff nil) ; no auto-ediff; diffs show in terminal. Toggle via menu (i), takes effect next session
  :config
  (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools


;; Proofread: context-aware LLM proofreading.  Registered in
;; lisp/package-list.el, but async-installer only
;; extends `load-path' during install postprocess, so — as with anvil above —
;; the directory has to be re-added on every startup.
(let ((proofread-dir (expand-file-name
                      "external-packages/emacs-proofread/lisp/proofread"
                      user-emacs-directory)))
  (when (file-directory-p proofread-dir)
    (add-to-list 'load-path proofread-dir)))

(use-package llm :ensure t)

(require 'auth-source)
(require 'llm-openai)

(defvar ml-proofread-gemini-checker
  `( :name gemini
     :backend llm
     :options ( :provider ,(make-llm-openai-compatible
                            ;; sone.19982002.xyz is an OpenAI-compatible proxy
                            ;; serving Gemini models.  `:url' stops before the
                            ;; command, so /v1/ not /v1/chat/completions.
                            :url "https://sone.19982002.xyz/v1/"
                            ;; llm resolves a function-valued `:key' at request
                            ;; time, so ~/.authinfo is read on first check and
                            ;; the secret never lands in the provider struct.
                            :key (lambda ()
                                   (auth-source-pick-first-password
                                    :host "sone.19982002.xyz"
                                    :user "apikey"))
                            :chat-model "sone-gemini-2.5-flash-think-0")
                :provider-identity "sone:gemini-2.5-flash-think"
                :source-label "gemini-2.5-flash-think"
                :response-strategy auto
                :diagnostic-passes 1))
  "Proofread LLM checker backed by the sone Gemini endpoint.")

;; The clone is asynchronous on a fresh machine, so tolerate proofread being
;; absent on the very first startup after registration.
(when (require 'proofread nil t)
  (setq proofread-profiles
        `((english . ( :language "en"
                       :display-language "English"
                       :checkers (,ml-proofread-gemini-checker)))))
  (setq proofread-profile 'english))


(provide 'init-local-ai)
;;; init-local-ai.el ends here
