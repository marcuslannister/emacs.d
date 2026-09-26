;;; scan.el --- Report upcase damage in ~/org -*- lexical-binding: t -*-
;;; Commentary:
;; Used by the org-case-check skill.  The patterns, the count, and the file test
;; all come from `init-local-case-guard', so this file adds only the output.
;;; Code:

(require 'subr-x)
(require 'init-local-case-guard)

(defun org-case-check--report (name)
  "Return the damage report for the current buffer under NAME, or nil if clean."
  (let ((count (ml-case-guard-canary-count)))
    (when (> count 0)
      (save-excursion
        (save-restriction
          (widen)
          (let ((case-fold-search nil)
                lines)
            (dolist (pattern ml-case-guard-canary-patterns)
              (goto-char (point-min))
              (while (re-search-forward pattern nil t)
                (push (cons (line-number-at-pos)
                            (buffer-substring (line-beginning-position)
                                              (line-end-position)))
                      lines)))
            (format "%s: %d matches, threshold %d\n%s\n"
                    name count ml-case-guard-canary-threshold
                    (mapconcat (lambda (l) (format "  %d: %s" (car l) (cdr l)))
                               (sort lines (lambda (a b) (< (car a) (car b))))
                               "\n"))))))))

(defun org-case-check-files ()
  "Print the damage report for every org file on disk under `ml-case-guard-directories'."
  (dolist (dir ml-case-guard-directories)
    (dolist (f (directory-files-recursively dir "\\.org\\'"))
      (unless (string-match-p "/\\.stversions/\\|sync-conflict" f)
        (with-temp-buffer
          (insert-file-contents f)
          (princ (or (org-case-check--report (abbreviate-file-name f)) "")))))))

(defun org-case-check-buffers ()
  "Return the damage report for every live buffer that visits a guarded file.
Indirect buffers are skipped, because they share the text of their base buffer."
  (string-join
   (delq nil (mapcar (lambda (b)
                       (with-current-buffer b
                         (and (not (buffer-base-buffer))
                              (ml-case-guard--file)
                              (org-case-check--report (buffer-name)))))
                     (buffer-list)))))

(provide 'org-case-check)
;;; scan.el ends here
