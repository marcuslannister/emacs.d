;;; init-local-git.el --- Personal git convenience commands -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defun my/git-push ()
  "Push the current branch to its push-remote.
On a branch with no upstream, push to origin and set upstream."
  (interactive)
  (require 'magit)
  (if (magit-get-upstream-branch)
      (magit-push-current-to-pushremote nil)
    (magit-push-current-to-upstream "origin" '("--set-upstream"))))

(defun my/git-pull-ff-only ()
  "Fetch and fast-forward the current branch; never auto-merge."
  (interactive)
  (require 'magit)
  (magit-pull-from-upstream '("--ff-only")))

(provide 'init-local-git)
;;; init-local-git.el ends here
