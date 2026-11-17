;;; init-local-tui.el --- Minimal setup for a terminal-only session -*- lexical-binding: t -*-
;;; Commentary:
;; `emacs -nw' runs next to Emacs.app.  The full Local layer would make it start a
;; second server and a second set of Anvil workers with the same names, which
;; breaks the first Emacs.  A terminal-only session therefore loads the Base, the
;; case guard, Hel, and the Modus theme, and nothing else.  The theme costs about
;; 13 ms and needs Hel first, because it binds a leader key.  The Base already
;; turns off lock files, backups, and auto-save, and sets a plain, side-by-side ediff.
;;
;; `async-installer' is not loaded, so this module puts the existing Hel and
;; hel-leader clones on `load-path' itself.  When a clone is missing, Hel warns and
;; stays off.  Run the GUI Emacs once to install it.
;;; Code:

(defvar xterm-extra-capabilities)

(defun my/tui-session-p ()
  "Return non-nil for an interactive, terminal-only start that is not a daemon."
  (and (not noninteractive)
       (not (daemonp))
       (not (display-graphic-p))))

(defun my/tui-setup ()
  "Add the Hel clones to `load-path', turn on OSC 52 copy, start Hel, and load the theme."
  ;; Emacs turns OSC 52 copy on only when the terminal reports it in its DA1 reply.
  ;; Kitty does; Herdr does not, but it passes the sequence on.  The terminal
  ;; initialization runs after the init file, so this takes effect.
  (setq xterm-extra-capabilities '(setSelection))
  (dolist (name '("hel" "hel-leader"))
    (let ((dir (locate-user-emacs-file (concat "var/external-packages/" name))))
      (if (file-directory-p dir)
          (add-to-list 'load-path dir)
        (display-warning 'init-local-tui (format "%s is not installed, so Hel stays off" name)))))
  (require 'init-local-hel)
  (my/hel-setup)
  (require 'init-local-themes))

(provide 'init-local-tui)
;;; init-local-tui.el ends here
