;;; init-local-zoxide.el --- Jump to a directory with zoxide -*- lexical-binding: t -*-
;;; Commentary:
;; zoxide keeps a ranked list of the directories you visit.  SPC z t runs
;; `zoxide-travel': pick a directory in the minibuffer (fido) and open it.  The
;; earlier configuration also had z f and z d; this module does not.
;;
;; The package and the key exist only when the zoxide program is on the PATH.  With no
;; program, the module warns and does nothing.  The package loads on first use.
;;; Code:

(declare-function my/hel-leader-bind "init-local-hel")

(defun my/zoxide-setup ()
  "Bind SPC z t to `zoxide-travel' when the zoxide program exists.  Never signals."
  (if (not (executable-find "zoxide"))
      (display-warning 'init-local-zoxide "The zoxide program is not on the PATH; zoxide is off")
    (use-package zoxide
      :ensure t
      :commands zoxide-travel)
    (my/hel-leader-bind "C-c z t" #'zoxide-travel)))

(provide 'init-local-zoxide)
;;; init-local-zoxide.el ends here
