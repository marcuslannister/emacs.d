;;; Package ---  async-installer packagve settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:
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
