;;; checks.el --- Checks that run after the startup of test-startup.sh  -*- lexical-binding: t; -*-

;; test-startup.sh loads this file in the batch Emacs that has just started the
;; config.  Each check needs the real load order, so a unit test cannot do it.
;; A failed check signals an error.  This file is not an ERT file: it lives in a
;; subfolder, so the `tests/*.el' loop of the CI does not run it under `emacs -Q'.

;;; Code:

(declare-function hel-switch-state "hel")
(declare-function my/async-installer-install-missing "init-local-async-installer")
(declare-function my/async-installer-pin-at-target-p "init-local-async-installer")
(defvar async-installer-git-list)
(defvar async-installer-git-native-compile)
(defvar my/hel-leader-bindings)
(defvar hel-state)

;; The case guard must be on before any command runs.
(unless (advice-member-p 'my/case-guard 'upcase-region)
  (error "The case guard is not active"))

;; Trailing whitespace is trimmed per mode, never on every save: that rewrites
;; files we only open.
(when (memq 'delete-trailing-whitespace (default-value 'before-save-hook))
  (error "before-save-hook trims whitespace in every buffer"))
;; ...and only in programming buffers, by edited line.
(unless (memq 'ws-butler-mode prog-mode-hook)
  (error "ws-butler is not on prog-mode-hook"))
(when (memq 'ws-butler-mode text-mode-hook)
  (error "ws-butler is on text-mode-hook"))

;; The pinned Git packages must be present at their pinned targets.
;; async-installer clones them in the background, and batch Emacs would exit
;; before the clones finish, so wait here.  Otherwise a green run would prove
;; nothing about the pins.
(unless (fboundp 'my/async-installer-install-missing)
  (error "The Git pin installer is not loaded"))
(setq async-installer-git-native-compile nil)
(my/async-installer-install-missing t)
(unless (equal (sort (mapcar (lambda (pin) (file-name-base (plist-get pin :repo)))
                             async-installer-git-list)
                     #'string<)
               '("anvil.el" "emacs-herdr" "hel" "hel-leader" "org-gtd.el"))
  (error "The pin list is wrong: %S" async-installer-git-list))
(dolist (pin async-installer-git-list)
  (unless (my/async-installer-pin-at-target-p pin)
    (error "Git package %s is not at its pinned target" (plist-get pin :repo))))

;; org-gtd loads in batch Emacs, once its pin is in place, and the module turns it
;; on.  A leader key that only autoloads it would pass without this check.
(unless (and (featurep 'org-gtd) (bound-and-true-p org-gtd-mode))
  (error "org-gtd is not active after startup: %S"
         (bound-and-true-p my/gtd-unavailable-reason)))
(unless (advice-member-p 'my/gtd--organize-newest-first 'org-gtd-organize--call)
  (error "The org-gtd settings were not applied"))

;; The theme is Modus Operandi Tinted, and the Base theme no longer loads.  Batch
;; Emacs has no fonts, so this file cannot check them.
(unless (memq 'modus-operandi-tinted custom-enabled-themes)
  (error "modus-operandi-tinted is not enabled: %S" custom-enabled-themes))
(when (memq 'elegant-world custom-enabled-themes)
  (error "The Base theme elegant-world is still enabled"))

;; The fringe has no background of its own.  Modus draws it darker than the text, and
;; with the wide fringes of the Base that shows as a band between two windows.
;; Batch Emacs is a terminal, where `face-background' gives fallback colors, so read
;; the face spec of the theme.
(let ((bg (plist-get (cdar (cadr (assq 'modus-operandi-tinted (get 'fringe 'theme-face))))
                     :background)))
  (unless (or (eq bg 'unspecified) (equal bg (modus-themes-get-color-value 'bg-main)))
    (error "The theme draws the fringe in %S, not in the text background" bg)))

;; The music player of the Base is removed.  Its use-package form made the music
;; browser an autoload on C-c m at startup (the Dired key came only after the package
;; loaded, so a startup check cannot see it).
(when (fboundp 'simple-mpv-audio-browse)
  (error "The simple-mpv commands are still defined at startup"))
(when (eq (key-binding (kbd "C-c m")) 'simple-mpv-audio-browse)
  (error "C-c m still runs the simple-mpv music browser"))

;; marginalia starts with the first key press, and brings the icons with it.
(unless (bound-and-true-p marginalia-mode)
  (error "marginalia-mode is not on after the first input"))
(unless (bound-and-true-p nerd-icons-completion-mode)
  (error "nerd-icons-completion-mode is not on after the first input"))

;; F5 starts the debugger of the Base.  The theme toggle is on the leader: C-c T.
(unless (eq (key-binding (kbd "<f5>")) 'dape)
  (error "F5 runs %S, not dape" (key-binding (kbd "<f5>"))))

;; Hel runs after startup and the pins are in place.  Every leader key must run
;; a defined command, in both states that have the leader.  This catches a key
;; that still points at a removed or not yet ported command.
(unless (and (boundp 'my/hel-leader-bindings) my/hel-leader-bindings)
  (error "The Hel leader table is not loaded"))
(unless (and (featurep 'hel) (bound-and-true-p hel-mode))
  (error "Hel is not active after startup"))
(dolist (state '(normal emacs))
  (with-temp-buffer
    (text-mode)
    (hel-switch-state state)
    (dolist (binding my/hel-leader-bindings)
      (let ((key (car binding))
            (command (cdr binding)))
        (unless (fboundp command)
          (error "Leader key %s runs an undefined command %S" key command))
        (unless (eq (key-binding (kbd key)) command)
          (error "Leader key %s in %s state runs %S, not %S"
                 key state (key-binding (kbd key)) command))))))

;; B binds these keys globally.  Hel binds none of the first four in any state,
;; so B keeps them.  C-w is the Hel window map in normal and emacs state.  In
;; insert state, in a text buffer, Hel deletes a word backward.
(with-temp-buffer
  (text-mode)
  (dolist (state '(normal insert emacs))
    (hel-switch-state state)
    (dolist (pair '(("C-a" . back-to-indentation)
                    ("C-v" . yank)
                    ("C-z" . undo)
                    ("M-w" . my-copy)))
      (unless (eq (key-binding (kbd (car pair))) (cdr pair))
        (error "%s in %s state runs %S, not %S" (car pair) state
               (key-binding (kbd (car pair))) (cdr pair))))
    (let ((expected (if (eq state 'insert) 'hel-delete-backward-word 'hel-window-map)))
      (unless (eq (key-binding (kbd "C-w")) expected)
        (error "C-w in %s state runs %S, not %S" state
               (key-binding (kbd "C-w")) expected)))))

;; The one-key case commands of Hel stay off.  Without Hel binding, a key may
;; fall through to a global command, which is fine unless it changes case.
(with-temp-buffer
  (text-mode)
  (hel-switch-state 'normal)
  (dolist (key '("`" "M-`" "~" "g u" "g U"))
    (let ((command (key-binding (kbd key))))
      (when (and (symbolp command) command
                 (string-match-p "upcase\\|downcase\\|invert-case" (symbol-name command)))
        (error "Hel key %s still changes case: %S" key command)))))

;; Dired starts in normal state, so h j k l move.  dired-noselect returns nil
;; when the ls program rejects dired-listing-switches (the BSD ls of a stock
;; macOS rejects a GNU only option), so say that before anything else fails.
(require 'dired)
(let ((buf (dired-noselect temporary-file-directory)))
  (unless (bufferp buf)
    (error "dired-noselect returned %S: does %S accept the switches %S?"
           buf insert-directory-program dired-listing-switches))
  (unwind-protect
      (with-current-buffer buf
        (unless (and (eq hel-state 'normal)
                     (eq (key-binding (kbd "j")) 'hel-next-line))
          (error "Dired does not start in Hel normal state: %S %S"
                 hel-state (key-binding (kbd "j")))))
    (when (buffer-live-p buf) (kill-buffer buf))))

;; The Hel state shows in the mode line of B.
(with-temp-buffer
  (emacs-lisp-mode)
  (unless (member '(:eval (my/hel-mode-line-state)) mode-line-format)
    (error "The Hel state is not in the mode line")))

;; During the port, the server of this fork has its own name, because all
;; servers of one user share one socket folder, and the earlier configuration
;; owns the default name.  Anvil is off: loading anvil.el only defines things,
;; and the MCP tools wait for the anvil-enable command.
(unless (equal (bound-and-true-p my/server-name) "nn")
  (error "The server name is not nn: %S" (bound-and-true-p my/server-name)))
(when (bound-and-true-p my/anvil-enabled)
  (error "Anvil is on by default"))
(when (and (featurep 'anvil) (bound-and-true-p anvil--enabled))
  (error "Anvil is enabled after startup"))

;; JIT native compilation is on everywhere.  Windows is the exception: the
;; helper turns it off, with a warning, when no MINGW64 toolchain is found.
(princ (format "Native compilation: available=%S jit=%S\n"
               (and (fboundp 'native-comp-available-p) (native-comp-available-p))
               (and (boundp 'native-comp-jit-compilation) native-comp-jit-compilation)))
(when (and (fboundp 'native-comp-available-p)
           (native-comp-available-p)
           (not (eq system-type 'windows-nt)))
  (unless native-comp-jit-compilation
    (error "native-comp-jit-compilation is off")))

;; C-x C-u is one slip from C-x u (undo), and it upcases mark-to-point with no
;; prompt.
(with-temp-buffer
  (when (key-binding (kbd "C-x C-u"))
    (error "C-x C-u should be unbound, got %S" (key-binding (kbd "C-x C-u")))))

(when inhibit-message
  (error "inhibit-message is still set; warnings stay hidden"))

;; display-warning keeps its text in this buffer even when the echo area is
;; quiet.
(when-let* ((buf (get-buffer "*Warnings*")))
  (princ (format "Warnings during startup:\n%s\n"
                 (with-current-buffer buf (buffer-string)))))

;;; checks.el ends here
