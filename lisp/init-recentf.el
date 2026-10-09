;;; init-recentf.el --- Settings for tracking recent files -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(add-hook 'after-init-hook 'recentf-mode)
(setq-default
 recentf-max-saved-items 1000
 ;; Clean up on idle, not at startup: checking /sshx: entries loads Tramp,
 ;; and trampver.el runs git twice.
 recentf-auto-cleanup 300
 recentf-exclude `("/tmp/" "/ssh:" ,(concat package-user-dir "/.*-autoloads\\.el\\'")))


(provide 'init-recentf)
;;; init-recentf.el ends here
