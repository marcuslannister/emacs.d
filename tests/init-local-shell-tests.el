;;; init-local-shell-tests.el --- Shell cursor tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Load only the mode helpers, without starting shells or installing packages.
(with-temp-buffer
  (insert-file-contents
   (expand-file-name "../lisp/init-local-shell.el"
                     (file-name-directory load-file-name)))
  (dolist (name '(init-ghostel-cursor-sync ml/ghostel-sync-hel))
    (goto-char (point-min))
    (search-forward (format "(defun %s " name))
    (beginning-of-line)
    (eval (read (current-buffer)) t)))

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
