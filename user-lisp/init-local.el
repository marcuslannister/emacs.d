;;; init-local.el --- Entry point of the Local layer -*- lexical-binding: t -*-
;;; Commentary:
;; The Base's init.el loads this file last, so the Local layer wins every
;; overlap.  It is the one hook: the Base has a single `require' line for it, and
;; this file loads each local module.
;;
;; The case guard and the PATH import load now, not from `nn-first-input-hook'.
;; A timer, an `emacsclient' call, or code that runs at startup can save or
;; rewrite a file before the first key press, and the case guard exists to stop
;; exactly that.  Loading them costs a few milliseconds.  A module that can wait
;; keeps its own deferred `use-package' form.
;;; Code:

(require 'init-local-case-guard)
(require 'init-local-exec-path)
(require 'init-local-whitespace)
;; Loading it only registers a deferred `use-package' form for Dired.
(require 'init-local-dired)
(require 'init-local-async-installer)

;; Registers the pinned Git packages and adds the existing clones to
;; `load-path'.  It warns and goes on if `async-installer' is not available.
(my/async-installer-setup)

;; Modal editing must be ready before the first key press.
(require 'init-local-hel)
(my/hel-setup)

;; Org.  These modules add leader keys, so they load after Hel.  Loading them
;; registers deferred `use-package' forms and a few functions; Org itself loads on
;; first use.
(require 'init-local-org)
(require 'init-local-org-norang)
(require 'init-local-append-review)
(require 'init-local-gtd)
(my/gtd-setup)
(require 'init-local-denote)
(require 'init-local-vulpea)
(require 'init-local-themes)
(require 'init-local-completion)
(require 'init-local-tabs)
(require 'init-local-undo)
(require 'init-local-auto-save)
(require 'init-local-ghostel)
(require 'init-local-herdr)
(my/herdr-setup)
(require 'init-local-zoxide)
(my/zoxide-setup)

(require 'init-local-server)
(my/server-start)

;; Anvil is on by default on macOS and Windows: this schedules nothing unless
;; `my/anvil-enabled' is set.
(require 'init-local-anvil)
(my/anvil-setup)

;; `C-x C-u' is one slip from `C-x u' (undo).  It runs `upcase-region' on the
;; text from the mark to point, with no prompt and no message.
(global-unset-key (kbd "C-x C-u"))

(provide 'init-local)
;;; init-local.el ends here
