;;; init-local-commands.el --- Small commands for the Hel leader -*- lexical-binding: t -*-
;;; Commentary:
;; Buffer, ediff, and window commands that leader keys call.  The leader table
;; in init-local-hel.el registers them as autoloads, so this file loads on first
;; use.  The two window commands are written for this config: a side window
;; (a terminal or a chat pane) must not make them fail.
;;; Code:

(require 'seq)

(defun my/save-all-buffers ()
  "Save every modified file-visiting buffer without prompting."
  (interactive)
  (save-some-buffers t))

(defun my/copy-buffer-file-name ()
  "Copy the full file name of the current buffer to the kill ring."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer does not visit a file"))
  (kill-new buffer-file-name)
  (message "Copied: %s" buffer-file-name))

(defun my/insert-timestamp ()
  "Insert the current time as YYYYMMDDTHHMM."
  (interactive)
  (insert (format-time-string "%Y%m%dT%H%M")))

(defun my/ediff-current-with-other-window ()
  "Ediff the buffer of this window with the buffer of the next window."
  (interactive)
  (if (< (count-windows) 2)
      (user-error "Need at least two windows")
    (ediff-buffers (window-buffer)
                   (window-buffer (next-window (selected-window) 0)))))

(defun my/main-window ()
  "Return a window that is not a side window, or nil when there is none.
The selected window comes first when it qualifies."
  (let ((selected (selected-window)))
    (if (not (window-parameter selected 'window-side))
        selected
      (seq-find (lambda (window) (not (window-parameter window 'window-side)))
                (window-list nil 'no-minibuf)))))

(defun my/delete-other-windows ()
  "Make one main window the only main window, also from a side window.
Side windows that set `no-delete-other-windows' stay."
  (interactive)
  (when-let* ((main (my/main-window)))
    (select-window main)
    (delete-other-windows)))

(defun my/delete-window ()
  "Delete the selected window, and say so instead of failing when it cannot go.
This is the case for the last main window when only side windows remain."
  (interactive)
  (condition-case err
      (delete-window)
    (error (message "Cannot delete this window: %s" (error-message-string err)))))

(provide 'init-local-commands)
;;; init-local-commands.el ends here
