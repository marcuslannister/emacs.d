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

;; Windows only: init-local-shell.el loads this fork via :load-path on Windows
;; (the only fork shipping a working Windows native runtime); Mac/Linux use the
;; MELPA `ghostel' instead.  Must NOT register off-Windows: async-installer would
;; clone it and put its `lisp/' ahead of the MELPA package on `load-path',
;; loading the stale v0.31.0 fork whose module downloader 404s (it fetches a
;; Windows `.tar.xz' bundle that dakra's releases do not ship for macOS/Linux).
;; external-packages/ is gitignored and not committed.
(when (eq system-type 'windows-nt)
  (async-installer-git-add "https://github.com/kiennq/ghostel.git"
                           :tag "v0.31.0.79.a7b0c9"
                           :subdir "lisp"
                           :main "ghostel.el"))

;; Hel: Helix-style modal editing.  Pinned to a commit, not a tag: this commit
;; sits 12 commits ahead of v0.12.0, the newest upstream tag, and those commits
;; carry real fixes -- multiple-cursors keys lost on a major-mode change, three
;; scroll fixes, a search variable used out of scope, and a duplicated advice.
;; Pinning the tag would give them up.  Move to `:tag' once upstream ships a
;; release that contains this commit.
;; Dependencies stay managed by package.el.
(async-installer-git-add "https://github.com/anuvyklack/hel.git"
                         :commit "93c88d8c67dcad08a7eb85949faf71b115973b5d"
                         :main "hel.el")

;; Native leader translation for Hel, pinned to the reviewed tag below.  The
;; two commits between v2.1 and the former commit pin are documentation only,
;; so the tag is functionally the same code.
(async-installer-git-add "https://github.com/anuvyklack/hel-leader.git"
                         :tag "v2.1"
                         :main "hel-leader.el")

;; Context-aware LLM proofreading.  The repo is a monorepo that tags each
;; package separately, so the tag is `proofread-v0.2.0', not `v0.2.0' (the
;; bare `v0.1.0' tag predates the split; `proofread-popup' ships its own
;; `proofread-popup-v*' tags and is not registered here).
;; `proofread.el' itself only pulls in built-ins, so it loads fine as-is;
;; the LLM backend (`proofread-llm.el') additionally needs `llm' >= 0.31.1
;; from GNU ELPA, which package.el must supply before that backend is used.
(async-installer-git-add "https://github.com/brsvh/emacs-proofread.git"
                         :tag "proofread-v0.2.0"
                         :subdir "lisp/proofread"
                         :main "proofread.el")
