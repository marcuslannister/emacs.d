;;; init-local-vulpea-integration-tests.el --- Real Task Table test -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(cl-letf (((symbol-function 'maybe-require-package)
           (lambda (&rest _args) nil)))
  (load-file
   (expand-file-name "../lisp/init-local-vulpea.el"
                     (file-name-directory load-file-name))))

(defun init-local-vulpea-integration-available-p ()
  "Return non-nil when real Task Table dependencies are locally available."
  (and (not (version< emacs-version "29.1"))
       (locate-library "vulpea")
       (locate-library "vulpea-ui")))

(defun init-local-vulpea-integration-entry-ids ()
  "Return current Collection View row IDs in display order."
  (mapcar #'car tabulated-list-entries))

(defun init-local-vulpea-integration-entry (id)
  "Return current Collection View entry identified by ID."
  (assoc id tabulated-list-entries))

(ert-deftest init-local-vulpea-public-indexing-opens-read-only-task-table ()
  (unless (init-local-vulpea-integration-available-p)
    (ert-skip "Vulpea or Vulpea UI is unavailable; no packages are installed by tests"))
  (condition-case err
      (progn
        (require 'vulpea)
        (require 'vulpea-ui))
    (error
     (ert-skip
      (format "Vulpea dependencies cannot load: %s"
              (error-message-string err)))))
  (let* ((temporary-directory (make-temp-file "vulpea-task-table" t))
         (org-file (expand-file-name "tasks.org" temporary-directory))
         (database (expand-file-name "vulpea.db" temporary-directory))
         (org-id-locations-file
          (expand-file-name "org-id-locations" temporary-directory))
         (old-workflow (default-value 'org-todo-keywords))
         (collection-buffer nil)
         source-before)
    (unwind-protect
        (progn
          (set-default
           'org-todo-keywords
           '((sequence "TODO(t)" "NEXT(n)" "WAITING(w@/!)" "HOLD(h)"
                       "|" "DONE(d!/!)" "CANCELLED(c@/!)")))
          (with-temp-file org-file
            (insert
             "#+title: Project Alpha\n"
             "* Parent\n"
             "** TODO [#A] Zeta\n"
             ":PROPERTIES:\n:ID: priority-a\n:END:\n"
             "** TODO alpha\n"
             ":PROPERTIES:\n:ID: missing-b\n:END:\n"
             "** TODO [#B] Alpha\n"
             ":PROPERTIES:\n:ID: explicit-b\n:END:\n"
             "** NEXT [#A] 重复\n"
             ":PROPERTIES:\n:ID: unicode\n:END:\n"
             "** DONE [#A] Finished\n"
             ":PROPERTIES:\n:ID: done\n:END:\n"
             "** CANCELLED [#A] Dropped\n"
             ":PROPERTIES:\n:ID: cancelled\n:END:\n"
             "** TODO [#A] No stable ID\n"))
          (setq source-before
                (with-temp-buffer
                  (insert-file-contents org-file)
                  (buffer-string)))
          (vulpea-db-close)
          (let ((vulpea-db-location database)
                (vulpea-db-index-heading-level t)
                (vulpea-db-sync-directories
                 (list (file-name-as-directory temporary-directory)))
                (init-local-vulpea-task-table-unavailable-reason nil))
            (vulpea-db-update-file org-file)
            (my/vulpea-task-table)
            (setq collection-buffer (current-buffer))
            (should (derived-mode-p 'vulpea-ui-collection-mode))
            (should init-local-vulpea-task-table-read-only-mode)
            (should
             (equal '("explicit-b" "missing-b" "priority-a" "unicode")
                    (sort (init-local-vulpea-integration-entry-ids)
                          #'string-lessp)))
            (let* ((missing
                    (init-local-vulpea-integration-entry "missing-b"))
                   (cells (cadr missing))
                   (priority-cell (aref cells 2))
                   (task-cell (aref cells 3))
                   (source-cell (aref cells 4)))
              (should (equal "B" (substring-no-properties priority-cell)))
              (should (equal "" (get-text-property 0 'display priority-cell)))
              (should (equal "alpha" task-cell))
              (should (equal "Project Alpha > Parent" source-cell)))
            (setq tabulated-list-sort-key '("Priority" . nil))
            (tabulated-list-print t)
            (let ((ids (init-local-vulpea-integration-entry-ids)))
              (should
               (equal '("priority-a" "unicode")
                      (sort (seq-take ids 2) #'string-lessp)))
              (should
               (equal '("explicit-b" "missing-b")
                      (sort (seq-drop ids 2) #'string-lessp))))
            (setq tabulated-list-sort-key '("Priority" . t))
            (tabulated-list-print t)
            (let ((ids (init-local-vulpea-integration-entry-ids)))
              (should
               (equal '("explicit-b" "missing-b")
                      (sort (seq-take ids 2) #'string-lessp)))
              (should
               (equal '("priority-a" "unicode")
                      (sort (seq-drop ids 2) #'string-lessp))))
            (init-local-vulpea-task-table-filter-todo "TODO")
            (should
             (equal '("explicit-b" "missing-b" "priority-a")
                    (sort (init-local-vulpea-integration-entry-ids)
                          #'string-lessp)))
            (init-local-vulpea-task-table-filter-priority "None")
            (should
             (equal '("missing-b")
                    (init-local-vulpea-integration-entry-ids)))
            (init-local-vulpea-task-table-filter-clear)
            (should
             (equal '("explicit-b" "missing-b" "priority-a" "unicode")
                    (sort (init-local-vulpea-integration-entry-ids)
                          #'string-lessp)))
            (init-local-vulpea-task-table-filter-text "重复")
            (should
             (equal '("unicode")
                    (init-local-vulpea-integration-entry-ids)))
            (init-local-vulpea-task-table-filter-clear)
            (should
             (equal source-before
                    (with-temp-buffer
                      (insert-file-contents org-file)
                      (buffer-string))))
            (vulpea-db-close)))
      (when (buffer-live-p collection-buffer)
        (kill-buffer collection-buffer))
      (ignore-errors (vulpea-db-close))
      (set-default 'org-todo-keywords old-workflow)
      (delete-directory temporary-directory t))))

(provide 'init-local-vulpea-integration-tests)
;;; init-local-vulpea-integration-tests.el ends here
