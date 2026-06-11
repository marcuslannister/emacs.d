;;; early-init.el --- Emacs 27+ pre-initialisation config  -*- lexical-binding: t; -*-

;;; Commentary:

;; Emacs 27+ loads this file before (normally) calling
;; `package-initialize'.  We use this file to suppress that automatic
;; behaviour so that startup is consistent across Emacs versions.

;;; Code:

(setq package-enable-at-startup nil)

;; Prefer newer source files over stale .elc — must be set before any other
;; load happens so it applies to early-init.el's own re-loads on next start.
(setq load-prefer-newer t)

(defun sanityinc/tui-session-p ()
  "Return non-nil for an interactive terminal-only startup."
  (and (not noninteractive)
       (not (display-graphic-p))
       (not (daemonp))))

;; Initialize package.el early so init.el can `use-package' compile-angel
;; before init-elpa.el runs.  init-elpa.el later re-applies these settings and
;; only initializes package.el if this file did not already do so.
(require 'package)
(setq package-user-dir
      (expand-file-name (format "elpa-%s.%s" emacs-major-version emacs-minor-version)
                        user-emacs-directory))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Restore previous frame size/position (must run before the first frame is
;; created so `initial-frame-alist' takes effect).
(defvar my/frame-state-file
  (expand-file-name "frame-state.el" user-emacs-directory)
  "File where the last frame geometry is persisted.")

(defun my/save-frame-state ()
  "Persist current frame geometry to `my/frame-state-file'."
  (when (display-graphic-p)
    (let* ((frame (selected-frame))
           (left (frame-parameter frame 'left))
           (top  (frame-parameter frame 'top)))
      ;; Skip save when frame is minimized (Windows reports -32000)
      (unless (and (integerp left) (integerp top)
                   (or (< left -31000) (< top -31000)))
        (with-temp-file my/frame-state-file
          (prin1 (list (cons 'left       left)
                       (cons 'top        top)
                       (cons 'width      (frame-parameter frame 'width))
                       (cons 'height     (frame-parameter frame 'height))
                       (cons 'fullscreen (frame-parameter frame 'fullscreen)))
                 (current-buffer)))))))

(defun my/load-frame-state ()
  "Apply saved geometry to `initial-frame-alist'."
  (when (file-exists-p my/frame-state-file)
    (condition-case nil
        (let ((state (with-temp-buffer
                       (insert-file-contents my/frame-state-file)
                       (read (current-buffer)))))
          (dolist (param state)
            (when (cdr param)
              (setf (alist-get (car param) initial-frame-alist) (cdr param)))))
      (error nil))))

(my/load-frame-state)
(add-hook 'kill-emacs-hook #'my/save-frame-state)

;; So we can detect this having been loaded
(provide 'early-init)

;;; early-init.el ends here
