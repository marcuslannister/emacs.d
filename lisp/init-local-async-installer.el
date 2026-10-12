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
     ;; LOAD nil: t loads every compiled file, including benchmark and demo scripts.
     dir 2 nil
     (lambda (file)
       (not (or (string-match-p "[/\\\\]tests?[/\\\\]" file)
                (string-suffix-p "-pkg.el" file)))))))

(advice-add 'async-installer-git--native-compile
            :override #'init-local-async-installer-native-compile)

(defun init-local-async-installer-git-update-one (package callback)
  "Update PACKAGE like `async-installer-git--update-one', but check git.
The original runs `git pull', which fails on the detached HEAD of a tag
checkout without fetching the new tag.  It ignores the exit codes and writes
`.gitcommit' anyway, so each later run reports \"Already at\" and skips the
package.  A failed clone leaves a directory without `.git'; git would then
run in the parent `~/.emacs.d' repository, so such a package fails instead.
Call CALLBACK with the package directory, or nil on failure."
  (let* ((tgt (or (plist-get package :commit) (plist-get package :branch)
                  (plist-get package :tag) "main"))
         (name (file-name-nondirectory
                (string-remove-suffix ".git" (plist-get package :repo))))
         (dir (expand-file-name name async-installer-git-install-dir))
         (cache-file (expand-file-name ".gitcommit" dir))
         (cached (if (file-exists-p cache-file)
                     (with-temp-buffer
                       (insert-file-contents cache-file)
                       (string-trim (buffer-string)))
                   ""))
         ;; Only a branch target can move after the checkout.
         (cmds `(("fetch" "--tags" "origin") ("checkout" ,tgt)
                 ,@(unless (or (plist-get package :commit) (plist-get package :tag))
                     '(("pull" "--ff-only"))))))
    (cond
     ((not (file-directory-p dir))
      (message "[async-git] Not installed, skip update: %s" name)
      (funcall callback nil))
     ((not (file-exists-p (expand-file-name ".git" dir)))
      (message "[async-git] Broken clone, delete and reinstall: %s" name)
      (funcall callback nil))
     ((string= cached tgt)
      (message "[async-git] Already at %s: %s" tgt name)
      (funcall callback dir))
     (t
      (message "[async-git] Updating %s: %s -> %s" name cached tgt)
      (async-start
       (lambda ()
         (let ((default-directory dir))
           (catch 'fail
             (dolist (args cmds t)
               (unless (eql 0 (apply #'call-process "git" nil nil nil args))
                 (throw 'fail nil))))))
       (lambda (ok)
         (if (not ok)
             (progn
               (message "[async-git] Update failed: %s" name)
               (funcall callback nil))
           (with-temp-file cache-file (insert tgt))
           (message "[async-git] Updated: %s -> %s" name tgt)
           (async-installer-git--native-compile dir)
           (funcall callback dir))))))))

(advice-add 'async-installer-git--update-one
            :override #'init-local-async-installer-git-update-one)

(setq async-installer-reload-files
      (list (expand-file-name "lisp/package-list.el" user-emacs-directory)))

(async-installer-reload)
(async-installer-auto-reload-mode 1)

(provide 'init-local-async-installer)
;;; init-local-async-installer.el ends here
