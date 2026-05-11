#!/bin/sh -e
echo "Attempting startup..."
${EMACS:=emacs} -nw --batch \
                --eval '(progn
                        (defvar url-show-status)
                        (let ((debug-on-error t)
                              (url-show-status nil)
                              (user-emacs-directory default-directory)
                              (early-init-file (expand-file-name "early-init.el"))
                              (user-init-file (expand-file-name "init.el"))
                              (load-path (delq default-directory load-path)))
                           (setq package-check-signature nil)
                           (load-file early-init-file)
                           (load-file user-init-file)
                           (run-hooks (quote after-init-hook))
                           (require (quote eshell))
                           (let ((buf (eshell t)))
                             (unwind-protect
                                 (with-current-buffer buf
                                   (goto-char (point-max))
                                   (when (fboundp (quote evil-insert-state))
                                     (evil-insert-state))
                                   (unless (eq (key-binding (kbd "RET"))
                                               (quote eshell-send-input))
                                     (error "Eshell RET should submit input, got %S"
                                            (key-binding (kbd "RET")))))
                               (when (buffer-live-p buf)
                                 (kill-buffer buf))))))'
echo "Startup successful"
