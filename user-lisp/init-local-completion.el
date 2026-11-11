;;; init-local-completion.el --- Annotations and icons for fido -*- lexical-binding: t -*-
;;; Commentary:
;; The Base uses fido (icomplete) for the minibuffer.  Icomplete reads the
;; `affixation-function' and `annotation-function' of a completion table, so fido
;; can show file details and icons without another completion UI.
;;
;; - marginalia adds the details: permissions, size, and date of a file, the doc string
;;   of a command, and so on.
;; - nerd-icons-completion adds an icon in front of each candidate.
;;
;; Both start with the first key press (`nn-first-input-hook'), not at startup.
;; Fido highlights only the text of the selected candidate, not the whole row.
;;; Code:

(use-package marginalia
  :ensure t
  :hook (nn-first-input . marginalia-mode))

(defun my/completion-icons-in-minibuffer-only (fn orig metadata prop)
  "Run FN, the icon advice of nerd-icons-completion, only in the minibuffer.
The icon advice wraps every `completion-metadata-get'.  The in-buffer popup (corfu)
has its own icons from `nerd-icons-corfu', so with this advice each row of that
popup shows two icons.  Call ORIG with METADATA and PROP when no minibuffer is current."
  (if (minibufferp)
      (funcall fn orig metadata prop)
    (funcall orig metadata prop)))

(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup)
  :config
  (advice-add 'nerd-icons-completion-completion-metadata-get :around
              #'my/completion-icons-in-minibuffer-only))

(provide 'init-local-completion)
;;; init-local-completion.el ends here
