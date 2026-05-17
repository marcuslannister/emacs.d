;;; init.el --- Load the full configuration -*- lexical-binding: t -*-
;;; Commentary:

;; This file bootstraps the configuration, which is divided into
;; a number of other files.

;;; Code:

;; load-prefer-newer is set in early-init.el so it applies from the very start.

(use-package compile-angel
  :demand t
  :config
  ;; Set `compile-angel-verbose' to nil to disable compile-angel messages.
  ;; (When set to nil, compile-angel won't show which file is being compiled.)
  (setq compile-angel-verbose t)

  ;; Uncomment the line below to compile automatically when an Elisp file is saved
  ;; (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode)

  ;; The following directive prevents compile-angel from compiling your init
  ;; files. If you choose to remove this push to `compile-angel-excluded-files'
  ;; and compile your pre/post-init files, ensure you understand the
  ;; implications and thoroughly test your code. For example, if you're using
  ;; the `use-package' macro, you'll need to explicitly add:
  ;; (eval-when-compile (require 'use-package))
  ;; at the top of your init file.
  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)

  ;; Ensure that quitting only occurs once Emacs finishes native compiling,
  ;; preventing incomplete or leftover compilation files in `/tmp`.
  (setq native-comp-async-query-on-exit t)
  (setq confirm-kill-processes t)
  ;;
  ;; Keep `native-comp-jit-compilation`. However, uncomment the following if Emacs
  ;; JIT native compilation should be disabled and completely replaced with
  ;; compile-angel. This can prevent redundant or repetitive background
  ;; compilations.
  ;;
  ;; (setq native-comp-jit-compilation nil)
  ;; (setq native-comp-deferred-compilation native-comp-jit-compilation) ; Deprecated

  ;; The following enables compilation of packages during installation;
  ;; compile-angel will handle it.
  (setq package-native-compile t)

  ;; Exclude the custom-file, recentf, and savehist files
  ;;
  ;; Ensure that compile-angel is loaded using `require`, `use-package`, or
  ;; another package manager, as compile-angel-excluded-files is declared after
  ;; the package is loaded.

  ;; Ensure that the value of `savehist-file` is updated before proceeding
  (with-eval-after-load "savehist"
    (push (concat "/" (file-name-nondirectory savehist-file))
          compile-angel-excluded-files))

  ;; Ensure that the value of `recentf-save-file` is updated before proceeding
  (with-eval-after-load "recentf"
    (push (concat "/" (file-name-nondirectory recentf-save-file))
          compile-angel-excluded-files))

  ;; Ensure that the value of `custom-file` is updated before proceeding
  (with-eval-after-load "cus-edit"
    (when (stringp custom-file)
      (push (concat "/" (file-name-nondirectory custom-file))
            compile-angel-excluded-files)))

  ;; Enable the (compile-angel-on-load-mode) mode after the above


  ;; A global mode that compiles .el files before they are loaded
  ;; using `load' or `require'.
  (compile-angel-on-load-mode 1))

;; Produce backtraces when errors occur: can be helpful to diagnose startup issues
;;(setq debug-on-error t)

(let ((minver "27.1"))
  (when (version< emacs-version minver)
    (error "Your Emacs is too old -- this config requires v%s or higher" minver)))
(when (version< emacs-version "28.1")
  (message "Your Emacs is old, and some functionality in this config will be disabled. Please upgrade if possible."))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'init-benchmarking) ;; Measure startup time

(defconst *spell-check-support-enabled* nil) ;; Enable with t if you prefer
(defconst *is-a-mac* (eq system-type 'darwin))


;; Adjust garbage collection threshold for early startup (see use of gcmh below)
(setq gc-cons-threshold (* 128 1024 1024))


;; Process performance tuning

(setq read-process-output-max (* 4 1024 1024))
(setq process-adaptive-read-buffering nil)


;; Bootstrap config


(setq custom-file (locate-user-emacs-file "custom.el"))
(require 'init-utils)
(require 'init-site-lisp) ;; Must come before elpa, as it may provide package.el
;; Calls (package-initialize)
(require 'init-elpa)      ;; Machinery for installing required packages
(require 'init-exec-path) ;; Set up $PATH


;; General performance tuning
(when (require-package 'gcmh)
  (setq gcmh-high-cons-threshold (* 128 1024 1024))
  (add-hook 'after-init-hook (lambda ()
                               (gcmh-mode)
                               (diminish 'gcmh-mode))))

(setq jit-lock-defer-time 0)


;; Allow users to provide an optional "init-preload-local.el"
(require 'init-preload-local nil t)

;; Load configs for specific features and modes
(require-package 'diminish)
(maybe-require-package 'scratch)
(require-package 'command-log-mode)

(require 'init-frame-hooks)
(require 'init-xterm)
;; (require 'init-themes)
(require 'init-osx-keys)
(require 'init-gui-frames)
(require 'init-dired)
(require 'init-isearch)
(require 'init-grep)
(require 'init-uniquify)
(require 'init-ibuffer)
(require 'init-flymake)
(require 'init-eglot)

(require 'init-recentf)
(require 'init-minibuffer)
(require 'init-hippie-expand)
(require 'init-corfu)
(require 'init-windows)
(require 'init-sessions)
(require 'init-mmm)

(require 'init-editing-utils)
(require 'init-whitespace)

(require 'init-vc)
(require 'init-darcs)
(require 'init-git)
(require 'init-github)

(require 'init-projectile)

(require 'init-compile)
(require 'init-crontab)
(require 'init-textile)
(require 'init-markdown)
(require 'init-csv)
;; (require 'init-erlang)
(require 'init-javascript)
;; (require 'init-php)
(require 'init-org)
(require 'init-nxml)
(require 'init-html)
(require 'init-css)
;; (require 'init-haml)
(require 'init-http)
(require 'init-python)
;; (require 'init-haskell)
;; (require 'init-elm)
;; (require 'init-purescript)
;; (require 'init-ruby)
;; (require 'init-rails)
;; (require 'init-sql)
;; (require 'init-ocaml)
;; (require 'init-j)
;; (require 'init-nim)
(require 'init-rust)
(require 'init-toml)
(require 'init-yaml)
;; (require 'init-docker)
(require 'init-terraform)
(require 'init-nix)
(maybe-require-package 'nginx-mode)
(maybe-require-package 'just-mode)
(when (maybe-require-package 'just-ts-mode)
  ;; Undo overly-optimistic autoloading, so that things still work in
  ;; Emacs 29 without treesitter
  (sanityinc/remove-auto-mode  'just-ts-mode))
(maybe-require-package 'justl)

(require 'init-paredit)
(require 'init-lisp)
(require 'init-sly)
(require 'init-clojure)
(require 'init-clojure-cider)

(when *spell-check-support-enabled*
  (require 'init-spelling))

(require 'init-misc)

(require 'init-folding)
;; (require 'init-dash)

;; (require 'init-ledger)
(require 'init-lua)
(require 'init-uiua)
;; (require 'init-zig)
(require 'init-terminals)

;; Extra packages which don't require any configuration

(require-package 'sudo-edit)
(maybe-require-package 'gnuplot)
(require-package 'htmlize)
(when *is-a-mac*
  (require-package 'osx-location))
(maybe-require-package 'dotenv-mode)
(maybe-require-package 'shfmt)

(when (maybe-require-package 'uptimes)
  (setq-default uptimes-keep-count 200)
  (add-hook 'after-init-hook (lambda () (require 'uptimes))))

(when (fboundp 'global-eldoc-mode)
  (add-hook 'after-init-hook 'global-eldoc-mode))

(require 'init-direnv)

(when (and (require 'treesit nil t)
           (fboundp 'treesit-available-p)
           (treesit-available-p))
  (require 'init-treesitter))



;; Allow access from emacsclient. Start early so later init failures
;; cannot prevent the server from running, but leave existing servers alone.
(require 'server)
(unless (server-running-p)
  (server-start))

;; Variables configured via the interactive 'customize' interface
(when (file-exists-p custom-file)
  (load custom-file))

;; Locales (setting them earlier in this file doesn't work in X)
(require 'init-locales)

;; Allow users to provide an optional "init-local" containing personal settings
(require 'init-local nil t)

(provide 'init)

;; Local Variables:
;; coding: utf-8
;; no-byte-compile: t
;; End:
;;; init.el ends here
