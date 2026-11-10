;;; init-local-dired.el --- Dired listing that the ls program accepts -*- lexical-binding: t -*-
;;; Commentary:
;; The Base sets `dired-listing-switches' to "-alh --group-directories-first".
;; The last option is GNU only.  The BSD ls of a stock macOS rejects it, and
;; then `dired-noselect' returns nil: Dired shows nothing.  A machine with GNU
;; coreutils first on PATH hides this.  Drop the option when the ls program
;; rejects it.  Emacs sorts directories first by itself when it uses `ls-lisp'.
;;; Code:

(defconst my/dired-gnu-only-switch "--group-directories-first"
  "The GNU only ls option that the Base puts in `dired-listing-switches'.")

(defun my/dired-usable-switches (switches)
  "Return SWITCHES without `my/dired-gnu-only-switch' if the ls program rejects it.
Return SWITCHES unchanged when it does not hold that option, when Emacs
emulates ls (`insert-directory-program' is nil), or when the program accepts it."
  (if (and insert-directory-program
           (string-search my/dired-gnu-only-switch switches)
           (not (eq 0 (let ((default-directory temporary-file-directory))
                        (ignore-errors
                          (call-process insert-directory-program nil nil nil
                                        my/dired-gnu-only-switch "-d" "."))))))
      (string-trim (string-replace my/dired-gnu-only-switch "" switches))
    switches))

;; The Local layer loads last, so this runs after the `:custom' of the Base.
(use-package dired
  :ensure nil
  :config
  (setq dired-listing-switches (my/dired-usable-switches dired-listing-switches)))

(provide 'init-local-dired)
;;; init-local-dired.el ends here
