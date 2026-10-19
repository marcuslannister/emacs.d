;;; init-local-etaf.el --- ETAF Markdown preview -*- lexical-binding: t; -*-

;;; Commentary:
;; etaf-md-preview needs ecss, ebox, etaf and etaf-ui.  None is on ELPA and
;; package-vc does not resolve VC dependencies, so install them in order.

;;; Code:

(dolist (pkg '(ecss ebox etaf etaf-ui))
  (unless (package-installed-p pkg)
    (package-vc-install (format "https://github.com/emacs-taf/%s" pkg))))

(use-package etaf-md-preview
  :ensure t
  :vc (:url "https://github.com/emacs-taf/etaf-md-preview")
  :commands etaf-md-preview-open)

;; package-vc puts only lisp/ on `load-path', but each root file (etaf.el,
;; ebox.el, ...) sets up lisp/ itself and must be found at the package root.
(dolist (pkg '(ecss ebox etaf etaf-ui etaf-md-preview))
  (when-let* ((desc (cadr (assq pkg package-alist))))
    (add-to-list 'load-path (package-desc-dir desc))))

(provide 'init-local-etaf)
;;; init-local-etaf.el ends here
