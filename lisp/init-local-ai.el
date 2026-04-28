;;; Package --- ai settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(async-installer-git-add "https://github.com/zawatton/anvil.el.git"
                         :tag "v0.4.1"
                         :main "anvil.el")

(let ((anvil-dir (expand-file-name "external-packages/anvil.el" user-emacs-directory)))
  (when (file-directory-p anvil-dir)
    (add-to-list 'load-path anvil-dir)))

;; Start Anvil when it has already been installed by async-installer.
(when (require 'anvil nil t)
  (require 'anvil-server-commands nil t)

  ;; Choose which modules to load (defaults shown)
  (setq anvil-modules '(worker eval org file host git proc fs emacs text clipboard data net))

  ;; Enable optional modules
  (setq anvil-optional-modules '(xlsx pdf ide http cron browser))

  (anvil-enable)
  (when (and (fboundp 'anvil-server-start)
             (not (bound-and-true-p anvil-server--running)))
    (anvil-server-start)))


(provide 'init-local-ai)
;;; init-local-ai.el ends here
