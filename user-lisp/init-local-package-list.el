;;; init-local-package-list.el --- Git packages that async-installer installs  -*- lexical-binding: t; -*-
;;; Commentary:
;; Each entry names a tag, and the tag is the pin.  `async-installer-reload'
;; loads this file, so a bump takes effect without a restart.  Move a tag on
;; purpose, and test the package when you do.
;;; Code:

;; Bumping anvil: edit the `:tag' below, then
;;   1. M-x my/update-all-packages  -- reads the new tag, fetches and checks
;;      it out, rewrites the .gitcommit cache, native-compiles, and refreshes
;;      the Anvil bridge script (the per-machine MCP stdio bridge) when Anvil
;;      is loaded
;;   2. restart Emacs and reconnect the MCP client
;; Do not `git checkout' var/external-packages/anvil.el by hand: it desyncs the
;; async-installer .gitcommit cache and skips the native-compile.
(async-installer-git-add "https://github.com/zawatton/anvil.el.git"
                         :tag "v1.4.1"
                         :main "anvil.el")

;; Hel: Helix-style modal editing.  v0.13.0 now contains the fixes this was
;; pinned to a commit for (multiple-cursors keys lost on a major-mode change,
;; three scroll fixes, a search variable used out of scope, a duplicated
;; advice), so it moved from `:commit' to the tag.
;; Dependencies stay managed by package.el.
(async-installer-git-add "https://github.com/anuvyklack/hel.git"
                         :tag "v0.13.0"
                         :main "hel.el")

;; Native leader translation for Hel, pinned to the reviewed tag below.  The
;; two commits between v2.1 and the former commit pin are documentation only,
;; so the tag is functionally the same code.
(async-installer-git-add "https://github.com/anuvyklack/hel-leader.git"
                         :tag "v2.1"
                         :main "hel-leader.el")

;; GTD process layer.  Pinned to a tag: `org-gtd-refile-prompt-for-types' is
;; obsolete from 4.1.0, and on master the type registry migration silently skips
;; `project-heading' and `project-task', so projects would auto-file into
;; org-gtd-tasks.org instead of prompting for a topic file.  4.6.1 is the newest
;; release; move the tag deliberately, and re-test the refile prompt when you do.
;; Dependencies (org-edna from GNU ELPA, transient) stay with package.el.
(async-installer-git-add "https://github.com/Trevoke/org-gtd.el.git"
                         :tag "4.6.1"
                         :main "org-gtd.el")

(provide 'init-local-package-list)
;;; init-local-package-list.el ends here
