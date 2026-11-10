;;; init-local-exec-path.el --- Import the login shell environment on macOS -*- lexical-binding: t -*-
;;; Commentary:
;; A GUI Emacs on macOS starts with the short PATH that launchd gives it.  It
;; cannot find tools such as `rg', `fd', `git', or `herdr' that live in a
;; Homebrew or Nix directory.  This module copies PATH and a few other variables
;; from the login shell once, at startup.
;;
;; After the import it also picks the ls program again, because the Base chose it
;; before the import.  Windows keeps the Base's own PATH setup, so nothing runs
;; there.  If the import fails, or the package is missing, the module warns and
;; startup goes on.
;;; Code:

(defvar my/exec-path-variables
  '("PATH" "MANPATH" "LANG" "LC_CTYPE"
    "SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO"
    "NIX_PATH" "NIX_SSL_CERT_FILE")
  "Environment variables to copy from the login shell.")

(when (eq system-type 'darwin)
  (use-package exec-path-from-shell
    :custom (exec-path-from-shell-variables my/exec-path-variables))
  ;; A terminal Emacs inherits the shell's PATH already, so only a GUI frame or
  ;; a daemon needs the import.  Batch Emacs (the tests) skips it too.
  (when (or (display-graphic-p) (daemonp))
    (if (require 'exec-path-from-shell nil t)
        (condition-case err
            (progn
              (exec-path-from-shell-initialize)
              ;; The Base picked `insert-directory-program' from the short launchd
              ;; PATH, so it holds the BSD ls.  Pick again with the imported PATH.
              ;; `ls-lisp-use-insert-directory-program' needs no refresh: ls-lisp
              ;; is not loaded here, and /bin/ls makes the value non-nil anyway.
              (when-let* ((ls (executable-find "ls")))
                (setq insert-directory-program ls)))
          (error (display-warning 'init-local-exec-path
                                  (format "PATH import skipped: %s"
                                          (error-message-string err)))))
      (display-warning 'init-local-exec-path
                       "exec-path-from-shell is not installed; PATH import skipped"))))

(provide 'init-local-exec-path)
;;; init-local-exec-path.el ends here
