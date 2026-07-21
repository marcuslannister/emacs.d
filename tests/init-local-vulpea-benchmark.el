;;; init-local-vulpea-benchmark.el --- Task Table performance proof -*- lexical-binding: t; -*-

(require 'benchmark)
(require 'cl-lib)
(require 'package)

(let ((root (expand-file-name ".." (file-name-directory load-file-name))))
  (dolist (directory (file-expand-wildcards
                      (expand-file-name "elpa-*/*" root)))
    (when (file-directory-p directory)
      (add-to-list 'load-path directory))))

(unless (and (not (version< emacs-version "29.1"))
             (locate-library "vulpea")
             (locate-library "vulpea-ui"))
  (princ "SKIP: Vulpea benchmark dependencies are unavailable\n")
  (kill-emacs 0))

(require 'tabulated-list)
(require 'vulpea)
(require 'vulpea-ui)

(cl-letf (((symbol-function 'maybe-require-package)
           (lambda (&rest _args) nil)))
  (load-file
   (expand-file-name "../lisp/init-local-vulpea.el"
                     (file-name-directory load-file-name))))

(defconst init-local-vulpea-benchmark-task-count 5000)
(defconst init-local-vulpea-benchmark-runs 5)

(defun init-local-vulpea-benchmark--tasks ()
  "Build the synthetic Task collection."
  (cl-loop
   for index below init-local-vulpea-benchmark-task-count
   collect
   (make-vulpea-note
    :id (format "benchmark-%04d" index)
    :path (format "/tmp/task-benchmark-%d.org" (% index 20))
    :level 2
    :pos (1+ index)
    :title (format "Task %04d" index)
    :todo (aref ["TODO" "NEXT" "WAITING" "HOLD"] (% index 4))
    :priority (aref [?A ?B ?C nil] (% index 4))
    :file-title (format "Project %02d" (% index 20))
    :outline-path (list (format "Area %02d" (% index 50))))))

(defun init-local-vulpea-benchmark--median-ms (thunk)
  "Return median milliseconds for five warm runs of THUNK."
  (funcall thunk)
  (let ((samples
         (cl-loop repeat init-local-vulpea-benchmark-runs
                  collect (* 1000.0 (car (benchmark-run 1 (funcall thunk)))))))
    (nth (/ (length samples) 2) (sort samples #'<))))

(defun init-local-vulpea-benchmark--line (name actual limit)
  "Format NAME with ACTUAL milliseconds and LIMIT status."
  (format "%s: %.3f ms (%s < %.0f ms)\n"
          name actual (if (< actual limit) "PASS" "FAIL") limit))

(defun init-local-vulpea-benchmark--goto-first-row ()
  "Move point to the first rendered Task row."
  (goto-char (point-min))
  (while (and (not (eobp)) (null (tabulated-list-get-id)))
    (forward-line 1)))

(defun init-local-vulpea-benchmark-run ()
  "Measure real Collection View open, sort, filter, and edit refresh."
  (let* ((notes (init-local-vulpea-benchmark--tasks))
         (state (make-init-local-vulpea-task-table-state))
         (database (make-temp-file "vulpea-task-benchmark" nil ".db"))
         (buffer-name "*vulpea-collection: Task Table*")
         (old-workflow (default-value 'org-todo-keywords))
         (query-count 0)
         (lookup-count 0)
         initial-ms sort-ms filter-ms edit-ms)
    (unwind-protect
        (let ((vulpea-db-location database)
              (init-local-vulpea-task-table-unavailable-reason nil))
          (set-default
           'org-todo-keywords
           '((sequence "TODO" "NEXT" "WAITING" "HOLD" "|" "DONE")))
          (cl-letf (((symbol-function 'vulpea-db-query)
                     (lambda (&optional _predicate)
                       (cl-incf query-count)
                       notes))
                    ((symbol-function 'vulpea-db-count-notes)
                     (lambda () (length notes)))
                    ((symbol-function 'vulpea-db-worker-busy-p)
                     (lambda () nil))
                    ((symbol-function 'vulpea-db-get-by-id)
                     (lambda (_id)
                       (cl-incf lookup-count)
                       (car notes)))
                    ((symbol-function
                      'init-local-vulpea-task-table--mutate-note)
                     #'ignore))
            (setq initial-ms
                  (init-local-vulpea-benchmark--median-ms
                   (lambda ()
                     (when-let* ((buffer (get-buffer buffer-name)))
                       (kill-buffer buffer))
                     (vulpea-ui-collection-open
                      (init-local-vulpea-task-table-view state)))))
            (unless (= query-count (1+ init-local-vulpea-benchmark-runs))
              (error "Initial render must use one query per run"))
            (with-current-buffer buffer-name
              (setq-local init-local-vulpea-task-table-state state)
              (init-local-vulpea-task-table-read-only-mode +1)
              (init-local-vulpea-task-table--install-refresh-advice)
              (setq query-count 0)
              (let ((descending nil))
                (setq sort-ms
                      (init-local-vulpea-benchmark--median-ms
                       (lambda ()
                         (setq descending (not descending)
                               tabulated-list-sort-key
                               (cons "Task" descending))
                         (tabulated-list-print t)))))
              (unless (zerop query-count)
                (error "Native sort performed a database query"))
              (setq filter-ms
                    (init-local-vulpea-benchmark--median-ms
                     (lambda ()
                       (init-local-vulpea-task-table-filter-text "Task 49"))))
              (unless (= query-count (1+ init-local-vulpea-benchmark-runs))
                (error "Filter refresh must use one query per run"))
              (init-local-vulpea-task-table-filter-clear)
              (init-local-vulpea-benchmark--goto-first-row)
              (setq query-count 0
                    lookup-count 0
                    edit-ms
                    (init-local-vulpea-benchmark--median-ms
                     (lambda ()
                       (init-local-vulpea-task-table-edit "Priority" "A"))))
              (unless (= query-count (1+ init-local-vulpea-benchmark-runs))
                (error "Edit refresh must use one query per run"))
              (unless
                  (= lookup-count (* 2 (1+ init-local-vulpea-benchmark-runs)))
                (error "Edit must perform two stable-ID checks per run"))))
          (princ
           (format "Tasks: %d; median of %d warm runs\n"
                   init-local-vulpea-benchmark-task-count
                   init-local-vulpea-benchmark-runs))
          (princ (init-local-vulpea-benchmark--line
                  "Initial query/render" initial-ms 200))
          (princ (init-local-vulpea-benchmark--line "Sort" sort-ms 100))
          (princ (init-local-vulpea-benchmark--line "Filter" filter-ms 100))
          (princ (init-local-vulpea-benchmark--line
                  "Edit-triggered refresh" edit-ms 100)))
      (advice-remove 'vulpea-ui-collection-refresh
                     #'init-local-vulpea-task-table--refresh-advice)
      (when-let* ((buffer (get-buffer buffer-name)))
        (kill-buffer buffer))
      (set-default 'org-todo-keywords old-workflow)
      (delete-file database))))

(when noninteractive
  (init-local-vulpea-benchmark-run))

(provide 'init-local-vulpea-benchmark)
;;; init-local-vulpea-benchmark.el ends here
