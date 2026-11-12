;;; init-local-windows-native-comp.el --- Byte code only on Windows  -*- lexical-binding: t; -*-

;;; Commentary:

;; On Windows, load .elc byte code and never .eln native code.  Windows
;; Defender scans each .eln file as a DLL image before `load' returns, and an
;; .elc file is plain data.  On one Windows machine, loading org, org-agenda,
;; transient and vc-git took 8.6 s with .eln files and 0.6 s with byte code.
;; So: no JIT compile, no trampolines, and no .eln lookup.  The lookup also
;; finds the .eln files that the Emacs build ships (org and others), so
;; turning JIT off is not enough.
;; early-init.el loads this file before `package-activate-all'.  See ADR 0001.

;;; Code:

(setq native-comp-jit-compilation nil
      native-comp-enable-subr-trampolines nil
      ;; A folder that never holds a .eln file, so Emacs finds none.
      native-comp-eln-load-path (list (expand-file-name "var/no-eln/" user-emacs-directory)))

(provide 'init-local-windows-native-comp)
;;; init-local-windows-native-comp.el ends here
