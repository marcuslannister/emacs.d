;;; init-exec-path.el --- Set up exec-path to help Emacs find programs  -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(require-package 'exec-path-from-shell)

(with-eval-after-load 'exec-path-from-shell
  (dolist (var '("SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO" "LANG" "LC_CTYPE" "NIX_SSL_CERT_FILE" "NIX_PATH"))
    (add-to-list 'exec-path-from-shell-variables var)))


(when (or (memq window-system '(mac ns x pgtk))
          (unless (memq system-type '(ms-dos windows-nt))
            (daemonp)))
  (exec-path-from-shell-initialize))

(when (eq system-type 'windows-nt)
  ;; Emacs daemons can keep an older environment than interactive PowerShell.
  (let* ((local-bin (expand-file-name "~/.local/bin"))
         (local-bin-dir (file-name-as-directory local-bin))
         (path-entry (subst-char-in-string ?/ ?\\ local-bin))
         (path-entries (parse-colon-path (getenv "PATH"))))
    (when (file-directory-p local-bin)
      (add-to-list 'exec-path local-bin)
      (unless (or (member local-bin path-entries)
                  (member local-bin-dir path-entries)
                  (member path-entry path-entries))
        (setenv "PATH" (concat path-entry path-separator (getenv "PATH")))))))

(provide 'init-exec-path)
;;; init-exec-path.el ends here
