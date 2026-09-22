;;; init-local-kp.el --- Knuth-Plass line breaking (emacs-kp) -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; async-installer only extends `load-path' during install postprocess, so —
;; as with anvil and proofread — the directory has to be re-added on every
;; startup.
(let ((kp-dir (expand-file-name "external-packages/emacs-kp" user-emacs-directory)))
  (when (file-directory-p kp-dir)
    (add-to-list 'load-path kp-dir)))

(when (require 'ekp nil t)
  (require 'ekp-buffer nil t))

(when (featurep 'ekp-buffer)
  ;; Cap the justified measure at a comfortable ~80-char reading width, but
  ;; still shrink for a narrower window/split (`narrowest-window' alone would
  ;; stretch prose across a full-frame Org buffer).
  (setq ekp-buffer-measure (cons 'max (* (frame-char-width) 80)))

  ;; On Emacs 31, automatic pixel measurement can crash native macOS font
  ;; lookup while `org-agenda-to-appt' visits Org files.  Keep the setup hooks
  ;; available for manual commands, but do not start automatic reflow there.
  (add-hook 'org-mode-hook #'ekp-org-setup)
  (add-hook 'markdown-mode-hook #'ekp-markdown-setup)
  (unless (>= emacs-major-version 31)
    (add-hook 'org-mode-hook #'ekp-auto-justify-mode)
    (add-hook 'markdown-mode-hook #'ekp-auto-justify-mode)))

(provide 'init-local-kp)
;;; init-local-kp.el ends here
