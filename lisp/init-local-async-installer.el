;;; init-local-async-installer.el --- Bootstrap Git package installer -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(let ((dir (expand-file-name "external-packages/async-installer" user-emacs-directory)))
  (unless (file-exists-p (expand-file-name "async-installer.el" dir))
    (make-directory dir t)
    (message "Bootstrapping async-installer...")
    (call-process "git" nil nil nil "clone"
                  "https://github.com/zawatton/async-installer.git" dir))
  (add-to-list 'load-path dir))

(require 'async-installer)

(defun init-local-async-installer-native-compile (dir)
  "Native-compile DIR without loading package metadata or tests."
  (when (and async-installer-git-native-compile
             (fboundp 'native-compile-async))
    (message "[async-git] native-compile queued: %s" dir)
    (native-compile-async
     dir 2 t
     (lambda (file)
       (not (or (string-match-p "[/\\\\]tests?[/\\\\]" file)
                (string-suffix-p "-pkg.el" file)))))))

(advice-add 'async-installer-git--native-compile
            :override #'init-local-async-installer-native-compile)

(setq async-installer-reload-files
      (list (expand-file-name "lisp/package-list.el" user-emacs-directory)))

(async-installer-reload)
(async-installer-auto-reload-mode 1)

(provide 'init-local-async-installer)
;;; init-local-async-installer.el ends here
