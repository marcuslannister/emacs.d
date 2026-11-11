;;; init-local-ghostel.el --- Ghostel terminal: Hel, copy mode, Windows shell -*- lexical-binding: t -*-
;;; Commentary:
;; The Base sets up Ghostel (init-tools.el): the key, the project commands, and the
;; window below.  This module adds to it:
;; - Hel: off in the terminal input modes, so ESC and the leader key reach the
;;   terminal; on in Emacs mode; a vi-style copy mode.
;; - Fixes for two upstream behaviors (a Kitty graphics check that rejects every
;;   scaled image, and a focus click flag that drops a later click).
;; - Paste of an image from the clipboard, a steady block cursor, less editor work
;;   while the terminal redraws, and the shell on Windows (PowerShell 7, and Git
;;   Bash on demand).
;; Ghostel and its native module load on first use, not at startup.  The module is
;; downloaded on the first `M-x ghostel' (see docs/windows-setup.md for Windows).
;;; Code:

(require 'seq)

(defvar ghostel--input-mode)
(defvar ghostel-shell)
(defvar ghostel-semi-char-mode-map)
(defvar ghostel-char-mode-map)
(defvar ghostel-keymap-exceptions)
(defvar ghostel-ignore-cursor-change)
(declare-function ghostel "ghostel")
(declare-function ghostel-yank "ghostel")
(declare-function ghostel-send-key "ghostel")
(declare-function ghostel--adjust-size "ghostel")
(declare-function ghostel--cursor-blink-stop "ghostel")
(declare-function ghostel-readonly-end-of-line "ghostel")
(declare-function ghostel-readonly-end-of-buffer "ghostel")
(declare-function ghostel-readonly-copy "ghostel")
(declare-function ghostel-readonly-exit "ghostel")
(declare-function hel-local-mode "hel")
(declare-function my/hel-leader-bind "init-local-hel")

;;;; Terminals

(defun my/ghostel-new ()
  "Open a fresh, auto-numbered Ghostel terminal in the current window."
  (interactive)
  ;; A non-numeric prefix makes `ghostel' take the fresh path: *ghostel*,
  ;; *ghostel*<2>, and so on.
  (ghostel '(4)))

(defun my/ghostel-split-new ()
  "Split the window to the right and open a fresh Ghostel terminal there."
  (interactive)
  (select-window (split-window-right))
  (my/ghostel-new))

(defun my/ghostel-new-tab ()
  "Open a new tab with a fresh Ghostel terminal in it."
  (interactive)
  (tab-new)
  (my/ghostel-new))

;;;; Copy mode with vi keys

(defvar-keymap my/ghostel-copy-vi-mode-map
  :doc "Keymap for `my/ghostel-copy-vi-mode'."
  "h" #'backward-char
  "j" #'next-line
  "k" #'previous-line
  "l" #'forward-char
  "w" #'forward-word
  "b" #'backward-word
  "0" #'beginning-of-line
  "$" #'ghostel-readonly-end-of-line
  "g" #'beginning-of-buffer
  "G" #'ghostel-readonly-end-of-buffer
  "SPC" #'set-mark-command
  "RET" #'ghostel-readonly-copy
  "<return>" #'ghostel-readonly-copy
  "q" #'ghostel-readonly-exit
  "C-g" #'ghostel-readonly-exit)

(define-minor-mode my/ghostel-copy-vi-mode
  "Tmux-style vi navigation and selection for the copy mode of Ghostel.
Move with h j k l (w and b words, 0 and $ line, g and G buffer).  SPC starts a
selection, movement extends it, RET copies and exits, q or C-g cancels."
  :keymap my/ghostel-copy-vi-mode-map)

(defun my/ghostel-sync-hel (&rest _)
  "Match Hel and the vi copy keys to the input mode of Ghostel.
In the semi-char and char modes Hel would take ESC and the leader key from the
terminal, so it is off.  In Emacs mode the buffer is read-only and the leader key
is useful, so it is on.  In copy mode the vi keys replace Hel."
  (when (derived-mode-p 'ghostel-mode)
    ;; Do not underline the no-break spaces of the terminal.
    (setq-local nobreak-char-display nil)
    (pcase ghostel--input-mode
      ('emacs
       (my/ghostel-copy-vi-mode -1)
       (when (fboundp 'hel-local-mode) (hel-local-mode 1)))
      ('copy
       (when (fboundp 'hel-local-mode) (hel-local-mode -1))
       (my/ghostel-copy-vi-mode 1))
      (_
       (my/ghostel-copy-vi-mode -1)
       (when (fboundp 'hel-local-mode) (hel-local-mode -1))))
    ;; A mode change can replace the cursor without a window change.
    (my/ghostel-cursor-sync)))

;;;; Fixes for upstream behavior

(defun my/ghostel-kitty-check-source-rect (src-x src-y src-w src-h pixel-w pixel-h)
  "Signal `ghostel-kitty-unsupported-source-rect' only for a true atlas crop.
Upstream rejects a placement whenever the crop size differs from the rendered
size, and those differ on every ordinary scale-to-fit placement, so it floods
errors on a scaled preview.  A non-zero SRC-X or SRC-Y is the only crop signal
that needs no decoding of the image.  The arguments match
`ghostel--kitty-check-source-rect', which this replaces."
  (when (or (> src-x 0) (> src-y 0))
    (signal 'ghostel-kitty-unsupported-source-rect
            (list src-x src-y src-w src-h pixel-w pixel-h))))

;; Upstream marks a frame as refocused on every focus change and clears the mark on
;; the next left press in a Ghostel buffer, which it then eats as a focus click.
;; When focus returns without such a press (Cmd-Tab, a popup closing, a click in
;; another window), the mark stays, and a later click in Ghostel is dropped.  A real
;; focus click comes within milliseconds of the focus change, so honor the mark
;; only while it is fresh, and clear it after any other command.
(defvar my/ghostel--focus-change-time 0.0
  "`float-time' of the last frame focus change.")

(defun my/ghostel-stamp-focus-change (&rest _)
  "Record the time of a frame focus change."
  (setq my/ghostel--focus-change-time (float-time)))

(defun my/ghostel-expire-focus-flag (event &rest _)
  "Clear a stale refocus mark before Ghostel handles the press EVENT."
  (let ((age (- (float-time) my/ghostel--focus-change-time)))
    ;; A negative age means the clock moved back, so the stamp is not fresh.
    (when (or (< age 0) (> age 0.5))
      (set-frame-parameter (window-frame (posn-window (event-start event)))
                           'ghostel--frame-refocused nil))))

(defun my/ghostel-drop-focus-flag ()
  "Clear the refocus marks when a command other than the Ghostel press runs."
  (unless (memq this-command '(ghostel-mouse-press-or-copy-mode
                               handle-switch-frame handle-focus-in
                               handle-focus-out ignore))
    (dolist (frame (frame-list))
      (when (frame-parameter frame 'ghostel--frame-refocused)
        (set-frame-parameter frame 'ghostel--frame-refocused nil)))))

;;;; Keys and paste

(defun my/ghostel-smart-paste ()
  "Paste the clipboard text, or send Ctrl+V when the clipboard has an image.
An image wins when the clipboard offers both an image and text."
  (interactive)
  (if (and (display-graphic-p)
           (seq-some (lambda (type) (string-prefix-p "image/" (symbol-name type)))
                     (gui-get-selection 'CLIPBOARD 'TARGETS)))
      (ghostel-send-key "v" "ctrl")
    (ghostel-yank)))

(defun my/ghostel-bind-terminal-keys (&rest _)
  "Bind the Ghostel keys again; they are lost when the semi-char map is rebuilt.
Ghostel makes `ghostel-semi-char-mode-map' again from `ghostel-keymap-exceptions',
which drops the keys that `use-package' bound."
  (pcase-dolist (`(,key . ,cmd) '(("M-c" . ghostel-copy-mode)
                                  ("M-e" . ghostel-emacs-mode)
                                  ("M-t" . my/ghostel-split-new)))
    (define-key ghostel-semi-char-mode-map (kbd key) cmd))
  (dolist (map (list ghostel-semi-char-mode-map ghostel-char-mode-map))
    ;; Karabiner maps the physical Ctrl+V to Cmd+V on macOS.
    (dolist (key '("C-v" "s-v"))
      (define-key map (kbd key) #'my/ghostel-smart-paste))))

;;;; Look and speed

(defun my/ghostel-speed-up ()
  "Drop the editor work that fights the redraw of Ghostel in this buffer."
  (setq-local scroll-conservatively most-positive-fixnum
              bidi-paragraph-direction 'left-to-right
              bidi-inhibit-bpa t)
  (electric-pair-local-mode -1)
  (electric-indent-local-mode -1)
  (show-paren-local-mode -1)
  (when (fboundp 'corfu-mode) (corfu-mode -1))
  (add-hook 'window-state-change-functions #'ghostel--adjust-size nil t))

(defun my/ghostel-cursor-sync (&rest _)
  "Use a steady block cursor in Ghostel, and the blinking cursor elsewhere.
Both blink timers stop in Ghostel, so the block that a program such as Claude Code
paints does not flicker through."
  (with-current-buffer (window-buffer (selected-window))
    (if (derived-mode-p 'ghostel-mode)
        (progn
          (setq-local ghostel-ignore-cursor-change t)
          (when (fboundp 'ghostel--cursor-blink-stop)
            (ghostel--cursor-blink-stop))
          (setq-local cursor-type 'box)
          (when blink-cursor-mode (blink-cursor-mode -1)))
      (unless blink-cursor-mode (blink-cursor-mode 1)))))

;;;; Windows shell

(defconst my/ghostel-pwsh "C:/Program Files/PowerShell/7/pwsh.exe"
  "PowerShell 7 on Windows.")

(defun my/ghostel-bash ()
  "Open a Ghostel terminal that runs Git Bash (bash.exe from `exec-path')."
  (interactive)
  (if-let* ((bash (executable-find "bash")))
      (let ((ghostel-shell (list bash "-l" "-i")))
        (ghostel))
    (user-error "No bash on the PATH; add the usr/bin folder of Git Bash")))

;;;; Setup

(use-package ghostel
  :init
  ;; PowerShell 7 is a native Windows program, so it reports C:\ paths (no MSYS
  ;; /c/... paths), which Claude Code and the native git and rg expect.  The default,
  ;; cmd.exe, is worse.  It has no OSC-133 shell integration, a fair price.
  (when (and (eq system-type 'windows-nt) (file-exists-p my/ghostel-pwsh))
    (setq ghostel-shell (list my/ghostel-pwsh "-NoLogo")))
  :hook ((ghostel-mode . my/ghostel-sync-hel)
         (ghostel-mode . my/ghostel-speed-up))
  :custom
  (ghostel-timer-delay 0.01)
  (ghostel-max-scrollback (* 1024 1024))
  :config
  (dolist (fn '(ghostel-semi-char-mode ghostel-char-mode ghostel-emacs-mode
                ghostel-copy-mode ghostel-readonly-exit))
    (advice-add fn :after #'my/ghostel-sync-hel))
  (my/ghostel-bind-terminal-keys)
  (advice-add 'ghostel--rebuild-semi-char-keymap :after #'my/ghostel-bind-terminal-keys)
  (when (fboundp 'ghostel--kitty-check-source-rect)
    (advice-add 'ghostel--kitty-check-source-rect
                :override #'my/ghostel-kitty-check-source-rect))
  (add-function :after after-focus-change-function #'my/ghostel-stamp-focus-change)
  (add-hook 'pre-command-hook #'my/ghostel-drop-focus-flag)
  (advice-add 'ghostel-mouse-press-or-copy-mode :before #'my/ghostel-expire-focus-flag)
  ;; Shell integration for zsh (prompt marks, directory tracking).
  (when-let* (((not (eq system-type 'windows-nt)))
              (lib (locate-library "ghostel"))
              (script (expand-file-name "etc/shell/ghostel.zsh" (file-name-directory lib)))
              ((file-readable-p script)))
    (setenv "GHOSTEL_SH_INTEGRATION" script)))

(add-hook 'window-selection-change-functions #'my/ghostel-cursor-sync)
(add-hook 'window-buffer-change-functions #'my/ghostel-cursor-sync)

;; `shell-mode' gets the VT parser of Ghostel instead of the regexps of comint.  It
;; is on for `shell-mode' only: the global mode would reach every comint buffer,
;; including the REPLs, where font-lock matters and ANSI colors are rare.  The
;; native module is downloaded on demand, so a fresh install has the Lisp and no
;; module; the check on the entry point stops a void-function in the output filter.
(defun my/shell-enable-ghostel-comint ()
  "Turn on `ghostel-comint-mode' when ghostel-comint and its native module load."
  (when (and (require 'ghostel-comint nil t)
             (fboundp 'ghostel--comint-make-state))
    (ghostel-comint-mode 1)))
(add-hook 'shell-mode-hook #'my/shell-enable-ghostel-comint)

;; `claude' started from an Emacs terminal inherits the environment of Emacs, which
;; never ran scm_breeze.  The shell snapshot of Claude Code then replays the git
;; wrapper of scm_breeze without this variable, and every git call fails with
;; "permission denied" on an empty command.  Give the child a real path.
(unless (eq system-type 'windows-nt)
  (setenv "_git_cmd" (or (executable-find "git") "/usr/bin/git")))

(my/hel-leader-bind
 "C-c g h" #'ghostel
 "C-c g n" #'my/ghostel-new
 "C-c g o" #'ghostel-project
 "C-c t g" #'my/ghostel-new-tab)

(provide 'init-local-ghostel)
;;; init-local-ghostel.el ends here
