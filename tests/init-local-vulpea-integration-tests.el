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

(defun init-local-vulpea-integration-require ()
  "Load real Task Table dependencies or skip the current test."
  (unless (init-local-vulpea-integration-available-p)
    (ert-skip "Vulpea or Vulpea UI is unavailable; no packages are installed by tests"))
  (condition-case err
      (progn
        (require 'vulpea)
        (require 'vulpea-ui)
        (init-local-vulpea-task-table--install-refresh-advice))
    (error
     (ert-skip
      (format "Vulpea dependencies cannot load: %s"
              (error-message-string err))))))

(defun init-local-vulpea-integration-entry-ids ()
  "Return current Collection View row IDs in display order."
  (mapcar #'car tabulated-list-entries))

(defun init-local-vulpea-integration-entry (id)
  "Return current Collection View entry identified by ID."
  (assoc id tabulated-list-entries))

(defun init-local-vulpea-integration-goto-entry (id)
  "Move point to the rendered Collection View row identified by ID."
  (goto-char (point-min))
  (catch 'found
    (while (< (point) (point-max))
      (when (equal id (tabulated-list-get-id))
        (throw 'found t))
      (forward-line 1))
    nil))

(ert-deftest init-local-vulpea-public-indexing-opens-read-only-task-table ()
  (init-local-vulpea-integration-require)
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
            (should
             (init-local-vulpea-integration-goto-entry "explicit-b"))
            (let ((query (symbol-function 'vulpea-db-query))
                  (sort-key (copy-tree tabulated-list-sort-key))
                  (queries 0))
              (cl-letf (((symbol-function 'vulpea-db-query)
                         (lambda (&rest args)
                           (cl-incf queries)
                           (apply query args)))
                        ((symbol-function 'vulpea-db-worker-busy-p)
                         (lambda () nil)))
                (run-hook-with-args
                 'vulpea-db-worker-done-functions
                 org-file 'applied 1))
              (should (> queries 0))
              (should (equal "explicit-b" (tabulated-list-get-id)))
              (should (equal sort-key tabulated-list-sort-key)))
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

(ert-deftest init-local-vulpea-navigation-survives-move-and-deletion ()
  (init-local-vulpea-integration-require)
  (let* ((temporary-directory (make-temp-file "vulpea-task-navigation" t))
         (source-file (expand-file-name "inbox.org" temporary-directory))
         (target-file (expand-file-name "archive.org" temporary-directory))
         (database (expand-file-name "vulpea.db" temporary-directory))
         (org-id-locations-file
          (expand-file-name "org-id-locations" temporary-directory))
         (old-workflow (default-value 'org-todo-keywords))
         collection-buffer)
    (unwind-protect
        (progn
          (set-default 'org-todo-keywords
                       '((sequence "TODO(t)" "|" "DONE(d)")))
          (with-temp-file source-file
            (insert
             "#+title: Inbox\n"
             "* Parent\n"
             "** TODO Movable Task\n"
             ":PROPERTIES:\n:ID: movable-task\n:END:\n"))
          (with-temp-file target-file
            (insert "#+title: Archive\n* Destination\n"))
          (vulpea-db-close)
          (let ((vulpea-db-location database)
                (vulpea-db-index-heading-level t)
                (vulpea-db-sync-directories
                 (list (file-name-as-directory temporary-directory)))
                (init-local-vulpea-task-table-unavailable-reason nil))
            (vulpea-db-update-file source-file)
            (vulpea-db-update-file target-file)
            (my/vulpea-task-table)
            (setq collection-buffer (current-buffer))
            (should (init-local-vulpea-integration-goto-entry "movable-task"))
            (with-temp-file source-file
              (insert "#+title: Inbox\n* Parent\n"))
            (with-temp-file target-file
              (insert
               "#+title: Archive\n"
               "* Destination\n"
               "** TODO Movable Task\n"
               ":PROPERTIES:\n:ID: movable-task\n:END:\n"))
            (vulpea-db-update-file source-file)
            (vulpea-db-update-file target-file)
            (vulpea-ui-collection-refresh)
            (should (init-local-vulpea-integration-goto-entry "movable-task"))
            (init-local-vulpea-task-table-visit)
            (should (equal (file-truename target-file)
                           (file-truename buffer-file-name)))
            (should (equal "Movable Task" (org-get-heading t t t t)))
            (switch-to-buffer collection-buffer)
            (with-temp-file target-file
              (insert "#+title: Archive\n* Destination\n"))
            (vulpea-db-update-file target-file)
            (let ((message
                   (condition-case err
                       (progn (init-local-vulpea-task-table-visit) nil)
                     (user-error (error-message-string err)))))
              (should (string-match-p "disappeared" message)))
            (should-not (init-local-vulpea-integration-entry "movable-task"))
            (vulpea-db-close)))
      (when (buffer-live-p collection-buffer)
        (kill-buffer collection-buffer))
      (dolist (file (list source-file target-file))
        (when-let* ((buffer (find-buffer-visiting file)))
          (kill-buffer buffer)))
      (ignore-errors (vulpea-db-close))
      (set-default 'org-todo-keywords old-workflow)
      (delete-directory temporary-directory t))))


(ert-deftest init-local-vulpea-edit-todo-and-priority-writeback ()
  (init-local-vulpea-integration-require)
  (let* ((temporary-directory (make-temp-file "vulpea-task-edit" t))
         (org-file (expand-file-name "tasks.org" temporary-directory))
         (database (expand-file-name "vulpea.db" temporary-directory))
         (org-id-locations-file
          (expand-file-name "org-id-locations" temporary-directory))
         (old-workflow (default-value 'org-todo-keywords))
         collection-buffer)
    (unwind-protect
        (progn
          (set-default 'org-todo-keywords
                       '((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d)")))
          (with-temp-file org-file
            (insert
             "#+title: Tasks\n"
             "* Parent\n"
             "** TODO [#A] Editable\n"
             ":PROPERTIES:\n:ID: editable-task\n:END:\n"
             "** TODO [#B] Keep Open\n"
             ":PROPERTIES:\n:ID: keep-open\n:END:\n"))
          (vulpea-db-close)
          (let ((vulpea-db-location database)
                (vulpea-db-index-heading-level t)
                (vulpea-db-sync-directories
                 (list (file-name-as-directory temporary-directory)))
                (init-local-vulpea-task-table-unavailable-reason nil))
            (vulpea-db-update-file org-file)
            (my/vulpea-task-table)
            (setq collection-buffer (current-buffer))
            (should (init-local-vulpea-integration-goto-entry "editable-task"))
            (init-local-vulpea-task-table-edit "Priority" "None")
            (should (init-local-vulpea-integration-goto-entry "editable-task"))
            (let ((note (vulpea-db-get-by-id "editable-task")))
              (should note)
              (should-not (vulpea-note-priority note)))
            (should
             (string-match-p
              "\\*\\* TODO Editable"
              (with-temp-buffer
                (insert-file-contents org-file)
                (buffer-string))))
            (should-not
             (string-match-p
              "\\[#A\\]"
              (with-temp-buffer
                (insert-file-contents org-file)
                (buffer-string))))
            (should (init-local-vulpea-integration-goto-entry "editable-task"))
            (init-local-vulpea-task-table-edit "TODO" "NEXT")
            (let ((note (vulpea-db-get-by-id "editable-task")))
              (should (equal "NEXT" (vulpea-note-todo note)))
              (should-not (vulpea-note-priority note)))
            (should (member "editable-task"
                            (init-local-vulpea-integration-entry-ids)))
            (should (init-local-vulpea-integration-goto-entry "editable-task"))
            (init-local-vulpea-task-table-edit "TODO" "DONE")
            (should-not (init-local-vulpea-integration-entry "editable-task"))
            (should (equal '("keep-open")
                           (init-local-vulpea-integration-entry-ids)))
            (should (equal "keep-open" (tabulated-list-get-id)))
            (should
             (string-match-p
              "\\*\\* DONE Editable"
              (with-temp-buffer
                (insert-file-contents org-file)
                (buffer-string))))
            ;; Move keeps ID and stays editable.
            (let ((target-file (expand-file-name "archive.org"
                                                 temporary-directory)))
              (with-temp-file org-file
                (insert "#+title: Tasks\n* Parent\n"
                        "** TODO [#B] Keep Open\n"
                        ":PROPERTIES:\n:ID: keep-open\n:END:\n"))
              (with-temp-file target-file
                (insert
                 "#+title: Archive\n"
                 "* Destination\n"
                 "** TODO Moved Task\n"
                 ":PROPERTIES:\n:ID: moved-edit\n:END:\n"))
              (vulpea-db-update-file org-file)
              (vulpea-db-update-file target-file)
              (vulpea-ui-collection-refresh)
              (should (init-local-vulpea-integration-goto-entry "moved-edit"))
              (init-local-vulpea-task-table-edit "Priority" "A")
              (let ((note (vulpea-db-get-by-id "moved-edit")))
                (should note)
                (should (eq ?A (vulpea-note-priority note))))
              (with-temp-file target-file
                (insert "#+title: Archive\n* Destination\n"))
              (vulpea-db-update-file target-file)
              (let ((message
                     (condition-case err
                         (progn
                           (init-local-vulpea-integration-goto-entry
                            "moved-edit")
                           (init-local-vulpea-task-table-edit "TODO" "NEXT")
                           nil)
                       (user-error (error-message-string err)))))
                (should (string-match-p "disappeared" message))
                (should-not
                 (init-local-vulpea-integration-entry "moved-edit"))))
            (vulpea-db-close)))
      (when (buffer-live-p collection-buffer)
        (kill-buffer collection-buffer))
      (dolist (file (directory-files temporary-directory t "\\.org\\'"))
        (when-let* ((buffer (find-buffer-visiting file)))
          (kill-buffer buffer)))
      (ignore-errors (vulpea-db-close))
      (set-default 'org-todo-keywords old-workflow)
      (delete-directory temporary-directory t))))

(provide 'init-local-vulpea-integration-tests)
;;; init-local-vulpea-integration-tests.el ends here
