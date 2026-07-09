;;; Package ---  async-installer packagve settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:
;; Bumping anvil (Mac/Linux): edit the `:tag' below, then
;;   1. M-x async-installer-git-update-all-interactive  -- reads the new tag,
;;      runs git pull + checkout, rewrites the .gitcommit cache, native-compiles
;;   2. M-x anvil-server-install  -- refresh ~/.emacs.d/anvil-stdio.sh (the
;;      per-machine MCP stdio bridge) after the "[async-git] Updated" message
;;   3. restart Emacs and reconnect the MCP client
;; Do not `git checkout' external-packages/anvil.el by hand: it desyncs the
;; async-installer .gitcommit cache and skips the native-compile.
(async-installer-git-add "https://github.com/zawatton/anvil.el.git"
                         :tag "v1.3.0"
                         :main "anvil.el")

;; Windows-only in practice: init-local-shell.el loads this fork via
;; :load-path on Windows (the only fork shipping a working Windows native
;; runtime); Mac/Linux use the MELPA `ghostel' instead.  Registered here so a
;; fresh checkout's `async-installer-git-install-all-interactive' actually
;; clones it -- external-packages/ is gitignored and not committed.
(async-installer-git-add "https://github.com/kiennq/ghostel.git"
                         :tag "v0.31.0.79.a7b0c9"
                         :subdir "lisp"
                         :main "ghostel.el")

;; org-supertag: multi-file package (tracks the `main' branch).  async-installer
;; only clones + loads `org-supertag.el'; its ELPA deps (ht, gptel, websocket,
;; simple-httpd) must be installed separately, and a module must `require' it.
(async-installer-git-add "https://github.com/yibie/org-supertag.git"
                         :main "org-supertag.el")
