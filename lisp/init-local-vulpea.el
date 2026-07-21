;;; init-local-vulpea.el --- Read-only Vulpea Task Table -*- lexical-binding: t; -*-
;;; Commentary:
;; Optional Vulpea indexing and one read-only Collection View over Open Tasks.
;;; Code:

(require 'cl-lib)
(require 'org)
(require 'seq)
(require 'subr-x)

(defvar vulpea-db-index-heading-level)
(defvar vulpea-db-location)
(defvar vulpea-db-sync-directories)
(defvar vulpea-db-sync-scan-on-enable)

(declare-function maybe-require-package "init-elpa"
                  (package &optional min-version no-refresh))
(declare-function make-vulpea-note "vulpea-note" (&rest slots))
(declare-function vulpea-db-autosync-mode "vulpea-db-sync" (&optional arg))
(declare-function vulpea-db-query "vulpea-db-query" (&optional predicate))
(declare-function vulpea-db-worker-busy-p "vulpea-db-worker" ())
(declare-function vulpea-note-aliases "vulpea-note" (note))
(declare-function vulpea-note-attach-dir "vulpea-note" (note))
(declare-function vulpea-note-closed "vulpea-note" (note))
(declare-function vulpea-note-created-at "vulpea-note" (note))
(declare-function vulpea-note-deadline "vulpea-note" (note))
(declare-function vulpea-note-file-title "vulpea-note" (note))
(declare-function vulpea-note-id "vulpea-note" (note))
(declare-function vulpea-note-level "vulpea-note" (note))
(declare-function vulpea-note-links "vulpea-note" (note))
(declare-function vulpea-note-meta "vulpea-note" (note))
(declare-function vulpea-note-modified-at "vulpea-note" (note))
(declare-function vulpea-note-outline-path "vulpea-note" (note))
(declare-function vulpea-note-path "vulpea-note" (note))
(declare-function vulpea-note-pos "vulpea-note" (note))
(declare-function vulpea-note-primary-title "vulpea-note" (note))
(declare-function vulpea-note-priority "vulpea-note" (note))
(declare-function vulpea-note-properties "vulpea-note" (note))
(declare-function vulpea-note-scheduled "vulpea-note" (note))
(declare-function vulpea-note-tags "vulpea-note" (note))
(declare-function vulpea-note-title "vulpea-note" (note))
(declare-function vulpea-note-todo "vulpea-note" (note))
(declare-function vulpea-ui-collection-open "vulpea-ui" (view))
(defvar init-local-vulpea-task-table-unavailable-reason
  "Vulpea setup has not completed"
  "Reason the Task Table cannot currently open, or nil when available.")

(defun init-local-vulpea--keyword-name (keyword)
  "Return the TODO state name from configured KEYWORD."
  (if (string-match "\\([^()]+\\)" keyword)
      (match-string 1 keyword)
    keyword))

(defun init-local-vulpea-task-workflow ()
  "Return Open Task and done states from the configured global Org workflow."
  (let (open done all)
    (dolist (spec (default-value 'org-todo-keywords))
      (let* ((states (mapcar #'init-local-vulpea--keyword-name (cdr spec)))
             (separator (seq-position states "|" #'string=))
             (sequence-open
              (if separator
                  (seq-take states separator)
                (butlast states)))
             (sequence-done
              (if separator
                  (seq-drop states (1+ separator))
                (last states))))
        (setq open (append open sequence-open)
              done (append done sequence-done)
              all (append all (remove "|" states)))))
    (list :open (delete-dups open)
          :done (delete-dups done)
          :all all)))

(defun init-local-vulpea-task-eligible-p (note)
  "Return non-nil when NOTE is an ID-bearing heading with a TODO state."
  (and (vulpea-note-id note)
       (> (or (vulpea-note-level note) 0) 0)
       (let ((todo (vulpea-note-todo note)))
         (and (stringp todo)
              (not (string-empty-p todo))))))

(defun init-local-vulpea-task-open-p (note &optional done-states)
  "Return non-nil when NOTE is open under DONE-STATES.
DONE-STATES defaults to the configured global Org workflow."
  (and (init-local-vulpea-task-eligible-p note)
       (not (member
             (vulpea-note-todo note)
             (or done-states
                 (plist-get (init-local-vulpea-task-workflow) :done))))))

(defun init-local-vulpea-task-todo-rank (state &optional open-states)
  "Return STATE's rank in OPEN-STATES.
OPEN-STATES defaults to the configured global Org workflow."
  (let ((states
         (or open-states
             (plist-get (init-local-vulpea-task-workflow) :open))))
    (or (seq-position states state #'string=)
        (length states))))

(defun init-local-vulpea-task-priority-rank (priority)
  "Return PRIORITY's Org rank, treating missing Priority as B."
  (let ((value (cond
                ((characterp priority) (upcase priority))
                ((and (stringp priority) (> (length priority) 0))
                 (upcase (aref priority 0))))))
    (cond
     ((eq value ?A) 0)
     ((or (eq value ?B) (null value)) 1)
     ((eq value ?C) 2)
     (t 3))))

(defun init-local-vulpea--sorted-open-notes (notes)
  "Return eligible Open Task NOTES in stable default order."
  (let* ((workflow (init-local-vulpea-task-workflow))
         (open-states (plist-get workflow :open))
         (done-states (plist-get workflow :done))
         (unknown-rank (length open-states))
         (todo-ranks (make-hash-table :test #'equal)))
    (dolist (state open-states)
      (puthash state
               (init-local-vulpea-task-todo-rank state open-states)
               todo-ranks))
    (mapcar
     (lambda (row) (aref row 0))
     (sort
      (cl-loop
       for note in notes
       for index from 0
       when (init-local-vulpea-task-open-p note done-states)
       collect
       (vector note
               (gethash (vulpea-note-todo note) todo-ranks unknown-rank)
               (init-local-vulpea-task-priority-rank
                (vulpea-note-priority note))
               (downcase (or (vulpea-note-title note) ""))
               index))
      (lambda (a b)
        (cond
         ((/= (aref a 1) (aref b 1)) (< (aref a 1) (aref b 1)))
         ((/= (aref a 2) (aref b 2)) (< (aref a 2) (aref b 2)))
         ((not (equal (aref a 3) (aref b 3)))
          (string-lessp (aref a 3) (aref b 3)))
         (t (< (aref a 4) (aref b 4)))))))))

(defun init-local-vulpea--display-note (note)
  "Return a Collection View snapshot of NOTE with correct Priority display."
  (make-vulpea-note
   :id (vulpea-note-id note)
   :path (vulpea-note-path note)
   :level (vulpea-note-level note)
   :pos (vulpea-note-pos note)
   :title (vulpea-note-title note)
   :primary-title (vulpea-note-primary-title note)
   :aliases (vulpea-note-aliases note)
   :tags (vulpea-note-tags note)
   :links (vulpea-note-links note)
   :properties (vulpea-note-properties note)
   :meta (vulpea-note-meta note)
   :todo (vulpea-note-todo note)
   ;; Native string sorting sees B while the Collection View displays blank.
   :priority (or (vulpea-note-priority note)
                 (propertize "B"
                             'display ""
                             'init-local-vulpea-missing-priority t))
   :scheduled (vulpea-note-scheduled note)
   :deadline (vulpea-note-deadline note)
   :closed (vulpea-note-closed note)
   :outline-path (vulpea-note-outline-path note)
   :attach-dir (vulpea-note-attach-dir note)
   :file-title (vulpea-note-file-title note)
   :created-at (vulpea-note-created-at note)
   :modified-at (vulpea-note-modified-at note)))

(defun init-local-vulpea-task-table-source ()
  "Query and return Open Tasks for the Task Table Collection View."
  (let ((notes (vulpea-db-query)))
    (when (and (null notes)
               (fboundp 'vulpea-db-worker-busy-p)
               (vulpea-db-worker-busy-p))
      (user-error
       "Vulpea index synchronization is still in progress; retry when it finishes"))
    (mapcar #'init-local-vulpea--display-note
            (init-local-vulpea--sorted-open-notes notes))))

(defun init-local-vulpea-task-table-view ()
  "Return the public Vulpea UI Collection View specification."
  (list :name "Task Table"
        :filter (list :source #'init-local-vulpea-task-table-source)
        :columns '((todo :name "TODO" :width 10)
                   (priority :name "Priority" :width 8)
                   (title :name "Task" :width 48)
                   (context :name "Source" :width 36))
        ;; The source supplies the composite default ordering.  Leaving this
        ;; nil also lets native header sorting replace it in either direction.
        :sort nil))

(defun init-local-vulpea-task-table-read-only ()
  "Reject a source mutation from the read-only Task Table."
  (interactive)
  (user-error "Task Table is read-only; edit the source Org heading"))

(defvar init-local-vulpea-task-table-read-only-mode-map
  (let ((map (make-sparse-keymap)))
    (dolist (command '(vulpea-ui-collection-add-tag
                       vulpea-ui-collection-remove-tag
                       vulpea-ui-collection-quick-edit
                       vulpea-ui-collection-remove-meta
                       vulpea-ui-collection-set-todo
                       vulpea-ui-collection-delete
                       vulpea-ui-collection-apply
                       vulpea-ui-collection-undo))
      (define-key map (vector 'remap command)
                  #'init-local-vulpea-task-table-read-only))
    map)
  "Keymap that keeps Task Table source data read-only.")

(define-minor-mode init-local-vulpea-task-table-read-only-mode
  "Keep the current Vulpea Collection View read-only."
  :init-value nil
  :lighter " TaskRO"
  :keymap init-local-vulpea-task-table-read-only-mode-map)

(defun init-local-vulpea--ensure-available ()
  "Raise an actionable error unless the Task Table can open."
  (when init-local-vulpea-task-table-unavailable-reason
    (user-error
     "Task Table unavailable: %s. Install vulpea and vulpea-ui, then run M-x vulpea-doctor"
     init-local-vulpea-task-table-unavailable-reason))
  (unless (and (fboundp 'vulpea-db-query)
               (fboundp 'vulpea-ui-collection-open))
    (user-error
     "Task Table unavailable: Vulpea APIs are missing. Install vulpea and vulpea-ui"))
  (unless (and (boundp 'vulpea-db-location)
               (stringp vulpea-db-location)
               (file-readable-p vulpea-db-location))
    (user-error
     (concat "Task Table unavailable: no readable Vulpea database. "
             "Let indexing finish, then run M-x vulpea-doctor"))))

;;;###autoload
(defun my/vulpea-task-table ()
  "Open the named read-only Task Table through Vulpea UI Collection View."
  (interactive)
  (init-local-vulpea--ensure-available)
  (condition-case err
      (progn
        (vulpea-ui-collection-open (init-local-vulpea-task-table-view))
        (let ((workflow (init-local-vulpea-task-workflow)))
          (setq-local org-todo-keywords-1 (plist-get workflow :all)
                      org-not-done-keywords (plist-get workflow :open)
                      org-done-keywords (plist-get workflow :done)))
        (init-local-vulpea-task-table-read-only-mode +1))
    (user-error
     (signal (car err) (cdr err)))
    (error
     (user-error
      "Task Table unavailable: database or Collection View failure: %s. Run M-x vulpea-doctor"
      (error-message-string err)))))

(defun init-local-vulpea--mark-unavailable (reason)
  "Record and warn that the optional integration is unavailable for REASON."
  (setq init-local-vulpea-task-table-unavailable-reason reason)
  (display-warning
   'init-local-vulpea
   (format
    "Vulpea Task Table unavailable: %s. Install vulpea and vulpea-ui, then run M-x vulpea-doctor"
    reason)
   :warning))

(defun init-local-vulpea--initialize ()
  "Initialize guarded Vulpea indexing and UI support."
  (cond
   ((version< emacs-version "29.1")
    (init-local-vulpea--mark-unavailable "Emacs 29.1 or newer is required"))
   ((not (fboundp 'maybe-require-package))
    (init-local-vulpea--mark-unavailable "the optional package installer is missing"))
   (t
    (setq vulpea-db-sync-directories
          (list (file-name-as-directory
                 (expand-file-name org-directory)))
          vulpea-db-location
          (expand-file-name "var/vulpea/vulpea.db" user-emacs-directory)
          vulpea-db-index-heading-level t
          vulpea-db-sync-scan-on-enable 'async)
    (cond
     ((not (maybe-require-package 'vulpea "2.6.0"))
      (init-local-vulpea--mark-unavailable "the vulpea package could not be installed"))
     ((not (maybe-require-package 'vulpea-ui))
      (init-local-vulpea--mark-unavailable "the vulpea-ui package could not be installed"))
     (t
      (condition-case err
          (progn
            (require 'vulpea)
            (require 'vulpea-ui)
            (vulpea-db-autosync-mode +1)
            (setq init-local-vulpea-task-table-unavailable-reason nil))
        (error
         (init-local-vulpea--mark-unavailable
          (format "initialization failed: %s" (error-message-string err))))))))))

(init-local-vulpea--initialize)

(provide 'init-local-vulpea)
;;; init-local-vulpea.el ends here
