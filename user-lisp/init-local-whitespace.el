;;; init-local-whitespace.el --- Trim only the lines we edit, in programming modes -*- lexical-binding: t -*-
;;; Commentary:
;; The Base ran `delete-trailing-whitespace' before every save, in every buffer.
;; That rewrites lines we never touched: notes, other people's files, and
;; anything we only open and save.  `ws-butler' trims trailing whitespace only on
;; the lines we changed, and this module turns it on in `prog-mode' buffers only.
;;; Code:

(use-package ws-butler
  :hook (prog-mode . ws-butler-mode))

(provide 'init-local-whitespace)
;;; init-local-whitespace.el ends here
