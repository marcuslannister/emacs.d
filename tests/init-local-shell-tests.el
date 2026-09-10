;;; init-local-shell-tests.el --- Shell cursor tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Load only the cursor function, without starting shells or installing packages.
(with-temp-buffer
  (insert-file-contents
   (expand-file-name "../lisp/init-local-shell.el"
                     (file-name-directory load-file-name)))
  (goto-char (point-min))
  (search-forward "(defun init-ghostel-cursor-sync ")
  (beginning-of-line)
  (eval (read (current-buffer)) t))

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
