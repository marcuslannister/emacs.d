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
                                 (kill-buffer buf))))
                           (when (featurep (quote hel-leader))
                             (with-temp-buffer
                               (special-mode)
                               (unless (and (eq hel-state (quote emacs))
                                            (eq (key-binding (kbd "SPC"))
                                                (quote hel-leader))
                                            (eq (key-binding (kbd "C-c b n"))
                                                (quote next-buffer))
                                            (eq (key-binding (kbd "C-c v t"))
                                                (quote my/vulpea-task-table))
                                            (equal hel-leader-ctrl-meta-prefix "G"))
                                 (error "Hel leader unavailable: state=%S SPC=%S buffer=%S vulpea=%S C-M=%S"
                                        hel-state
                                        (key-binding (kbd "SPC"))
                                        (key-binding (kbd "C-c b n"))
                                        (key-binding (kbd "C-c v t"))
                                        hel-leader-ctrl-meta-prefix))
                               (let ((hel-leader--keys nil)
                                     (hel-leader--pending-modifier nil)
                                     (hel-leader--command nil))
                                 (hel-leader--handle-input-event ?b)
                                 (unless (and (eq (hel-leader--handle-input-event ?n)
                                                  :quit)
                                              (eq hel-leader--command
                                                  (quote next-buffer)))
                                   (error "SPC b n translation failed: %S"
                                          hel-leader--command)))
                               (let ((hel-leader--keys nil)
                                     (hel-leader--pending-modifier nil)
                                     (hel-leader--command nil))
                                 (hel-leader--handle-input-event ?v)
                                 (unless (and (eq (hel-leader--handle-input-event ?t)
                                                  :quit)
                                              (eq hel-leader--command
                                                  (quote my/vulpea-task-table)))
                                   (error "SPC v t translation failed: %S"
                                          hel-leader--command))))
                             (let ((my/hel--installing nil)
                                   (inhibit-message t)
                                   (load-path load-path)
                                   (install-calls 0))
                               (cl-letf (((symbol-function
                                           (quote my/hel--missing-package))
                                          (lambda () "hel-leader"))
                                         ((symbol-function
                                           (quote async-installer-git--install-one))
                                          (lambda (_package callback)
                                            (setq install-calls
                                                  (1+ install-calls))
                                            (funcall callback
                                                     temporary-file-directory))))
                                 (my/hel--install))
                               (unless (= install-calls 1)
                                 (error "Broken Hel install retried %d times"
                                        install-calls)))
                             (require (quote dired))
                             (let ((buf (dired-noselect temporary-file-directory)))
                               (unwind-protect
                                   (with-current-buffer buf
                                     (unless (and (eq hel-state (quote normal))
                                                  (eq (key-binding (kbd "SPC"))
                                                      (quote hel-leader))
                                                  (eq (key-binding (kbd "C-c b n"))
                                                      (quote next-buffer))
                                                  (eq (key-binding (kbd "h"))
                                                      (quote hel-backward-char))
                                                  (eq (key-binding (kbd "j"))
                                                      (quote hel-next-line))
                                                  (eq (key-binding (kbd "k"))
                                                      (quote hel-previous-line))
                                                  (eq (key-binding (kbd "l"))
                                                      (quote hel-forward-char)))
                                       (error "Dired Normal keys: %S %S %S %S"
                                              hel-state
                                              (key-binding (kbd "SPC"))
                                              (key-binding (kbd "C-c b n"))
                                              (mapcar (lambda (key)
                                                        (key-binding (kbd key)))
                                                      (quote ("h" "j" "k" "l")))))
                                     (hel-switch-state (quote emacs))
                                     (unless (equal
                                              (mapcar
                                               (lambda (key)
                                                 (key-binding (kbd key)))
                                               (quote ("h" "j" "k" "l")))
                                              (quote (backward-char dired-next-line
                                                      dired-previous-line forward-char)))
                                       (error "Dired Emacs-state hjkl unavailable: %S"
                                              (mapcar
                                               (lambda (key)
                                                 (key-binding (kbd key)))
                                               (quote ("h" "j" "k" "l"))))))
                                 (when (buffer-live-p buf)
                                   (kill-buffer buf)))))))'
echo "Startup successful"
