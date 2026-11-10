;;; init-local-vulpea.el --- Vulpea note database -*- lexical-binding: t -*-
;;; Commentary:
;; Vulpea indexes the Org notes in a SQLite database, for note search, link
;; insertion, and backlinks.  The database is var/vulpea/vulpea.db, which Git ignores.
;;
;; Vulpea is optional.  Its autosync mode keeps the index current on each save; it
;; starts with the first Org buffer, so startup does not load Vulpea.  If Vulpea
;; cannot start, a warning says so and Emacs goes on.
;;; Code:

(defvar org-mode-hook)
(declare-function vulpea-db-autosync-mode "vulpea-db-sync" (&optional arg))
(declare-function my/hel-leader-bind "init-local-hel")

(use-package vulpea
  :ensure t
  :custom
  (vulpea-db-location (locate-user-emacs-file "var/vulpea/vulpea.db"))
  (vulpea-db-sync-external-method nil)
  ;; Extract in a worker: it keeps the parsing at save time off the main thread.
  (vulpea-db-async-extraction 'full))

(defun my/vulpea-start ()
  "Turn on `vulpea-db-autosync-mode', once.  Never signals.
It runs from `org-mode-hook' and removes itself first, so a failure is not retried
on every Org buffer."
  (remove-hook 'org-mode-hook #'my/vulpea-start)
  (condition-case err
      (progn
        (require 'vulpea)
        (vulpea-db-autosync-mode +1))
    (error
     (display-warning 'init-local-vulpea
                      (format "Vulpea unavailable: %s.  Run M-x vulpea-doctor"
                              (error-message-string err))
                      :warning))))

(add-hook 'org-mode-hook #'my/vulpea-start)

;; The package has no autoload for these two commands, and every leader key must run
;; a defined command at startup.  A fresh install hides this: package.el compiles the
;; package in the same process and loads it.
(dolist (command '(vulpea-buffer-tags-add vulpea-buffer-tags-remove))
  (autoload command "vulpea-buffer" nil t))

(my/hel-leader-bind
 "C-c v f" #'vulpea-find
 "C-c v i" #'vulpea-insert
 "C-c v a" #'vulpea-buffer-tags-add
 "C-c v A" #'vulpea-buffer-tags-remove
 "C-c v u" #'vulpea-db-sync-full-scan
 "C-c v b" #'vulpea-find-backlink)

(provide 'init-local-vulpea)
;;; init-local-vulpea.el ends here
