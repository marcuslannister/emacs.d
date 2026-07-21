;;; init-local-vulpea-benchmark.el --- Task Table performance proof -*- lexical-binding: t; -*-

(require 'benchmark)
(require 'cl-lib)
(require 'package)
(require 'tabulated-list)

(let ((root (expand-file-name ".." (file-name-directory load-file-name))))
  (dolist (directory (file-expand-wildcards
                      (expand-file-name "elpa-*/*" root)))
    (when (file-directory-p directory)
      (add-to-list 'load-path directory))))

(require 'vulpea)

(cl-letf (((symbol-function 'maybe-require-package)
           (lambda (&rest _args) nil)))
  (load-file
   (expand-file-name "../lisp/init-local-vulpea.el"
                     (file-name-directory load-file-name))))

(declare-function init-local-vulpea-task-table-edit "init-local-vulpea"
                  (&optional field value))
(declare-function init-local-vulpea-task-table-source "init-local-vulpea"
                  (&optional state))
(declare-function make-init-local-vulpea-task-table-state "init-local-vulpea"
                  (&rest slots))

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

(defun init-local-vulpea-benchmark--assert-under (name actual limit)
  "Fail when NAME ACTUAL milliseconds does not beat LIMIT."
  (when (>= actual limit)
    (error "%s median %.3f ms exceeds %.0f ms" name actual limit)))

(defun init-local-vulpea-benchmark-run ()
  "Measure the Task Table pipeline through its public Collection source."
  (let* ((notes (init-local-vulpea-benchmark--tasks))
         (state (make-init-local-vulpea-task-table-state))
         (filter-state
          (make-init-local-vulpea-task-table-state :text "Task 49"))
         (old-workflow (default-value 'org-todo-keywords))
         (query-count 0)
         (lookup-count 0)
         rows initial-ms sort-ms filter-ms edit-ms)
    (unwind-protect
        (progn
          (set-default
           'org-todo-keywords
           '((sequence "TODO" "NEXT" "WAITING" "HOLD" "|" "DONE")))
          (cl-letf (((symbol-function 'vulpea-db-query)
                     (lambda (&optional _predicate)
                       (cl-incf query-count)
                       notes))
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
                     (setq rows
                           (init-local-vulpea-task-table-source state)))))
            (unless (= query-count (1+ init-local-vulpea-benchmark-runs))
              (error "Initial render must use one query per run"))
            (setq query-count 0
                  sort-ms
                  (init-local-vulpea-benchmark--median-ms
                   (lambda ()
                     (sort
                      (copy-sequence rows)
                      (lambda (a b)
                        (string-lessp (vulpea-note-title a)
                                      (vulpea-note-title b)))))))
            (unless (zerop query-count)
              (error "In-memory sort performed a database query"))
            (setq filter-ms
                  (init-local-vulpea-benchmark--median-ms
                   (lambda ()
                     (init-local-vulpea-task-table-source filter-state))))
            (unless (= query-count (1+ init-local-vulpea-benchmark-runs))
              (error "Filter refresh must use one query per run"))
            (with-temp-buffer
              (tabulated-list-mode)
              (setq tabulated-list-format [("Task" 20 t)]
                    tabulated-list-entries
                    '(("benchmark-0000" ["Task 0000"])))
              (tabulated-list-init-header)
              (tabulated-list-print)
              (goto-char (point-min))
              (setq query-count 0
                    lookup-count 0)
              (cl-letf (((symbol-function 'vulpea-ui-collection-refresh)
                         (lambda ()
                           (init-local-vulpea-task-table-source state))))
                (setq edit-ms
                      (init-local-vulpea-benchmark--median-ms
                       (lambda ()
                         (init-local-vulpea-task-table-edit
                          "Priority" "A"))))))
            (unless (= query-count (1+ init-local-vulpea-benchmark-runs))
              (error "Edit refresh must use one query per run"))
            (unless
                (= lookup-count (* 2 (1+ init-local-vulpea-benchmark-runs)))
              (error "Edit must perform two stable-ID checks per run"))))
      (set-default 'org-todo-keywords old-workflow))
    (princ
     (format
      (concat "Tasks: %d; median of %d warm runs\n"
              "Initial query/render: %.3f ms\n"
              "Sort: %.3f ms\n"
              "Filter: %.3f ms\n"
              "Edit-triggered refresh: %.3f ms\n")
      init-local-vulpea-benchmark-task-count
      init-local-vulpea-benchmark-runs
      initial-ms sort-ms filter-ms edit-ms))
    (init-local-vulpea-benchmark--assert-under
     "Initial query/render" initial-ms 200)
    (init-local-vulpea-benchmark--assert-under "Sort" sort-ms 100)
    (init-local-vulpea-benchmark--assert-under "Filter" filter-ms 100)
    (init-local-vulpea-benchmark--assert-under
     "Edit-triggered refresh" edit-ms 100)))

(when noninteractive
  (init-local-vulpea-benchmark-run))

(provide 'init-local-vulpea-benchmark)
;;; init-local-vulpea-benchmark.el ends here
