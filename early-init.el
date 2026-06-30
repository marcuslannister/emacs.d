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
;; created so `initial-frame-alist' takes effect).  The persisted geometry is
;; untrusted disposable cache; `lib/frame-state.el' validates it on load.
;; Loaded by absolute path because `lib/' is not yet on `load-path' here.
(load (expand-file-name "lib/frame-state" user-emacs-directory) t t)
(when (fboundp 'my/load-frame-state)
  (my/load-frame-state)
  (add-hook 'kill-emacs-hook #'my/save-frame-state))

;; So we can detect this having been loaded
(provide 'early-init)

;;; early-init.el ends here
