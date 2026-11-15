;;; init-local-tui.el --- Minimal setup for a terminal-only session -*- lexical-binding: t -*-
;;; Commentary:
;; `emacs -nw' runs next to Emacs.app.  The full Local layer would make it start a
;; second server and a second set of Anvil workers with the same names, which
;; breaks the first Emacs.  A terminal-only session therefore loads the Base, the
;; case guard, and Hel, and nothing else.  The Base already turns off lock files,
;; backups, and auto-save, and sets a plain, side-by-side ediff.
;;
;; `async-installer' is not loaded, so this module puts the existing Hel and
;; hel-leader clones on `load-path' itself.  When a clone is missing, Hel warns and
;; stays off.  Run the GUI Emacs once to install it.
;;; Code:

(defun my/tui-session-p ()
  "Return non-nil for an interactive, terminal-only start that is not a daemon."
  (and (not noninteractive)
       (not (daemonp))
       (not (display-graphic-p))))

(defun my/tui-setup ()
  "Add the Hel clones to `load-path' and start Hel."
  (dolist (name '("hel" "hel-leader"))
    (let ((dir (locate-user-emacs-file (concat "var/external-packages/" name))))
      (if (file-directory-p dir)
          (add-to-list 'load-path dir)
        (display-warning 'init-local-tui (format "%s is not installed, so Hel stays off" name)))))
  (require 'init-local-hel)
  (my/hel-setup))

(provide 'init-local-tui)
;;; init-local-tui.el ends here
