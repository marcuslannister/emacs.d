;;; init-local-org-norang-tests.el --- Norang clocking, reminder, and agenda tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-org-norang-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'use-package)

(defvar appt-time-msg-list)

(defvar init-local-org-norang-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-org-norang-tests--keys)))

;; Load with deferral and without the timers and the appointment hooks of the module.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil))
  (cl-letf (((symbol-function 'appt-activate) #'ignore)
            ((symbol-function 'run-at-time) #'ignore)
            ((symbol-function 'run-with-idle-timer) #'ignore))
    (load (expand-file-name "../user-lisp/init-local-org-norang.el"
                            (file-name-directory (or load-file-name buffer-file-name)))
          nil t)))

;;;; Agenda order

(ert-deftest init-local-org-norang-sort-puts-plain-tasks-first ()
  (should (eq -1 (my/org-agenda-sort "  Task" "  Deadline:  Task")))
  (should (eq 1 (my/org-agenda-sort "  Scheduled:  Task" "  Task"))))

(ert-deftest init-local-org-norang-sort-puts-deadlines-before-schedules ()
  (should (eq -1 (my/org-agenda-sort "  Deadline:  A" "  Scheduled:  B")))
  (should (eq 1 (my/org-agenda-sort "  Scheduled:  B" "  Deadline:  A"))))

(ert-deftest init-local-org-norang-sort-puts-the-most-late-deadline-first ()
  (should (eq 1 (my/org-agenda-sort "  3 d. ago:  A" "  5 d. ago:  B")))
  (should (eq -1 (my/org-agenda-sort "  5 d. ago:  B" "  3 d. ago:  A")))
  (should-not (my/org-agenda-sort "  3 d. ago:  A" "  3 d. ago:  B")))

(ert-deftest init-local-org-norang-sort-puts-the-nearest-pending-deadline-first ()
  (should (eq -1 (my/org-agenda-sort "  In 2d.:  A" "  In 5d.:  B")))
  (should (eq 1 (my/org-agenda-sort "  In 5d.:  B" "  In 2d.:  A"))))

(ert-deftest init-local-org-norang-sort-puts-the-most-late-schedule-first ()
  (should (eq 1 (my/org-agenda-sort "  Sched. 2x:  A" "  Sched. 7x:  B"))))

(ert-deftest init-local-org-norang-sort-keeps-equal-entries ()
  (should-not (my/org-agenda-sort "  Deadline:  A" "  Deadline:  B")))

;;;; Clocking

(ert-deftest init-local-org-norang-organization-task-needs-a-known-id ()
  (cl-letf (((symbol-function 'org-id-find) (lambda (&rest _) nil)))
    (should-error (my/org-clock-in-organization-task) :type 'user-error)))

(ert-deftest init-local-org-norang-organization-task-clocks-in-as-default ()
  (let (calls)
    (with-temp-buffer
      (insert "* Organization\n")
      (let ((marker (copy-marker (point-min))))
        (cl-letf (((symbol-function 'org-id-find) (lambda (&rest _) marker))
                  ((symbol-function 'org-clock-in)
                   (lambda (&rest args) (push (list (current-buffer) args) calls))))
          (my/org-clock-in-organization-task))))
    (should (equal '((16)) (cadr (car calls))))))

(defmacro init-local-org-norang-tests--punch (arg &rest body)
  "Run `my/org-punch-in' with ARG in an Org buffer at a heading, with BODY's stubs."
  (declare (indent 1))
  `(let (organization clock-in)
     (with-temp-buffer
       (org-mode)
       (insert "* Heading\n")
       (cl-letf (((symbol-function 'my/org-clock-in-organization-task)
                  (lambda () (setq organization t)))
                 ((symbol-function 'org-clock-in) (lambda (&rest args) (setq clock-in args))))
         (my/org-punch-in ,arg)))
     ,@body))

(ert-deftest init-local-org-norang-punch-in-clocks-the-organization-task ()
  (init-local-org-norang-tests--punch 1
    (should organization)
    (should-not clock-in)))

(ert-deftest init-local-org-norang-punch-in-with-prefix-asks-for-a-task ()
  (init-local-org-norang-tests--punch 4
    (should-not organization)
    (should (equal '((16)) clock-in))))

(ert-deftest init-local-org-norang-punch-in-in-the-agenda-honors-the-tags ()
  (let (organization agenda-clock-in)
    (cl-letf (((symbol-function 'my/org-clock-in-organization-task)
               (lambda () (setq organization t)))
              ((symbol-function 'org-agenda-clock-in)
               (lambda (&rest args) (setq agenda-clock-in args))))
      (with-temp-buffer
        (org-mode)
        (insert "* TODO Task :work:\n")
        (let ((marker (copy-marker (point-min))))
          (with-temp-buffer
            (insert (propertize "agenda line" 'org-hd-marker marker))
            (goto-char (point-min))
            (let ((major-mode 'org-agenda-mode))
              (my/org-punch-in 4)
              (should (equal '((16)) agenda-clock-in))
              (should-not organization)
              (my/org-punch-in 1)
              (should organization))))))))

(ert-deftest init-local-org-norang-punch-out-stops-the-clock-and-the-lock ()
  (let (out unlocked)
    (cl-letf (((symbol-function 'org-clock-is-active) (lambda () t))
              ((symbol-function 'org-clock-out) (lambda (&rest _) (setq out t)))
              ((symbol-function 'org-agenda-remove-restriction-lock)
               (lambda (&rest _) (setq unlocked t))))
      (my/org-punch-out))
    (should out)
    (should unlocked)))

(ert-deftest init-local-org-norang-punch-out-without-a-clock-only-removes-the-lock ()
  (let (out unlocked)
    (cl-letf (((symbol-function 'org-clock-is-active) (lambda () nil))
              ((symbol-function 'org-clock-out) (lambda (&rest _) (setq out t)))
              ((symbol-function 'org-agenda-remove-restriction-lock)
               (lambda (&rest _) (setq unlocked t))))
      (my/org-punch-out))
    (should-not out)
    (should unlocked)))

;;;; Reminders

(ert-deftest init-local-org-norang-appt-rebuild-clears-then-builds ()
  (let ((appt-time-msg-list '(old)) built)
    (cl-letf (((symbol-function 'org-agenda-to-appt)
               (lambda (&rest _) (setq built appt-time-msg-list))))
      (my/org-agenda-to-appt))
    (should (null built))))

(ert-deftest init-local-org-norang-appt-rebuild-survives-an-agenda-error ()
  (cl-letf (((symbol-function 'org-agenda-to-appt) (lambda (&rest _) (error "bad file")))
            ((symbol-function 'message) #'ignore))
    (should-not (my/org-agenda-to-appt))))

;;;; Keys

(ert-deftest init-local-org-norang-clock-commands-exist-before-org-loads ()
  (should init-local-org-norang-tests--keys)
  (dolist (binding init-local-org-norang-tests--keys)
    (should (fboundp (cdr binding)))))

(provide 'init-local-org-norang-tests)
;;; init-local-org-norang-tests.el ends here
