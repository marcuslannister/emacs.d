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

(defun init-local-etaf-scroll-down ()
  "Scroll the preview down, then put point on the middle window line."
  (interactive)
  (ebox-scroll-down)
  (move-to-window-line nil))

(defun init-local-etaf-scroll-up ()
  "Scroll the preview up, then put point on the middle window line."
  (interactive)
  (ebox-scroll-up)
  (move-to-window-line nil))

;; The autoload of `etaf-md-preview-open' loads etaf-md-preview-app, which
;; defines the map.  The `etaf-md-preview' feature may never load, so a
;; use-package :config for it can silently never run.
(with-eval-after-load 'etaf-md-preview-app
  ;; ebox remaps self-insert, so j and k beep. n and p scroll.
  (define-key etaf-md-preview-mode-map (kbd "j") #'init-local-etaf-scroll-down)
  (define-key etaf-md-preview-mode-map (kbd "k") #'init-local-etaf-scroll-up))

;; package-vc puts only lisp/ on `load-path', but each root file (etaf.el,
;; ebox.el, ...) sets up lisp/ itself and must be found at the package root.
(dolist (pkg '(ecss ebox etaf etaf-ui etaf-md-preview))
  (when-let* ((desc (cadr (assq pkg package-alist))))
    (add-to-list 'load-path (package-desc-dir desc))))

(provide 'init-local-etaf)
;;; init-local-etaf.el ends here
