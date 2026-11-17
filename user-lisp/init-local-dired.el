;;; init-local-dired.el --- Dired listing sorted by date -*- lexical-binding: t -*-
;;; Commentary:
;; Sort files and directories by modification date, as in the Earlier
;; configuration: "-Ahlt --time-style=long-iso".  `--time-style' is GNU only.
;; The BSD ls of a stock macOS rejects it, and then `dired-noselect' returns
;; nil: Dired shows nothing.  Drop that option when the ls program rejects it.
;; Do not group directories first.  A newer file stays above an older directory.
;;; Code:

(defconst my/dired-date-switches "-Ahlt --time-style=long-iso"
  "Listing switches that sort files and directories by modification date.")

(defconst my/dired-gnu-only-switch "--time-style=long-iso"
  "The GNU only option in `my/dired-date-switches'.")

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

(defvar dired-subdir-alist)
(declare-function dired-current-directory "dired" (&optional localp))
(declare-function dired-goto-file "dired" (file))

(defun my/dired-goto-file-or-folder (file)
  "Go to FILE in this Dired buffer, or open the folder of FILE.
`dired-goto-file' finds only files that this buffer lists.  When this buffer
does not have the folder of FILE, open that folder in Dired and go to FILE.
Signal an error when FILE does not exist, or when this buffer does not show it."
  (interactive
   (prog1 (list (expand-file-name (read-file-name "Goto file: " (dired-current-directory))))
     (push-mark))
   dired-mode)
  (let ((file (directory-file-name file)))
    (cond ((dired-goto-file file))
          ((not (file-exists-p file)) (user-error "No such file: %s" file))
          ;; `dired-jump' would read the folder again and turn off `dired-omit-mode'.
          ((assoc (file-name-directory file) dired-subdir-alist)
           (user-error "This buffer does not show %s" (file-name-nondirectory file)))
          (t (dired-jump nil file)))))

;; The Local layer loads last, so this runs after the `:custom' of the Base.
(use-package dired
  :ensure nil
  :config
  ;; The Base sets `ls-lisp-dirs-first', which pins directories above files.
  (setq ls-lisp-dirs-first nil
        dired-listing-switches (my/dired-usable-switches my/dired-date-switches)))

(provide 'init-local-dired)
;;; init-local-dired.el ends here
