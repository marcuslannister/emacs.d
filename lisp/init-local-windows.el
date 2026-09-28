;; windows-config.el - windows specific settings  -*- lexical-binding: t; -*-

;; Windows paths with forward slashes
(setq default-directory "~/")

;; Default browser on Windows
(setq browse-url-browser-function 'browse-url-default-windows-browser)

;; Fix performance issues on Windows
(setq w32-get-true-file-attributes nil)
(setq inhibit-compacting-font-caches t)

;; `executable-find' costs 1.5-5 ms per call here (about 0.1 ms on macOS).
;; Keep .cmd: npm installs its programs as .cmd shims.
(setq exec-suffixes '("" ".exe" ".cmd" ".bat" ".com")
      exec-path (delete-dups (mapcar #'directory-file-name exec-path)))

(defvar my-executable-find-cache (make-hash-table :test 'equal :size 100))

(defun my-executable-find-clear-cache (&rest _)
  (clrhash my-executable-find-cache))

;; Clear when the global PATH changes.  Buffer-local changes (envrc)
;; skip the cache in the advice.
(add-variable-watcher 'exec-path
                      (lambda (_sym _new _op where)
                        (unless where (my-executable-find-clear-cache))))

(define-advice executable-find (:around (orig-fun command &optional remote) my-cache)
  (if (or remote (local-variable-p 'exec-path))
      (funcall orig-fun command remote)
    (let ((hit (gethash command my-executable-find-cache 'miss)))
      (if (eq hit 'miss)
          (puthash command (funcall orig-fun command) my-executable-find-cache)
        hit))))

;; These defaults call `executable-find' when their package loads.
(setq sgml-validate-command nil
      shell-command-guess-open "open")  ; `dired-do-open' uses w32-shell-execute

;; `vc-refresh-state' costs about 230 ms per file here.  Without it the
;; mode line shows no Git branch; vc-dir, Magit and diff-hl still work.
(remove-hook 'find-file-hook #'vc-refresh-state)

(defun my-open-in-external-app ()
  "Open the current file in an external app."
  (interactive)
  (require 'dired-aux)
  (shell-command-do-open (list (or buffer-file-name (user-error "Buffer has no file")))))

;; Set cursor color
(set-face-attribute 'cursor nil :background "#d00000")

(provide 'init-local-windows)
