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

;; Initialize package.el early so init.el can `use-package' compile-angel
;; before init-elpa.el runs.  init-elpa.el later re-applies these settings;
;; package-initialize is idempotent.
(require 'package)
(setq package-user-dir
      (expand-file-name (format "elpa-%s.%s" emacs-major-version emacs-minor-version)
                        user-emacs-directory))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; So we can detect this having been loaded
(provide 'early-init)

;;; early-init.el ends here
