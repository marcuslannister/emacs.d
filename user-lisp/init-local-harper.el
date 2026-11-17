;;; init-local-harper.el --- Harper grammar check through Eglot -*- lexical-binding: t -*-
;;; Commentary:
;; Harper checks grammar and spelling offline.  Emacs talks to it through Eglot
;; and its language server, `harper-ls', which nix-config installs.
;; SPC e g g starts or stops it in an Org, Markdown, or text buffer.  There is
;; no mode hook: Harper does not parse Org syntax, so it marks agenda lines,
;; checklists, and code too.  Fix a mark with SPC e g a (`eglot-code-actions').
;;; Code:

(declare-function my/hel-leader-bind "init-local-hel")
(declare-function eglot-current-server "eglot")
(declare-function eglot-shutdown "eglot")
(defvar eglot-server-programs)
(defvar eglot-workspace-configuration)

(defconst my/harper-dict-file "~/.config/harper-ls/dictionary.txt"
  "User dictionary of Harper.  nix-config links it from dotfiles.")

(defun my/harper-setup ()
  "Register `harper-ls' with Eglot for Org, Markdown, and text buffers."
  (if (not (executable-find "harper-ls"))
      (display-warning 'init-local-harper
                       "harper-ls not found; Harper grammar check is off")
    (add-to-list 'eglot-server-programs
                 '((org-mode markdown-ts-mode text-mode) . ("harper-ls" "--stdio")))
    (setq-default eglot-workspace-configuration
                  (plist-put (default-value 'eglot-workspace-configuration)
                             :harper-ls
                             `(:dialect "American"
                               :userDictPath ,(expand-file-name my/harper-dict-file))))))

(defun my/harper-toggle ()
  "Start Harper in this prose buffer, or stop it if Eglot already runs here."
  (interactive)
  (unless (derived-mode-p 'org-mode 'markdown-ts-mode 'text-mode)
    (user-error "Harper checks only Org, Markdown, and text buffers"))
  (require 'eglot)
  (if (eglot-current-server)
      (eglot-shutdown (eglot-current-server))
    (call-interactively #'eglot)))

(with-eval-after-load 'eglot
  (my/harper-setup))

;; Eglot does not autoload this command, and the leader key must work before Eglot loads.
(autoload 'eglot-code-actions "eglot" nil t)
(my/hel-leader-bind "C-c e g g" #'my/harper-toggle
                    "C-c e g a" #'eglot-code-actions)

(provide 'init-local-harper)
;;; init-local-harper.el ends here
