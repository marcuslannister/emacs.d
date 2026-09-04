;;; init-local-vulpea.el --- Vulpea note database -*- lexical-binding: t; -*-
;;; Commentary:
;; Optional Vulpea indexing for note search, link insertion, and backlinks.
;;; Code:

(require 'org)

(defvar vulpea-db-location)
(defvar vulpea-db-sync-external-method nil)

(declare-function maybe-require-package "init-elpa"
                  (package &optional min-version no-refresh))
(declare-function vulpea-db-autosync-mode "vulpea-db-sync" (&optional arg))

(setq vulpea-db-location
      (expand-file-name "var/vulpea/vulpea.db" user-emacs-directory)
      vulpea-db-sync-external-method nil)

(when (maybe-require-package 'vulpea "2.6.0")
  (condition-case err
      (progn
        (require 'vulpea)
        ;; Keep Emacs saves indexed without polling or watching the directory.
        (vulpea-db-autosync-mode +1))
    (error
     (display-warning
      'init-local-vulpea
      (format "Vulpea unavailable: %s. Run M-x vulpea-doctor"
              (error-message-string err))
      :warning))))

(provide 'init-local-vulpea)
;;; init-local-vulpea.el ends here
