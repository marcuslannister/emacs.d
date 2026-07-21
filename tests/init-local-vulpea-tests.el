;;; init-local-vulpea-tests.el --- Tests for Vulpea Task Table -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'seq)

(cl-defstruct vulpea-note
  id path level pos title primary-title aliases tags links properties meta
  todo priority scheduled deadline closed outline-path attach-dir file-title
  created-at modified-at)

(cl-letf (((symbol-function 'maybe-require-package)
           (lambda (&rest _args) nil)))
  (load-file
   (expand-file-name "../lisp/init-local-vulpea.el"
                     (file-name-directory load-file-name))))

(defconst init-local-vulpea-test-workflow
  '((sequence "TODO(t)" "NEXT(n)" "WAITING(w@/!)" "HOLD(h)"
              "|" "DONE(d!/!)" "CANCELLED(c@/!)")))

(defmacro init-local-vulpea-test-with-workflow (&rest body)
  "Run BODY with the deterministic global Task workflow."
  (declare (indent 0) (debug t))
  `(let ((old-workflow (default-value 'org-todo-keywords)))
     (unwind-protect
         (progn
           (set-default 'org-todo-keywords
                        init-local-vulpea-test-workflow)
           ,@body)
       (set-default 'org-todo-keywords old-workflow))))

(defun init-local-vulpea-test-note (id todo priority title
                                       &optional level file-title outline-path)
  "Build a synthetic Vulpea note for Task Table tests."
  (make-vulpea-note
   :id id
   :path (format "/tmp/%s.org" (or file-title "Tasks"))
   :level (or level 1)
   :pos 1
   :title title
   :todo todo
   :priority priority
   :file-title (or file-title "Tasks")
   :outline-path outline-path))

(defun init-local-vulpea-test-fixtures ()
  "Return Tasks and deliberately ineligible notes in database order."
  (list
   (init-local-vulpea-test-note "missing-b" "TODO" nil "alpha" 1
                                "Work" '("Parent"))
   (init-local-vulpea-test-note "explicit-b" "TODO" ?B "Alpha" 1
                                "Work" '("Parent"))
   (init-local-vulpea-test-note "priority-a" "TODO" ?A "zeta")
   (init-local-vulpea-test-note "priority-c" "TODO" ?C "Ångström")
   (init-local-vulpea-test-note "next" "NEXT" ?A "Next task")
   (init-local-vulpea-test-note "unicode" "WAITING" nil "重复" 1
                                "项目" '("等待"))
   (init-local-vulpea-test-note "duplicate-1" "HOLD" ?A "Duplicate")
   (init-local-vulpea-test-note "duplicate-2" "HOLD" ?A "Duplicate")
   (init-local-vulpea-test-note "done" "DONE" ?A "Finished")
   (init-local-vulpea-test-note "cancelled" "CANCELLED" ?A "Dropped")
   (init-local-vulpea-test-note "file-note" "TODO" ?A "File" 0)
   (init-local-vulpea-test-note nil "TODO" ?A "No ID")
   (init-local-vulpea-test-note "no-state" nil ?A "Reference")))

(defun init-local-vulpea-test-visible-cell (cell)
  "Return CELL's visible replacement, or its plain contents."
  (or (and (> (length cell) 0)
           (get-text-property 0 'display cell))
      (substring-no-properties cell)))

(defun init-local-vulpea-test-priority-cell (note)
  "Return NOTE's public Collection View Priority cell value."
  (let ((priority (vulpea-note-priority note)))
    (cond
     ((null priority) "")
     ((characterp priority) (char-to-string priority))
     (t (format "%s" priority)))))

(defmacro init-local-vulpea-test-with-command-table (notes &rest body)
  "Open a mocked command-seam Task Table over NOTES, then run BODY."
  (declare (indent 1) (debug t))
  `(let ((database (make-temp-file "vulpea-task-table" nil ".db"))
         (database-notes ,notes)
         (collection-buffer
          (generate-new-buffer " *vulpea-task-table-command-test*"))
         (init-local-vulpea-task-table-unavailable-reason nil)
         view rows)
     (unwind-protect
         (cl-labels
             ((render ()
                (setq rows
                      (funcall
                       (plist-get (plist-get view :filter) :source))))
              (launch (mode &optional file)
                (let ((vulpea-db-location database))
                  (with-temp-buffer
                    (funcall mode)
                    (setq buffer-file-name file)
                    (my/vulpea-task-table)))))
           (cl-letf (((symbol-function 'vulpea-db-query)
                      (lambda () database-notes))
                     ((symbol-function 'vulpea-db-worker-busy-p)
                      (lambda () nil))
                     ((symbol-function 'vulpea-ui-collection-open)
                      (lambda (new-view)
                        (setq view new-view)
                        (switch-to-buffer collection-buffer)
                        (setq-local vulpea-ui-collection--view new-view)
                        (render)))
                     ((symbol-function 'vulpea-ui-collection-refresh)
                      #'render))
             ,@body))
       (when (buffer-live-p collection-buffer)
         (kill-buffer collection-buffer))
       (delete-file database))))

(ert-deftest init-local-vulpea-task-model-classifies-workflow-and-priority ()
  (init-local-vulpea-test-with-workflow
    (let ((open (init-local-vulpea-test-note "open" "WAITING" nil "Open"))
          (done (init-local-vulpea-test-note "done" "CANCELLED" ?A "Done"))
          (file (init-local-vulpea-test-note "file" "TODO" ?A "File" 0))
          (idless (init-local-vulpea-test-note nil "TODO" ?A "No ID")))
      (should (init-local-vulpea-task-eligible-p open))
      (should (init-local-vulpea-task-open-p open))
      (should-not (init-local-vulpea-task-open-p done))
      (should-not (init-local-vulpea-task-eligible-p file))
      (should-not (init-local-vulpea-task-eligible-p idless))
      (should (= 0 (init-local-vulpea-task-todo-rank "TODO")))
      (should (= 1 (init-local-vulpea-task-todo-rank "NEXT")))
      (should (= 2 (init-local-vulpea-task-todo-rank "WAITING")))
      (should (= 3 (init-local-vulpea-task-todo-rank "HOLD")))
      (should (= 4 (init-local-vulpea-task-todo-rank "UNKNOWN")))
      (should (= 0 (init-local-vulpea-task-priority-rank ?A)))
      (should (= 1 (init-local-vulpea-task-priority-rank ?B)))
      (should (= 1 (init-local-vulpea-task-priority-rank nil)))
      (should (= 2 (init-local-vulpea-task-priority-rank ?C)))
      (should (= 3 (init-local-vulpea-task-priority-rank ?D))))))

(ert-deftest init-local-vulpea-source-is-one-query-and-stably-sorted ()
  (init-local-vulpea-test-with-workflow
    (let ((queries 0)
          rows)
      (cl-letf (((symbol-function 'vulpea-db-query)
                 (lambda ()
                   (cl-incf queries)
                   (init-local-vulpea-test-fixtures)))
                ((symbol-function 'vulpea-db-get-by-id)
                 (lambda (&rest _)
                   (ert-fail "Source performed a per-row database read")))
                ((symbol-function 'vulpea-db-worker-busy-p)
                 (lambda () nil)))
        (setq rows (init-local-vulpea-task-table-source)))
      (should (= queries 1))
      (should
       (equal (mapcar #'vulpea-note-id rows)
              '("priority-a" "missing-b" "explicit-b" "priority-c"
                "next" "unicode" "duplicate-1" "duplicate-2")))
      (should (equal (mapcar #'vulpea-note-title (last rows 2))
                     '("Duplicate" "Duplicate"))))))

(ert-deftest init-local-vulpea-source-preserves-context-and-missing-priority ()
  (init-local-vulpea-test-with-workflow
    (cl-letf (((symbol-function 'vulpea-db-query)
               #'init-local-vulpea-test-fixtures)
              ((symbol-function 'vulpea-db-worker-busy-p)
               (lambda () nil)))
      (let* ((rows (init-local-vulpea-task-table-source))
             (missing (seq-find
                       (lambda (note)
                         (equal "missing-b" (vulpea-note-id note)))
                       rows))
             (explicit (seq-find
                        (lambda (note)
                          (equal "explicit-b" (vulpea-note-id note)))
                        rows))
             (missing-cell (init-local-vulpea-test-priority-cell missing))
             (explicit-cell (init-local-vulpea-test-priority-cell explicit)))
        (should (equal "Work" (vulpea-note-file-title missing)))
        (should (equal '("Parent") (vulpea-note-outline-path missing)))
        (should (equal "" (init-local-vulpea-test-visible-cell missing-cell)))
        (should (equal "B" (substring-no-properties missing-cell)))
        (should (equal "B" explicit-cell))
        (should-not (equal (vulpea-note-priority missing)
                           (vulpea-note-priority explicit)))))))

(ert-deftest init-local-vulpea-native-priority-values-sort-both-directions ()
  (init-local-vulpea-test-with-workflow
    (cl-letf (((symbol-function 'vulpea-db-query)
               #'init-local-vulpea-test-fixtures)
              ((symbol-function 'vulpea-db-worker-busy-p)
               (lambda () nil)))
      (let* ((rows (seq-filter
                    (lambda (note)
                      (member (vulpea-note-id note)
                              '("priority-a" "missing-b"
                                "explicit-b" "priority-c")))
                    (init-local-vulpea-task-table-source)))
             (cell #'init-local-vulpea-test-priority-cell)
             (ascending
              (sort (copy-sequence rows)
                    (lambda (a b)
                      (string-lessp (funcall cell a) (funcall cell b)))))
             (descending
              (sort (copy-sequence rows)
                    (lambda (a b)
                      (string-lessp (funcall cell b) (funcall cell a))))))
        (should (equal "priority-a" (vulpea-note-id (car ascending))))
        (should (equal "priority-c" (vulpea-note-id (car (last ascending)))))
        (should (equal "priority-c" (vulpea-note-id (car descending))))
        (should (equal "priority-a" (vulpea-note-id (car (last descending)))))
        (should
         (equal '("explicit-b" "missing-b")
                (sort (mapcar #'vulpea-note-id (seq-subseq ascending 1 3))
                      #'string-lessp)))))))

(ert-deftest init-local-vulpea-view-uses-fixed-public-collection-columns ()
  (let ((view (init-local-vulpea-task-table-view)))
    (should (equal "Task Table" (plist-get view :name)))
    (should (eq #'init-local-vulpea-task-table-source
                (plist-get (plist-get view :filter) :source)))
    (should
     (equal '((todo :name "TODO" :width 10)
              (priority :name "Priority" :width 8)
              (title :name "Task" :width 48)
              (context :name "Source" :width 36))
            (plist-get view :columns)))
    (should-not (plist-get view :sort))))

(ert-deftest init-local-vulpea-command-opens-one-read-only-view-with-one-query ()
  (init-local-vulpea-test-with-workflow
    (let ((database (make-temp-file "vulpea-task-table" nil ".db"))
          (buffer (generate-new-buffer " *vulpea-task-table-test*"))
          (init-local-vulpea-task-table-unavailable-reason nil)
          (queries 0)
          captured-view
          captured-rows)
      (unwind-protect
          (cl-letf (((symbol-function 'vulpea-db-query)
                     (lambda ()
                       (cl-incf queries)
                       (init-local-vulpea-test-fixtures)))
                    ((symbol-function 'vulpea-db-worker-busy-p)
                     (lambda () nil))
                    ((symbol-function 'vulpea-ui-collection-open)
                     (lambda (view)
                       (setq captured-view view
                             captured-rows
                             (funcall
                              (plist-get (plist-get view :filter) :source)))
                       (switch-to-buffer buffer))))
            (let ((vulpea-db-location database))
              (my/vulpea-task-table))
            (should (= queries 1))
            (should (equal "Task Table" (plist-get captured-view :name)))
            (should (= 8 (length captured-rows)))
            (should init-local-vulpea-task-table-read-only-mode)
            (should
             (equal '("TODO" "NEXT" "WAITING" "HOLD" "DONE" "CANCELLED")
                    org-todo-keywords-1)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))
        (delete-file database)))))

(ert-deftest init-local-vulpea-command-reports-missing-support ()
  (let ((init-local-vulpea-task-table-unavailable-reason
         "Vulpea UI package is unavailable"))
    (let ((message
           (condition-case err
               (progn (my/vulpea-task-table) nil)
             (user-error (error-message-string err)))))
      (should (string-match-p "Vulpea UI" message))
      (should (string-match-p "Install" message)))))

(ert-deftest init-local-vulpea-command-reports-database-failure ()
  (let ((database (make-temp-file "vulpea-task-table" nil ".db"))
        (init-local-vulpea-task-table-unavailable-reason nil))
    (unwind-protect
        (cl-letf (((symbol-function 'vulpea-db-query)
                   (lambda () (error "database locked")))
                  ((symbol-function 'vulpea-ui-collection-open)
                   (lambda (view)
                     (funcall
                      (plist-get (plist-get view :filter) :source)))))
          (let ((vulpea-db-location database)
                (message
                 (condition-case err
                     (progn (my/vulpea-task-table) nil)
                   (user-error (error-message-string err)))))
            (should (string-match-p "database" message))
            (should (string-match-p "vulpea-doctor" message))))
      (delete-file database))))

(ert-deftest init-local-vulpea-empty-active-index-reports-progress ()
  (cl-letf (((symbol-function 'vulpea-db-query) (lambda () nil))
            ((symbol-function 'vulpea-db-worker-busy-p) (lambda () t)))
    (let ((message
           (condition-case err
               (progn (init-local-vulpea-task-table-source) nil)
             (user-error (error-message-string err)))))
      (should (string-match-p "index" message))
      (should (string-match-p "progress" message)))))

(ert-deftest init-local-vulpea-read-only-mode-remaps-source-mutations ()
  (dolist (command '(vulpea-ui-collection-add-tag
                     vulpea-ui-collection-remove-tag
                     vulpea-ui-collection-quick-edit
                     vulpea-ui-collection-remove-meta
                     vulpea-ui-collection-set-todo
                     vulpea-ui-collection-delete
                     vulpea-ui-collection-apply
                     vulpea-ui-collection-undo))
    (should
     (eq #'init-local-vulpea-task-table-read-only
         (lookup-key init-local-vulpea-task-table-read-only-mode-map
                     (vector 'remap command)))))
  (dolist (binding '(("f t" . init-local-vulpea-task-table-filter-todo)
                     ("f p" . init-local-vulpea-task-table-filter-priority)
                     ("f x" . init-local-vulpea-task-table-filter-text)
                     ("f s" . init-local-vulpea-task-table-filter-source)
                     ("f c" . init-local-vulpea-task-table-filter-clear)
                     ("f b" . init-local-vulpea-task-table-filter-launch-source)))
    (should
     (eq (cdr binding)
         (lookup-key init-local-vulpea-task-table-read-only-mode-map
                     (kbd (car binding)))))))

(ert-deftest init-local-vulpea-command-filters-and-clears ()
  (init-local-vulpea-test-with-workflow
    (init-local-vulpea-test-with-command-table
        (init-local-vulpea-test-fixtures)
      (let ((inputs '("WAITING" "None" "A" "B" "C" "TODO" "None"))
            (strings '("PARENT" "重复" "DUPLICATE"
                       "parent" "项目" "TASKS" "ALPHA" "work")))
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (&rest _) (pop inputs)))
                  ((symbol-function 'read-string)
                   (lambda (&rest _) (pop strings))))
          (cl-labels
              ((check-filter (command expected)
                 (launch #'org-mode)
                 (with-current-buffer collection-buffer
                   (should
                    (local-variable-p
                     'init-local-vulpea-task-table-state))
                   (call-interactively command))
                 (should
                  (equal expected (mapcar #'vulpea-note-id rows)))))
            (check-filter #'init-local-vulpea-task-table-filter-todo
                          '("unicode"))
            (check-filter #'init-local-vulpea-task-table-filter-priority
                          '("missing-b" "unicode"))
            (check-filter #'init-local-vulpea-task-table-filter-priority
                          '("priority-a" "next"
                            "duplicate-1" "duplicate-2"))
            (check-filter #'init-local-vulpea-task-table-filter-priority
                          '("explicit-b"))
            (check-filter #'init-local-vulpea-task-table-filter-priority
                          '("priority-c"))
            (check-filter #'init-local-vulpea-task-table-filter-text
                          '("missing-b" "explicit-b"))
            (check-filter #'init-local-vulpea-task-table-filter-text
                          '("unicode"))
            (check-filter #'init-local-vulpea-task-table-filter-text
                          '("duplicate-1" "duplicate-2"))
            (check-filter #'init-local-vulpea-task-table-filter-source
                          '("missing-b" "explicit-b"))
            (check-filter #'init-local-vulpea-task-table-filter-source
                          '("unicode"))
            (check-filter #'init-local-vulpea-task-table-filter-source
                          '("priority-a" "priority-c" "next"
                            "duplicate-1" "duplicate-2"))
            (launch #'org-mode)
            (with-current-buffer collection-buffer
              (call-interactively
               #'init-local-vulpea-task-table-filter-todo)
              (call-interactively
               #'init-local-vulpea-task-table-filter-priority)
              (call-interactively
               #'init-local-vulpea-task-table-filter-text)
              (call-interactively
               #'init-local-vulpea-task-table-filter-source))
            (should
             (equal '("missing-b") (mapcar #'vulpea-note-id rows)))
            (with-current-buffer collection-buffer
              (call-interactively
               #'init-local-vulpea-task-table-filter-clear))
            (should
             (equal '("priority-a" "missing-b" "explicit-b" "priority-c"
                      "next" "unicode" "duplicate-1" "duplicate-2")
                    (mapcar #'vulpea-note-id rows)))))))))

(ert-deftest init-local-vulpea-command-scopes-to-org-launch ()
  (init-local-vulpea-test-with-workflow
    (let* ((origin-a (make-temp-file "vulpea-origin-a" nil ".org"))
           (origin-b (make-temp-file "vulpea-origin-b" nil ".org"))
           (task-a-1
            (init-local-vulpea-test-note "a-1" "TODO" ?A "First A"))
           (task-a-2
            (init-local-vulpea-test-note "a-2" "NEXT" nil "Second A"))
           (task-b
            (init-local-vulpea-test-note "b-1" "WAITING" ?C "Only B")))
      (setf (vulpea-note-path task-a-1) origin-a
            (vulpea-note-path task-a-2) origin-a
            (vulpea-note-path task-b) origin-b)
      (unwind-protect
          (init-local-vulpea-test-with-command-table
              (list task-a-1 task-a-2 task-b)
            (launch #'org-mode origin-a)
            (with-current-buffer collection-buffer
              (call-interactively
               #'init-local-vulpea-task-table-filter-launch-source))
            (should
             (equal '("a-1" "a-2") (mapcar #'vulpea-note-id rows)))
            (with-current-buffer collection-buffer
              (call-interactively
               #'init-local-vulpea-task-table-filter-clear))
            (should
             (equal '("a-1" "a-2" "b-1")
                    (mapcar #'vulpea-note-id rows)))
            (launch #'org-mode origin-b)
            (should
             (equal '("a-1" "a-2" "b-1")
                    (mapcar #'vulpea-note-id rows)))
            (with-current-buffer collection-buffer
              (call-interactively
               #'init-local-vulpea-task-table-filter-launch-source))
            (should (equal '("b-1") (mapcar #'vulpea-note-id rows)))
            (launch #'fundamental-mode)
            (should
             (equal '("a-1" "a-2" "b-1")
                    (mapcar #'vulpea-note-id rows)))
            (let ((message
                   (with-current-buffer collection-buffer
                     (condition-case err
                         (progn
                           (call-interactively
                            #'init-local-vulpea-task-table-filter-launch-source)
                           nil)
                       (user-error (error-message-string err))))))
              (should (string-match-p "Org launch" message))))
        (delete-file origin-a)
        (delete-file origin-b)))))

(provide 'init-local-vulpea-tests)
;;; init-local-vulpea-tests.el ends here
