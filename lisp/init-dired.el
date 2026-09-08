;;; init-dired.el --- Dired customisations -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(setq-default dired-dwim-target t)

;; Prefer g-prefixed coreutils version of standard utilities when available
(let ((gls (executable-find "gls")))
  (when gls (setq insert-directory-program gls)))

(when (maybe-require-package 'diredfl)
  (with-eval-after-load 'dired
    (diredfl-global-mode)
    (require 'dired-x)))

;; Hook up dired-x global bindings without loading it up-front
(define-key ctl-x-map "\C-j" 'dired-jump)
(define-key ctl-x-4-map "\C-j" 'dired-jump-other-window)

(with-eval-after-load 'dired
  (setq dired-recursive-deletes 'top)
  (define-key dired-mode-map [mouse-2] 'dired-find-file)
  (define-key dired-mode-map (kbd "C-c C-q") 'wdired-change-to-wdired-mode)
  (define-key dired-mode-map (kbd "'") 'dired-up-directory)
  (define-key dired-mode-map (kbd "/") 'dired-isearch-filenames)
  (define-key dired-mode-map (kbd "h") #'backward-char)
  (define-key dired-mode-map (kbd "j") #'dired-next-line)
  (define-key dired-mode-map (kbd "k") #'dired-previous-line)
  (define-key dired-mode-map (kbd "l") #'forward-char)
  (define-key dired-mode-map (kbd "n") 'isearch-repeat-forward)
  (define-key dired-mode-map (kbd "p") 'isearch-repeat-backward))

(defun sanityinc/diff-hl-dired-status-files-no-query (original &rest args)
  "Call ORIGINAL with ARGS, killing its temp status buffer without a prompt.
On Emacs 31 the ignored-files check leaves a live process behind when
`diff-hl-dired-update' kills the buffer, which asks to confirm the kill
from inside a Dired refresh."
  (let ((update-function (car (last args))))
    (apply original (append (butlast args)
                            (list (lambda (entries &optional more-to-come)
                                    (let ((kill-buffer-query-functions nil))
                                      (funcall update-function entries more-to-come))))))))

(when (maybe-require-package 'diff-hl)
  (with-eval-after-load 'diff-hl-dired
    (advice-add 'diff-hl-dired-status-files :around
                #'sanityinc/diff-hl-dired-status-files-no-query))
  (with-eval-after-load 'dired
    (add-hook 'dired-mode-hook 'diff-hl-dired-mode)))

(provide 'init-dired)
;;; init-dired.el ends here
