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

;; `C-x C-u' is one slip from `C-x u' (undo).  It runs `upcase-region' on the
;; text from the mark to point, with no prompt and no message.
(global-unset-key (kbd "C-x C-u"))

(provide 'init-local)
;;; init-local.el ends here
