;;; init-local-ghostel-tests.el --- Ghostel module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-ghostel-tests.el -f ert-run-tests-batch-and-exit
;; Ghostel is not loaded: the tests stub what the module calls.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar ghostel--input-mode nil)
(defvar ghostel-ignore-cursor-change nil)
(defvar ghostel-semi-char-mode-map)
(defvar ghostel-char-mode-map)
(defvar ghostel-shell)
(defvar init-local-ghostel-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")

(define-derived-mode ghostel-mode fundamental-mode "Ghostel"
  "Stand-in for the mode of Ghostel.")
(define-error 'ghostel-kitty-unsupported-source-rect "Unsupported source rect")

(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-ghostel-tests--keys)))

;; Load with deferral and without installs, so no Ghostel code runs.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil)
      (use-package-ensure-function #'ignore))
  (load (expand-file-name "../user-lisp/init-local-ghostel.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

;;;; Terminals

(ert-deftest init-local-ghostel-new-opens-a-fresh-numbered-terminal ()
  (let (args)
    (cl-letf (((symbol-function 'ghostel) (lambda (&rest a) (setq args a))))
      (my/ghostel-new))
    (should (equal '(((4))) (list args)))))

(ert-deftest init-local-ghostel-new-tab-opens-a-tab-first ()
  (let (steps)
    (cl-letf (((symbol-function 'tab-new) (lambda (&rest _) (push 'tab steps)))
              ((symbol-function 'ghostel) (lambda (&rest _) (push 'terminal steps))))
      (my/ghostel-new-tab))
    (should (equal '(tab terminal) (reverse steps)))))

;;;; Hel and the copy keys

(defun init-local-ghostel-tests--sync (mode)
  "Run `my/ghostel-sync-hel' in a Ghostel buffer with input MODE.
Return the list of Hel arguments and the state of the vi copy mode."
  (let (hel)
    (with-temp-buffer
      (ghostel-mode)
      (let ((ghostel--input-mode mode))
        (cl-letf (((symbol-function 'hel-local-mode) (lambda (arg) (push arg hel)))
                  ((symbol-function 'my/ghostel-cursor-sync) #'ignore))
          (my/ghostel-copy-vi-mode (if (eq mode 'emacs) 1 -1))
          (my/ghostel-sync-hel)))
      (list (reverse hel) (bound-and-true-p my/ghostel-copy-vi-mode)
            nobreak-char-display))))

(ert-deftest init-local-ghostel-hel-is-on-in-emacs-mode-only ()
  (should (equal '((1) nil nil) (init-local-ghostel-tests--sync 'emacs)))
  (should (equal '((-1) t nil) (init-local-ghostel-tests--sync 'copy)))
  (should (equal '((-1) nil nil) (init-local-ghostel-tests--sync 'semi-char)))
  (should (equal '((-1) nil nil) (init-local-ghostel-tests--sync 'char))))

(ert-deftest init-local-ghostel-sync-hel-ignores-other-buffers ()
  (let (hel)
    (with-temp-buffer
      (cl-letf (((symbol-function 'hel-local-mode) (lambda (arg) (push arg hel))))
        (my/ghostel-sync-hel)))
    (should-not hel)))

(ert-deftest init-local-ghostel-copy-vi-keys ()
  (dolist (pair '(("h" . backward-char) ("j" . next-line) ("k" . previous-line)
                  ("l" . forward-char) ("SPC" . set-mark-command)
                  ("q" . ghostel-readonly-exit) ("RET" . ghostel-readonly-copy)))
    (should (eq (cdr pair) (keymap-lookup my/ghostel-copy-vi-mode-map (car pair))))))

;;;; Upstream fixes

(ert-deftest init-local-ghostel-kitty-check-allows-scaling-and-rejects-a-crop ()
  (should-not (my/ghostel-kitty-check-source-rect 0 0 100 50 200 100))
  (should-error (my/ghostel-kitty-check-source-rect 5 0 100 50 100 50)
                :type 'ghostel-kitty-unsupported-source-rect)
  (should-error (my/ghostel-kitty-check-source-rect 0 7 100 50 100 50)
                :type 'ghostel-kitty-unsupported-source-rect))

(defun init-local-ghostel-tests--expire (age)
  "Return non-nil when a stamp AGE seconds old makes the refocus mark clear."
  (let (cleared)
    (cl-letf (((symbol-function 'window-frame) (lambda (_) 'frame))
              ((symbol-function 'posn-window) (lambda (_) 'window))
              ((symbol-function 'event-start) (lambda (_) 'start))
              ((symbol-function 'set-frame-parameter)
               (lambda (frame param value)
                 (when (and (eq frame 'frame) (eq param 'ghostel--frame-refocused)
                            (null value))
                   (setq cleared t)))))
      (let ((my/ghostel--focus-change-time (- (float-time) age)))
        (my/ghostel-expire-focus-flag 'event)))
    cleared))

(ert-deftest init-local-ghostel-focus-mark-is-kept-only-while-fresh ()
  (should-not (init-local-ghostel-tests--expire 0.1))
  (should (init-local-ghostel-tests--expire 2.0))
  ;; A stamp in the future (the clock moved back) is not fresh.
  (should (init-local-ghostel-tests--expire -5.0)))

(ert-deftest init-local-ghostel-focus-mark-clears-after-another-command ()
  (let (cleared)
    (cl-letf (((symbol-function 'frame-list) (lambda () '(f1 f2)))
              ((symbol-function 'frame-parameter) (lambda (_f _p) t))
              ((symbol-function 'set-frame-parameter)
               (lambda (f _p v) (when (null v) (push f cleared)))))
      (let ((this-command 'ghostel-mouse-press-or-copy-mode))
        (my/ghostel-drop-focus-flag))
      (should-not cleared)
      (let ((this-command 'next-line))
        (my/ghostel-drop-focus-flag))
      (should (equal '(f2 f1) cleared)))))

(ert-deftest init-local-ghostel-focus-change-is-stamped ()
  (let ((my/ghostel--focus-change-time 0.0))
    (my/ghostel-stamp-focus-change)
    (should (> my/ghostel--focus-change-time 1.0))))

;;;; Paste, keys, cursor

(defun init-local-ghostel-tests--paste (targets)
  "Run the smart paste with clipboard TARGETS; return `sent' or `yanked'."
  (let (result)
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'gui-get-selection) (lambda (&rest _) targets))
              ((symbol-function 'ghostel-send-key)
               (lambda (key mod) (setq result (list 'sent key mod))))
              ((symbol-function 'ghostel-yank) (lambda (&rest _) (setq result 'yanked))))
      (my/ghostel-smart-paste))
    result))

(ert-deftest init-local-ghostel-paste-sends-ctrl-v-for-an-image ()
  (should (equal '(sent "v" "ctrl") (init-local-ghostel-tests--paste '(TARGETS image/png STRING))))
  (should (eq 'yanked (init-local-ghostel-tests--paste '(TARGETS STRING UTF8_STRING))))
  (should (eq 'yanked (init-local-ghostel-tests--paste nil))))

(ert-deftest init-local-ghostel-terminal-keys-are-bound-in-both-maps ()
  (let ((ghostel-semi-char-mode-map (make-sparse-keymap))
        (ghostel-char-mode-map (make-sparse-keymap)))
    (my/ghostel-bind-terminal-keys)
    (should (eq 'ghostel-copy-mode (keymap-lookup ghostel-semi-char-mode-map "M-c")))
    (should (eq 'ghostel-emacs-mode (keymap-lookup ghostel-semi-char-mode-map "M-e")))
    (should (eq 'my/ghostel-split-new (keymap-lookup ghostel-semi-char-mode-map "M-t")))
    (dolist (map (list ghostel-semi-char-mode-map ghostel-char-mode-map))
      (should (eq 'my/ghostel-smart-paste (keymap-lookup map "C-v")))
      (should (eq 'my/ghostel-smart-paste (keymap-lookup map "s-v"))))))

(ert-deftest init-local-ghostel-cursor-is-a-steady-block-in-ghostel ()
  (let ((blink-cursor-mode t) calls)
    (cl-letf (((symbol-function 'blink-cursor-mode) (lambda (arg) (push arg calls)))
              ((symbol-function 'ghostel--cursor-blink-stop) #'ignore))
      (with-temp-buffer
        (ghostel-mode)
        (set-window-buffer (selected-window) (current-buffer))
        (my/ghostel-cursor-sync)
        (should (eq 'box cursor-type))
        (should ghostel-ignore-cursor-change)
        (should (equal '(-1) calls))))))

(ert-deftest init-local-ghostel-cursor-blinks-outside-ghostel ()
  (let ((blink-cursor-mode nil) calls)
    (cl-letf (((symbol-function 'blink-cursor-mode) (lambda (arg) (push arg calls))))
      (with-temp-buffer
        (set-window-buffer (selected-window) (current-buffer))
        (my/ghostel-cursor-sync)))
    (should (equal '(1) calls))))

(ert-deftest init-local-ghostel-speed-up-is-local-to-the-buffer ()
  (with-temp-buffer
    (ghostel-mode)
    (cl-letf (((symbol-function 'electric-pair-local-mode) #'ignore)
              ((symbol-function 'electric-indent-local-mode) #'ignore)
              ((symbol-function 'show-paren-local-mode) #'ignore))
      (my/ghostel-speed-up))
    (should (eq 'left-to-right bidi-paragraph-direction))
    (should (memq #'ghostel--adjust-size window-state-change-functions)))
  (should-not (memq #'ghostel--adjust-size (default-value 'window-state-change-functions))))

;;;; Windows shell and keys

(ert-deftest init-local-ghostel-bash-needs-bash-on-the-path ()
  (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil)))
    (should-error (my/ghostel-bash) :type 'user-error)))

(ert-deftest init-local-ghostel-bash-starts-a-login-shell ()
  (let (shell)
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "/x/bash"))
              ((symbol-function 'ghostel) (lambda (&rest _) (setq shell ghostel-shell))))
      (my/ghostel-bash))
    (should (equal '("/x/bash" "-l" "-i") shell))))

(ert-deftest init-local-ghostel-binds-the-terminal-leader-keys ()
  (should (equal '(("C-c g h" . ghostel)
                   ("C-c g n" . my/ghostel-new)
                   ("C-c g o" . ghostel-project)
                   ("C-c t g" . my/ghostel-new-tab))
                 (reverse init-local-ghostel-tests--keys))))

(provide 'init-local-ghostel-tests)
;;; init-local-ghostel-tests.el ends here
