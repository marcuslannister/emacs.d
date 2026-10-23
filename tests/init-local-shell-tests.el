;;; init-local-shell-tests.el --- Shell cursor tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Load only the mode helpers, without starting shells or installing packages.
(with-temp-buffer
  (insert-file-contents
   (expand-file-name "../lisp/init-local-shell.el"
                     (file-name-directory load-file-name)))
  (dolist (name '(init-ghostel-cursor-sync init-ghostel-speed-up
                  ml/ghostel-sync-hel ml/shell-enable-ghostel-comint
                  ml/ghostel-smart-paste ml/ghostel-bind-terminal-keys))
    (goto-char (point-min))
    (search-forward (format "(defun %s " name))
    (beginning-of-line)
    (eval (read (current-buffer)) t)))

(ert-deftest init-ghostel-smart-paste-selects-clipboard-format ()
  "Send Alt+V for images; keep normal Ghostel text paste otherwise."
  (pcase-dolist (`(,targets ,image)
                 '(([UTF8_STRING] nil)
                   ([image/png] t)
                   ([image/tiff] t)
                   ([UTF8_STRING image/png] t)
                   (nil nil)))
    (let (sent yanked)
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'gui-get-selection)
                 (lambda (selection target)
                   (should (eq selection 'CLIPBOARD))
                   (should (eq target 'TARGETS))
                   targets))
                ((symbol-function 'ghostel-send-key)
                 (lambda (&rest args) (setq sent args)))
                ((symbol-function 'ghostel-yank) (lambda () (setq yanked t))))
        (ml/ghostel-smart-paste)
        (should (equal sent (and image '("v" "alt"))))
        (should (eq yanked (not image)))))))

(ert-deftest init-ghostel-smart-paste-in-tty ()
  "TTY Emacs keeps text paste without querying an unavailable GUI clipboard."
  (let (yanked)
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) nil))
              ((symbol-function 'gui-get-selection)
               (lambda (&rest _) (ert-fail "Unexpected GUI clipboard query")))
              ((symbol-function 'ghostel-yank) (lambda () (setq yanked t))))
      (ml/ghostel-smart-paste)
      (should yanked))))

(defvar ghostel-semi-char-mode-map)
(defvar ghostel-char-mode-map)

(ert-deftest init-ghostel-smart-paste-bindings ()
  "Terminal-input maps bind paste and semi-char Emacs keys without changing global keys."
  (let ((ghostel-semi-char-mode-map (make-sparse-keymap))
        (ghostel-char-mode-map (make-sparse-keymap))
        (global-paste (lookup-key (current-global-map) (kbd "s-v"))))
    (dotimes (_ 2)
      (ml/ghostel-bind-terminal-keys)
      (dolist (map (list ghostel-semi-char-mode-map ghostel-char-mode-map))
        (dolist (key '("C-v" "s-v"))
          (should (eq (lookup-key map (kbd key)) #'ml/ghostel-smart-paste))))
      (should (eq (lookup-key ghostel-semi-char-mode-map (kbd "M-c"))
                  #'ghostel-copy-mode)))
    (should (eq (lookup-key (current-global-map) (kbd "s-v")) global-paste))))

(ert-deftest init-ghostel-steady-cursor-and-focus ()
  "Ordinary and IDE terminals use a steady block; other buffers keep blinking."
  (let ((blink-cursor-mode t)
        (stops 0))
    (cl-letf (((symbol-function 'ghostel--cursor-blink-stop)
               (lambda () (setq stops (1+ stops))))
              ((symbol-function 'blink-cursor-mode)
               (lambda (arg) (setq blink-cursor-mode (> arg 0)))))
      (save-window-excursion
        (dolist (name '("*ghostel-test*" "*claude-code-test*"))
          (with-temp-buffer
            (rename-buffer name t)
            (setq major-mode 'ghostel-mode)
            (setq-local cursor-type '(hbar . 2))
            (set-window-buffer (selected-window) (current-buffer))
            (init-ghostel-cursor-sync)
            (should (eq cursor-type 'box))
            (should (buffer-local-value 'ghostel-ignore-cursor-change (current-buffer)))
            (should-not blink-cursor-mode)))
        (should (= stops 2))
        (with-temp-buffer
          (setq-local cursor-type 'bar)
          (set-window-buffer (selected-window) (current-buffer))
          (init-ghostel-cursor-sync)
          (should blink-cursor-mode)
          (should (eq cursor-type 'bar)))))))

(ert-deftest init-ghostel-no-nobreak-space-highlight ()
  "Terminal nonbreaking spaces must not acquire an editor-drawn underline."
  (let ((blink-cursor-mode nil)
        (default-display (default-value 'nobreak-char-display)))
    (cl-letf (((symbol-function 'hel-local-mode) #'ignore)
              ((symbol-function 'ml/ghostel-copy-vi-mode) #'ignore)
              ((symbol-function 'ghostel--cursor-blink-stop) #'ignore))
      (save-window-excursion
        (with-temp-buffer
          (setq-local nobreak-char-display t)
          (with-temp-buffer
            (setq major-mode 'ghostel-mode)
            (setq-local ghostel--input-mode 'semi-char)
            (setq-local nobreak-char-display t)
            (insert ">\u00a0 ")
            (set-window-buffer (selected-window) (current-buffer))
            (ml/ghostel-sync-hel)
            (should-not nobreak-char-display)
            (should (eq cursor-type 'box))
            (should-not blink-cursor-mode))
          (should nobreak-char-display)))
      (should (eq (default-value 'nobreak-char-display) default-display)))))

(ert-deftest init-ghostel-steady-cursor-after-editing-mode-change ()
  "Mode synchronization must restore the block after Hel changes its shape."
  (let ((blink-cursor-mode nil))
    (cl-letf (((symbol-function 'hel-local-mode)
               (lambda (_) (setq-local cursor-type '(hbar . 4))))
              ((symbol-function 'ml/ghostel-copy-vi-mode) #'ignore)
              ((symbol-function 'ghostel--cursor-blink-stop) #'ignore))
      (save-window-excursion
        (with-temp-buffer
          (setq major-mode 'ghostel-mode)
          (set-window-buffer (selected-window) (current-buffer))
          (dolist (mode '(emacs copy semi-char char))
            (setq-local ghostel--input-mode mode)
            (ml/ghostel-sync-hel)
            (should (eq cursor-type 'box))
            (should-not blink-cursor-mode)))))))

(ert-deftest init-ghostel-speed-up-skips-bidi ()
  "Ghostel buffers skip bidi scanning."
  (with-temp-buffer
    (setq major-mode 'ghostel-mode)
    (setq-local scroll-conservatively 101)
    (init-ghostel-speed-up)
    (should (eq bidi-paragraph-direction 'left-to-right))
    (should bidi-inhibit-bpa)
    (should (eq scroll-conservatively most-positive-fixnum))))

(ert-deftest init-shell-ghostel-comint-needs-lisp-and-native-module ()
  "Enable the VT filter only when both the Lisp and the native module load.
Lisp present with no module is the regression: it breaks shell output."
  (pcase-dolist (`(,lisp ,module ,expected)
                 '((nil nil nil) (t nil nil) (t t t)))
    (let (enabled)
      (cl-letf (((symbol-function 'require) (lambda (&rest _) lisp))
                ((symbol-function 'ghostel--comint-make-state)
                 (and module #'ignore))
                ((symbol-function 'ghostel-comint-mode)
                 (lambda (arg) (setq enabled (> arg 0)))))
        (ml/shell-enable-ghostel-comint))
      (should (eq enabled expected)))))
