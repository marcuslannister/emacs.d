;;; init-vc.el --- Version control support -*- lexical-binding: t -*-
;;; Commentary:

;; Most version control packages are configured separately: see
;; init-git.el, for example.

;;; Code:

;; Nix/home-manager files are symlinks into git repos. Prompting on every
;; emacsclient visit made a second frame easy to open by mistake.
(setq vc-follow-symlinks t)

;; Experiment: drive daily work from vc-dir, keep magit for the hard parts.
;; `vc-dir-root' opens at the repo root without prompting.
(global-set-key (kbd "C-x g") 'vc-dir-root)
(sanityinc/fullframe-mode 'vc-dir-mode)

(when (maybe-require-package 'diff-hl)
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)
  (add-hook 'after-init-hook 'global-diff-hl-mode)

  (with-eval-after-load 'diff-hl
    (define-key diff-hl-mode-map (kbd "<left-fringe> <mouse-1>") 'diff-hl-diff-goto-hunk)
    (define-key diff-hl-mode-map (kbd "M-C-]") 'diff-hl-next-hunk)
    (define-key diff-hl-mode-map (kbd "M-C-[") 'diff-hl-previous-hunk)))

(provide 'init-vc)
;;; init-vc.el ends here
