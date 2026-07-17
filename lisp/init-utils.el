;;; init-utils.el --- Elisp helper functions and commands -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defun sanityinc/display-buffer-full-frame (buffer alist)
  "If it's not visible, display buffer full-frame, saving the prior window config.
The saved config will be restored when the window is quit later.
BUFFER and ALIST are as for `display-buffer-full-frame'."
  (let ((initial-window-configuration (current-window-configuration)))
    (or (display-buffer-reuse-window buffer alist)
        (let ((full-window (display-buffer-full-frame buffer alist)))
          (prog1
              full-window
            (set-window-parameter full-window 'sanityinc/previous-config initial-window-configuration))))))

(defun sanityinc/maybe-restore-window-configuration (orig &optional kill window)
  (let* ((window  (or window (selected-window)))
         (to-restore (window-parameter window 'sanityinc/previous-config)))
    (set-window-parameter window 'sanityinc/previous-config nil)
    (funcall orig kill window)
    (when to-restore
      (set-window-configuration to-restore))))

(advice-add 'quit-window :around 'sanityinc/maybe-restore-window-configuration)

(defmacro sanityinc/fullframe-mode (mode)
  "Configure buffers that open in MODE to display in full-frame."
  `(add-to-list 'display-buffer-alist
                (cons (cons 'major-mode ,mode)
                      (list 'sanityinc/display-buffer-full-frame))))

(sanityinc/fullframe-mode 'package-menu-mode)


;; Side-window-tolerant variants of the window-deletion commands.  These
;; live here (loaded on both GUI and TUI startup paths) so the Hel
;; bindings in `init-local-hel' resolve in terminal sessions too.

(defun sanityinc/select-main-window ()
  "Ensure the selected window is a main (non-side) window.
If point is in a side window, switch to the most recent main
window.  Return non-nil when the selected window is a main window."
  (when (window-parameter (selected-window) 'window-side)
    (when-let ((main (seq-find (lambda (w)
                                 (not (window-parameter w 'window-side)))
                               (window-list nil 'no-minibuf))))
      (select-window main)))
  (not (window-parameter (selected-window) 'window-side)))

(defun sanityinc/delete-other-windows ()
  "Like `delete-other-windows', but tolerant of side windows.
When invoked from inside a side window (e.g. the claude-code
pane), act from a main window instead of erroring; side windows
that opt out via `no-delete-other-windows' are left intact."
  (interactive)
  (when (sanityinc/select-main-window)
    (delete-other-windows)))

(defun sanityinc/delete-window ()
  "Like `delete-window', but a no-op on the last main window.
Avoids the \"Attempt to delete main window of frame\" error when a
side window is the only other window on the frame."
  (interactive)
  (condition-case nil
      (delete-window)
    (error (message "Cannot delete the last main window"))))


;; Handier way to add modes to auto-mode-alist
(defun add-auto-mode (mode &rest patterns)
  "Add entries to `auto-mode-alist' to use `MODE' for all given file `PATTERNS'."
  (dolist (pattern patterns)
    (add-to-list 'auto-mode-alist (cons pattern mode))))

(defun sanityinc/remove-auto-mode (mode)
  "Remove entries from `auto-mode-alist' that are for `MODE'."
  (setq auto-mode-alist (seq-remove (lambda (x) (eq mode (cdr x))) auto-mode-alist)))

;; Like diminish, but for major modes
(defun sanityinc/set-major-mode-name (name)
  "Override the major mode NAME in this buffer."
  (setq-local mode-name name))

(defun sanityinc/major-mode-lighter (mode name)
  (add-hook (derived-mode-hook-name mode)
            (apply-partially 'sanityinc/set-major-mode-name name)))


;; String utilities missing from core emacs

(defun sanityinc/string-all-matches (regex str &optional group)
  "Find all matches for `REGEX' within `STR', returning the full match string or group `GROUP'."
  (let ((result nil)
        (pos 0)
        (group (or group 0)))
    (while (string-match regex str pos)
      (push (match-string group str) result)
      (setq pos (match-end group)))
    result))



;; Delete the current file

(defun delete-this-file ()
  "Delete the current file, and kill the buffer."
  (interactive)
  (unless (buffer-file-name)
    (error "No file is currently being edited"))
  (when (yes-or-no-p (format "Really delete '%s'?"
                             (file-name-nondirectory buffer-file-name)))
    (delete-file (buffer-file-name))
    (kill-this-buffer)))



;; Rename the current file

(if (fboundp 'rename-visited-file)
    (defalias 'rename-this-file-and-buffer 'rename-visited-file)
  (defun rename-this-file-and-buffer (new-name)
    "Renames both current buffer and file it's visiting to NEW-NAME."
    (interactive "sNew name: ")
    (let ((name (buffer-name))
          (filename (buffer-file-name)))
      (unless filename
        (error "Buffer '%s' is not visiting a file!" name))
      (progn
        (when (file-exists-p filename)
          (rename-file filename new-name 1))
        (set-visited-file-name new-name)
        (rename-buffer new-name)))))


;; Browse current HTML file

(defun browse-current-file ()
  "Open the current file as a URL using `browse-url'."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if (and (fboundp 'tramp-tramp-file-p)
             (tramp-tramp-file-p file-name))
        (error "Cannot open tramp file")
      (browse-url (concat "file://" file-name)))))


(provide 'init-utils)
;;; init-utils.el ends here
