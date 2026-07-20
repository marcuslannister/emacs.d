;;; prototype-vulpea-task-table.el --- Throwaway Task Table prototype -*- lexical-binding: t; -*-

;; PROTOTYPE — do not ship.
;; Question: Is the accepted native Task Table interaction coherent when
;; editing, filtering, sorting, jumping to source, and refreshing all affect
;; the same in-memory collection?
;; Run: emacs -Q -l lisp/prototype-vulpea-task-table.el -f prototype-vulpea-task-table

;;; Commentary:

;; Synthetic data only.  No Vulpea integration and no file writes.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'seq)
(require 'subr-x)
(require 'tabulated-list)

(defconst prototype-vulpea-task-table--workflow '("TODO" "NEXT" "WAIT" "DONE"))
(defconst prototype-vulpea-task-table--default-origin-source "Emacs.org")

(defvar prototype-vulpea-task-table--tasks nil)

(defvar-local prototype-vulpea-task-table--todo-filter nil)
(defvar-local prototype-vulpea-task-table--priority-filter nil)
(defvar-local prototype-vulpea-task-table--text-filter "")
(defvar-local prototype-vulpea-task-table--source-filter "")
(defvar-local prototype-vulpea-task-table--current-source nil)
(defvar-local prototype-vulpea-task-table--origin-source nil)
(defvar-local prototype-vulpea-task-table--synthetic-source nil)

(defvar prototype-vulpea-task-table-filter-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "t") #'prototype-vulpea-task-table-filter-todo)
    (define-key map (kbd "p") #'prototype-vulpea-task-table-filter-priority)
    (define-key map (kbd "x") #'prototype-vulpea-task-table-filter-text)
    (define-key map (kbd "s") #'prototype-vulpea-task-table-filter-source)
    (define-key map (kbd "b") #'prototype-vulpea-task-table-filter-current-buffer)
    (define-key map (kbd "c") #'prototype-vulpea-task-table-clear-filters)
    map)
  "Keymap for Task Table prototype filters.")

(defvar prototype-vulpea-task-table-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "e") #'prototype-vulpea-task-table-edit)
    (define-key map (kbd "RET") #'prototype-vulpea-task-table-visit-source)
    (define-key map (kbd "f") prototype-vulpea-task-table-filter-map)
    (define-key map (kbd "g") #'prototype-vulpea-task-table-refresh)
    (define-key map (kbd "R") #'prototype-vulpea-task-table-reset)
    map)
  "Keymap for `prototype-vulpea-task-table-mode'.")

(defun prototype-vulpea-task-table--fresh-tasks ()
  "Return fresh synthetic Tasks."
  (mapcar (lambda (task) (plist-put task :marker nil))
          (list
   (list :id "task-1" :todo "NEXT" :priority "A"
         :heading "Prepare quarterly plan" :source "Projects.org")
   (list :id "task-2" :todo "TODO" :priority "C"
         :heading "Book dentist appointment" :source "Personal.org")
   (list :id "task-3" :todo "TODO" :priority "A"
         :heading "Fix flaky startup check" :source "Emacs.org")
   (list :id "task-4" :todo "WAIT" :priority "B"
         :heading "Receive conference approval" :source "Work.org")
   (list :id "task-5" :todo "NEXT" :priority "B"
         :heading "Review contributor patch" :source "Emacs.org")
   (list :id "task-6" :todo "TODO" :priority nil
         :heading "Read native compilation notes" :source "Emacs.org")
   (list :id "task-7" :todo "DONE" :priority "A"
         :heading "Archive old project" :source "Projects.org"))))

(defun prototype-vulpea-task-table--task (id)
  "Return synthetic Task identified by ID."
  (seq-find (lambda (task) (equal id (plist-get task :id)))
            prototype-vulpea-task-table--tasks))

(defun prototype-vulpea-task-table--rank (value choices)
  "Return VALUE position in CHOICES, placing unknown values last."
  (or (seq-position choices value #'equal) (length choices)))

(defun prototype-vulpea-task-table--entry-less-p (entry-a entry-b)
  "Order ENTRY-A before ENTRY-B by workflow, Priority, then heading."
  (let* ((a (prototype-vulpea-task-table--task (car entry-a)))
         (b (prototype-vulpea-task-table--task (car entry-b)))
         (todo-a (prototype-vulpea-task-table--rank
                  (plist-get a :todo) prototype-vulpea-task-table--workflow))
         (todo-b (prototype-vulpea-task-table--rank
                  (plist-get b :todo) prototype-vulpea-task-table--workflow))
         (priority-a (prototype-vulpea-task-table--rank
                      (plist-get a :priority) '("A" "B" "C" nil)))
         (priority-b (prototype-vulpea-task-table--rank
                      (plist-get b :priority) '("A" "B" "C" nil))))
    (cond
     ((/= todo-a todo-b) (< todo-a todo-b))
     ((/= priority-a priority-b) (< priority-a priority-b))
     (t (string-lessp (plist-get a :heading) (plist-get b :heading))))))

(defun prototype-vulpea-task-table--priority-less-p (entry-a entry-b)
  "Order ENTRY-A before ENTRY-B by Priority, then heading."
  (let* ((a (prototype-vulpea-task-table--task (car entry-a)))
         (b (prototype-vulpea-task-table--task (car entry-b)))
         (rank-a (prototype-vulpea-task-table--rank
                  (plist-get a :priority) '("A" "B" "C" nil)))
         (rank-b (prototype-vulpea-task-table--rank
                  (plist-get b :priority) '("A" "B" "C" nil))))
    (if (= rank-a rank-b)
        (string-lessp (plist-get a :heading) (plist-get b :heading))
      (< rank-a rank-b))))

(defun prototype-vulpea-task-table--open-p (task)
  "Return non-nil when TASK is open."
  (not (equal (plist-get task :todo) "DONE")))

(defun prototype-vulpea-task-table--matches-p (task)
  "Return non-nil when TASK passes current filters."
  (and
   (prototype-vulpea-task-table--open-p task)
   (or (null prototype-vulpea-task-table--todo-filter)
       (member (plist-get task :todo) prototype-vulpea-task-table--todo-filter))
   (or (null prototype-vulpea-task-table--priority-filter)
       (member (or (plist-get task :priority) "None")
               prototype-vulpea-task-table--priority-filter))
   (or (string-empty-p prototype-vulpea-task-table--text-filter)
       (string-match-p
        (regexp-quote prototype-vulpea-task-table--text-filter)
        (downcase (plist-get task :heading))))
   (or (string-empty-p prototype-vulpea-task-table--source-filter)
       (string-match-p
        (regexp-quote prototype-vulpea-task-table--source-filter)
        (downcase (plist-get task :source))))
   (or (null prototype-vulpea-task-table--current-source)
       (equal prototype-vulpea-task-table--current-source
              (plist-get task :source)))))

(defun prototype-vulpea-task-table--entries ()
  "Return visible synthetic Task entries."
  (cl-loop for task in prototype-vulpea-task-table--tasks
           when (prototype-vulpea-task-table--matches-p task)
           collect
           (list (plist-get task :id)
                 (vector
                  (plist-get task :todo)
                  (or (plist-get task :priority) "-")
                  (plist-get task :heading)
                  (plist-get task :source)))))

(defun prototype-vulpea-task-table--filter-summary ()
  "Return compact visible filter state."
  (let ((parts nil))
    (when prototype-vulpea-task-table--todo-filter
      (push (format "TODO=%s"
                    (string-join prototype-vulpea-task-table--todo-filter ","))
            parts))
    (when prototype-vulpea-task-table--priority-filter
      (push (format "Priority=%s"
                    (string-join prototype-vulpea-task-table--priority-filter ","))
            parts))
    (unless (string-empty-p prototype-vulpea-task-table--text-filter)
      (push (format "text=%S" prototype-vulpea-task-table--text-filter) parts))
    (unless (string-empty-p prototype-vulpea-task-table--source-filter)
      (push (format "source=%S" prototype-vulpea-task-table--source-filter) parts))
    (when prototype-vulpea-task-table--current-source
      (push (format "buffer=%s" prototype-vulpea-task-table--current-source) parts))
    (if parts
        (format " [%s]" (string-join (nreverse parts) "; "))
      " [open Tasks]")))

(defun prototype-vulpea-task-table--refresh-mode-line ()
  "Show active filters in the mode line."
  (setq-local mode-line-process
              '(:eval (prototype-vulpea-task-table--filter-summary)))
  (force-mode-line-update))

(defun prototype-vulpea-task-table--source-buffer-name (source)
  "Return prototype buffer name for SOURCE."
  (format "*Task Table Prototype Source: %s*" source))

(defun prototype-vulpea-task-table--rebuild-source-buffers ()
  "Rebuild synthetic read-only Org source buffers and Task markers."
  (dolist (source (delete-dups
                   (mapcar (lambda (task) (plist-get task :source))
                           prototype-vulpea-task-table--tasks)))
    (with-current-buffer
        (get-buffer-create (prototype-vulpea-task-table--source-buffer-name source))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (setq-local prototype-vulpea-task-table--synthetic-source source)
        (insert (format "#+title: %s (PROTOTYPE — synthetic)\n\n" source))
        (dolist (task prototype-vulpea-task-table--tasks)
          (when (equal source (plist-get task :source))
            (let ((marker (point-marker)))
              (setf (plist-get task :marker) marker)
              (insert (format "* %s%s %s\n:PROPERTIES:\n:ID: %s\n:END:\n\n"
                              (plist-get task :todo)
                              (if-let* ((priority (plist-get task :priority)))
                                  (format " [#%s]" priority)
                                "")
                              (plist-get task :heading)
                              (plist-get task :id))))))
        (goto-char (point-min))
        (setq buffer-read-only t)))))

(defun prototype-vulpea-task-table-refresh ()
  "Refresh rows while preserving cursor, sort, and filters."
  (interactive)
  (prototype-vulpea-task-table--rebuild-source-buffers)
  (tabulated-list-print t)
  (prototype-vulpea-task-table--refresh-mode-line))

(defun prototype-vulpea-task-table--refresh-after-filter ()
  "Refresh after a filter change and report the visible row count."
  (prototype-vulpea-task-table-refresh)
  (message "%d Tasks visible; `f c' clears filters"
           (length (prototype-vulpea-task-table--entries))))

(defun prototype-vulpea-task-table-filter-todo ()
  "Set the combinable TODO filter."
  (interactive)
  (setq prototype-vulpea-task-table--todo-filter
        (completing-read-multiple "TODO states (empty means all open): "
                                  '("TODO" "NEXT" "WAIT") nil t))
  (prototype-vulpea-task-table--refresh-after-filter))

(defun prototype-vulpea-task-table-filter-priority ()
  "Set the combinable Priority filter."
  (interactive)
  (setq prototype-vulpea-task-table--priority-filter
        (completing-read-multiple "Priorities (empty means all): "
                                  '("A" "B" "C" "None") nil t))
  (prototype-vulpea-task-table--refresh-after-filter))

(defun prototype-vulpea-task-table-filter-text (text)
  "Set case-insensitive heading TEXT filter."
  (interactive "sHeading text (empty means all): ")
  (setq prototype-vulpea-task-table--text-filter (downcase text))
  (prototype-vulpea-task-table--refresh-after-filter))

(defun prototype-vulpea-task-table-filter-source (text)
  "Set case-insensitive source TEXT filter."
  (interactive "sSource text (empty means all): ")
  (setq prototype-vulpea-task-table--source-filter (downcase text))
  (prototype-vulpea-task-table--refresh-after-filter))

(defun prototype-vulpea-task-table-filter-current-buffer ()
  "Toggle filtering to the Org buffer that launched the Task Table."
  (interactive)
  (if prototype-vulpea-task-table--current-source
      (setq prototype-vulpea-task-table--current-source nil)
    (unless prototype-vulpea-task-table--origin-source
      (user-error "Launch the table from a synthetic Org source buffer first"))
    (setq prototype-vulpea-task-table--current-source
          prototype-vulpea-task-table--origin-source))
  (prototype-vulpea-task-table--refresh-after-filter))

(defun prototype-vulpea-task-table-clear-filters ()
  "Clear all Task Table filters."
  (interactive)
  (setq prototype-vulpea-task-table--todo-filter nil
        prototype-vulpea-task-table--priority-filter nil
        prototype-vulpea-task-table--text-filter ""
        prototype-vulpea-task-table--source-filter ""
        prototype-vulpea-task-table--current-source nil)
  (prototype-vulpea-task-table--refresh-after-filter))

(defun prototype-vulpea-task-table-edit ()
  "Edit the current synthetic Task's TODO state or Priority."
  (interactive)
  (let* ((id (or (tabulated-list-get-id) (user-error "No Task at point")))
         (task (prototype-vulpea-task-table--task id))
         (field (read-char-choice "Edit [t] TODO, [p] Priority, [q] cancel: "
                                  '(?t ?p ?q))))
    (pcase field
      (?t
       (setf (plist-get task :todo)
             (completing-read "TODO state: "
                              prototype-vulpea-task-table--workflow nil t
                              nil nil (plist-get task :todo))))
      (?p
       (let ((priority (completing-read "Priority: " '("A" "B" "C" "None")
                                        nil t nil nil
                                        (or (plist-get task :priority) "None"))))
         (setf (plist-get task :priority)
               (unless (equal priority "None") priority)))))
    (unless (eq field ?q)
      (prototype-vulpea-task-table-refresh)
      (if (prototype-vulpea-task-table--open-p task)
          (message "Updated %s; cursor, sort, and filters preserved" id)
        (message "Completed %s; row removed from the open-Task table" id)))))

(defun prototype-vulpea-task-table-visit-source ()
  "Jump to the current synthetic Task's source heading."
  (interactive)
  (let* ((id (or (tabulated-list-get-id) (user-error "No Task at point")))
         (task (prototype-vulpea-task-table--task id))
         (marker (plist-get task :marker)))
    (pop-to-buffer (marker-buffer marker))
    (goto-char marker)
    (org-show-context)))

(defun prototype-vulpea-task-table-reset ()
  "Reset all synthetic Tasks and filters."
  (interactive)
  (setq prototype-vulpea-task-table--tasks
        (prototype-vulpea-task-table--fresh-tasks))
  (prototype-vulpea-task-table-clear-filters)
  (message "Prototype reset"))

(define-derived-mode prototype-vulpea-task-table-mode tabulated-list-mode
  "Task-Table-Prototype"
  "Throwaway native Task Table interaction prototype.

Keys:
\<prototype-vulpea-task-table-mode-map>
\[prototype-vulpea-task-table-edit] edits TODO or Priority.
\[prototype-vulpea-task-table-visit-source] jumps to synthetic Org source.
\[prototype-vulpea-task-table-refresh] refreshes without resetting view state.
`f t/p/x/s/b' sets filters; `f c' clears them.  `R' resets all data."
  (setq tabulated-list-format
        [("TODO" 8 prototype-vulpea-task-table--entry-less-p)
         ("Priority" 8 prototype-vulpea-task-table--priority-less-p)
         ("Task" 36 t)
         ("Source" 18 t)])
  (setq tabulated-list-sort-key '("TODO" . nil))
  (setq tabulated-list-entries #'prototype-vulpea-task-table--entries)
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header)
  (prototype-vulpea-task-table--refresh-mode-line))

;;;###autoload
(defun prototype-vulpea-task-table ()
  "Open the throwaway native Task Table prototype."
  (interactive)
  (let ((origin-source
         (or (and (derived-mode-p 'org-mode)
                  prototype-vulpea-task-table--synthetic-source)
             prototype-vulpea-task-table--default-origin-source)))
    (unless prototype-vulpea-task-table--tasks
      (setq prototype-vulpea-task-table--tasks
            (prototype-vulpea-task-table--fresh-tasks)))
    (with-current-buffer (get-buffer-create "*Task Table Prototype*")
      (prototype-vulpea-task-table-mode)
      (setq prototype-vulpea-task-table--origin-source origin-source)
      (prototype-vulpea-task-table--rebuild-source-buffers)
      (tabulated-list-print)
      (pop-to-buffer (current-buffer)))))

(provide 'prototype-vulpea-task-table)
;;; prototype-vulpea-task-table.el ends here
