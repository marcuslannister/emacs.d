;;; init-local-undo.el --- Redo on C-r and a saved undo history -*- lexical-binding: t -*-
;;; Commentary:
;; - Redo is the built-in `undo-redo' (Emacs 28 and later).  The Base binds it to
;;   `C-S-z', and Hel `U' calls it.  `C-r' was `isearch-backward'; it is `undo-redo' now,
;;   as in the earlier configuration.  Hel binds `C-r' only in its window map.
;;   There is no undo package: the built-in commands are enough.
;; - undo-fu-session saves the undo history of a file when the buffer is killed, and
;;   restores it when the file opens again.  It turns on during startup, not on the
;;   first key press: it restores the history in `find-file-hook', so a file opened
;;   before the first key press (`emacs FILE', or `emacsclient FILE' to a new server)
;;   would not get its history back.  Saving that buffer would then overwrite the
;;   saved history with the short new one.
;; - The undo limits are larger than the Base values, so a long editing session does
;;   not lose history.
;;; Code:

(keymap-global-set "C-r" #'undo-redo)

(defconst my/undo-session-directory (concat nn-directory "undo-fu-session/")
  "Folder for the saved undo histories.  It is generated state, under `nn-directory'.")

(use-package undo-fu-session
  :ensure t
  :demand t
  :custom
  (undo-fu-session-directory my/undo-session-directory)
  :config
  (undo-fu-session-global-mode 1))

;; emacs.d-nn: these values are the earlier configuration's, in bytes.
(setq-default undo-limit 67108864          ; 64 MB
              undo-strong-limit 100663296  ; 96 MB
              undo-outer-limit 1006632960) ; 960 MB

(provide 'init-local-undo)
;;; init-local-undo.el ends here
