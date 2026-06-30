;;; frame-state.el --- Persist and validate frame geometry -*- lexical-binding: t; -*-

;;; Commentary:

;; Saves the last GUI frame's size/position and restores it on the next
;; start.  Loaded by `early-init.el' before the initial frame exists, so it
;; must stay dependency-free (built-ins only).
;;
;; The persisted file is untrusted disposable cache, not configuration: a
;; minimized Windows frame reports coordinates near -32000, and geometry
;; saved on one monitor layout can be off-screen on another.  Every value is
;; validated by `my/frame-state-sanitize' before it can reach
;; `initial-frame-alist', so a bad cache can never produce an invisible or
;; unusable first frame.  A rejected cache self-heals on the next good save.

;;; Code:

(defvar my/frame-state-file
  (expand-file-name "frame-state.el" user-emacs-directory)
  "File where the last frame geometry is persisted.")

(defun my/frame-state--valid-coord-p (v)
  "Non-nil if V is a sane on-screen frame coordinate.
Rejects the Windows minimize sentinel (~-32000) and absurd values.
Edge-relative forms like (+ N)/(- N) are intentionally not accepted; the
window manager places the frame instead."
  (and (integerp v) (< -31000 v 31000)))

(defun my/frame-state--valid-size-p (v)
  "Non-nil if V is a sane frame dimension in columns or rows."
  (and (integerp v) (< 0 v 10000)))

(defun my/frame-state--valid-fullscreen-p (v)
  "Non-nil if V is an accepted `fullscreen' frame parameter."
  (memq v '(nil fullboth fullheight fullwidth maximized)))

(defun my/frame-state-sanitize (state)
  "Return a sanitized copy of STATE, dropping every invalid field.
STATE is an alist as written by `my/save-frame-state'.  Position is
treated as a pair: if either `left' or `top' is invalid both are dropped
so the window manager can place the frame.  Other fields are validated
independently.  Return nil when STATE is not a well-formed alist."
  (condition-case nil
      (when (listp state)
        (let ((left   (cdr (assq 'left state)))
              (top    (cdr (assq 'top state)))
              (width  (cdr (assq 'width state)))
              (height (cdr (assq 'height state)))
              (fs     (assq 'fullscreen state))
              (clean '()))
          (when (and (my/frame-state--valid-coord-p left)
                     (my/frame-state--valid-coord-p top))
            (push (cons 'left left) clean)
            (push (cons 'top top) clean))
          (when (my/frame-state--valid-size-p width)
            (push (cons 'width width) clean))
          (when (my/frame-state--valid-size-p height)
            (push (cons 'height height) clean))
          (when (and fs (my/frame-state--valid-fullscreen-p (cdr fs)))
            (push (cons 'fullscreen (cdr fs)) clean))
          (nreverse clean)))
    (error nil)))

(defun my/save-frame-state ()
  "Persist current frame geometry to `my/frame-state-file'."
  (when (display-graphic-p)
    (let* ((frame (selected-frame))
           (left (frame-parameter frame 'left))
           (top  (frame-parameter frame 'top)))
      ;; Skip save when frame is minimized (Windows reports -32000).
      (unless (and (integerp left) (integerp top)
                   (or (< left -31000) (< top -31000)))
        (with-temp-file my/frame-state-file
          (prin1 (list (cons 'left       left)
                       (cons 'top        top)
                       (cons 'width      (frame-parameter frame 'width))
                       (cons 'height     (frame-parameter frame 'height))
                       (cons 'fullscreen (frame-parameter frame 'fullscreen)))
                 (current-buffer)))))))

(defun my/load-frame-state ()
  "Apply sanitized saved geometry to `initial-frame-alist'.
The on-disk state is untrusted cache and is validated by
`my/frame-state-sanitize' before any value reaches the frame."
  (when (file-exists-p my/frame-state-file)
    (condition-case nil
        (let ((state (my/frame-state-sanitize
                      (with-temp-buffer
                        (insert-file-contents my/frame-state-file)
                        (read (current-buffer))))))
          (dolist (param state)
            (when (cdr param)
              (let ((cell (assq (car param) initial-frame-alist)))
                (if cell
                    (setcdr cell (cdr param))
                  (push param initial-frame-alist))))))
      (error nil))))

(provide 'frame-state)
;;; frame-state.el ends here
