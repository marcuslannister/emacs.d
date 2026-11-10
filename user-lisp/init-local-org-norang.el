;;; init-local-org-norang.el --- Clocking, reminders, and agenda order from the Norang guide -*- lexical-binding: t -*-

;; The functions below are adapted from "Organize Your Life In Plain Text!" by
;; Bernt Hansen: https://doc.norang.ca/org-mode.html
;; Copyright (C) 2013-2026 Bernt Hansen.
;; The guide licenses its code examples under the GNU General Public License,
;; version 3 or later.  This config uses version 3.  Keep this notice with the code.
;;
;; The guide names these functions bh/...; here they have the my/org-... prefix of
;; the Local layer.  The logic follows the guide, except where a comment says so.

;;; Commentary:
;; Three groups, all for a day of clocked, scheduled Org work:
;; - Clocking: `my/org-punch-in' and `my/org-punch-out' clock the Organization task
;;   by default, or the task at point.
;; - Reminders: `my/org-agenda-to-appt' rebuilds the appointment list from the
;;   agenda, so Emacs warns before a timed entry.
;; - Agenda order: `my/org-agenda-sort' puts plain tasks first, then deadlines,
;;   then scheduled entries.
;; The guide has more (a parent-task clock-in and a clock-out hook).  Only what
;; this config used is here.  The keys of the clock commands are in the leader table.
;;; Code:

(require 'org-macs)

(defvar appt-time-msg-list)
(defvar org-agenda-cmp-user-defined)
(declare-function appt-activate "appt")
(declare-function org-agenda-clock-in "org-agenda")
(declare-function org-agenda-remove-restriction-lock "org-agenda")
(declare-function org-agenda-to-appt "org-agenda")
(declare-function org-before-first-heading-p "org")
(declare-function org-clock-in "org-clock")
(declare-function org-clock-is-active "org-clock")
(declare-function org-clock-out "org-clock")
(declare-function org-get-at-bol "org")
(declare-function org-get-tags "org")
(declare-function org-id-find "org-id")
(declare-function my/hel-leader-bind "init-local-hel")

;;;; Clocking

(defcustom my/org-organization-task-id "6B6FB404-85A4-4212-B9D0-D4C2C527DD9D"
  "Org ID of the task that `my/org-punch-in' clocks in by default."
  :type 'string
  :group 'org-clock)

(defun my/org-clock-in-organization-task ()
  "Clock in the task with `my/org-organization-task-id', and make it the default task."
  (interactive)
  (let ((marker (org-id-find my/org-organization-task-id 'marker)))
    (unless marker
      (user-error "No Org entry has the ID %s" my/org-organization-task-id))
    (org-with-point-at marker
      (org-clock-in '(16)))))

(defun my/org-punch-in (arg)
  "Start clocking.  Clock in the Organization task, the default task.
With the prefix argument C-u (ARG is 4) on a task that has tags, in the agenda,
or at a heading in an Org buffer, ask which task to clock in instead."
  (interactive "p")
  (if (eq major-mode 'org-agenda-mode)
      (let* ((marker (org-get-at-bol 'org-hd-marker))
             (tags (org-with-point-at marker (org-get-tags))))
        (if (and (eq arg 4) tags)
            (org-agenda-clock-in '(16))
          (my/org-clock-in-organization-task)))
    (save-restriction
      (widen)
      (if (and (eq major-mode 'org-mode) (not (org-before-first-heading-p)) (eq arg 4))
          (org-clock-in '(16))
        (my/org-clock-in-organization-task)))))

(defun my/org-punch-out ()
  "Stop the running clock, and remove the restriction lock of the agenda."
  (interactive)
  (when (org-clock-is-active)
    (org-clock-out))
  (org-agenda-remove-restriction-lock))

(defun my/org-clock-in-switch-task ()
  "Run `org-clock-in' as with C-u: pick a task from the recent clocks."
  (interactive)
  (let ((current-prefix-arg '(4)))
    (call-interactively #'org-clock-in)))

;;;; Reminders

(defun my/org-agenda-to-appt ()
  "Erase all appointments, then rebuild them for today from the agenda.
A failure of the agenda only shows a message, so a bad file cannot stop Emacs."
  (interactive)
  (setq appt-time-msg-list nil)
  (condition-case err
      (org-agenda-to-appt)
    (error (message "org-agenda-to-appt failed: %s" (error-message-string err)))))

;; Rebuild the reminders every time the agenda shows.
(add-hook 'org-agenda-finalize-hook #'my/org-agenda-to-appt 'append)

;; Build them once after startup, when Emacs is idle.  The guide does it in
;; `after-init-hook', which loads Org and reads every agenda file before the first
;; key press.  The org timestamp regexps also trip the syntax-table cache when the
;; build runs during a GUI start.
(run-with-idle-timer 3 nil #'my/org-agenda-to-appt)

(appt-activate t)

;; If Emacs runs overnight, reset the appointments one minute after midnight.
;; shortcut: this runs once, as in the guide, so only the first night; add a repeat
;; of 86400 seconds if a daily reset is needed.
(run-at-time "24:01" nil #'my/org-agenda-to-appt)

;;;; Agenda order

(defun my/org-agenda--match-number (regexp date-str)
  "Return the number in the first group of REGEXP in DATE-STR, or nil."
  (when (string-match regexp date-str)
    (string-to-number (match-string 1 date-str))))

(defun my/org-agenda--due-deadline-p (date-str)
  "Return non-nil if DATE-STR is a deadline that is due today."
  (string-match-p "Deadline:" date-str))

(defun my/org-agenda--late-deadline (date-str)
  "Return the days that the deadline in DATE-STR is overdue, or nil."
  (my/org-agenda--match-number "\\([0-9]+\\) d\\. ago:" date-str))

(defun my/org-agenda--pending-deadline (date-str)
  "Return the days until the deadline in DATE-STR, or nil."
  (my/org-agenda--match-number "In \\([0-9]+\\)d\\.:" date-str))

(defun my/org-agenda--deadline-p (date-str)
  "Return non-nil if DATE-STR shows a deadline in any state."
  (or (my/org-agenda--due-deadline-p date-str)
      (my/org-agenda--late-deadline date-str)
      (my/org-agenda--pending-deadline date-str)))

(defun my/org-agenda--scheduled-today-p (date-str)
  "Return non-nil if DATE-STR is scheduled today."
  (string-match-p "Scheduled:" date-str))

(defun my/org-agenda--scheduled-late (date-str)
  "Return how many times DATE-STR is late for its schedule, or nil."
  (my/org-agenda--match-number "Sched\\.\\s-*\\([0-9]+\\)x:" date-str))

(defun my/org-agenda--scheduled-p (date-str)
  "Return non-nil if DATE-STR shows a schedule in any state."
  (or (my/org-agenda--scheduled-today-p date-str)
      (my/org-agenda--scheduled-late date-str)))

(defun my/org-agenda--plain-p (date-str)
  "Return non-nil if DATE-STR has no schedule and no deadline."
  (not (or (my/org-agenda--deadline-p date-str)
           (my/org-agenda--scheduled-p date-str))))

(defun my/org-agenda--sort-test (fn a b)
  "Compare the agenda strings A and B with the predicate FN.
Return -1 if only A matches, 1 if only B matches, and nil otherwise."
  (let ((match-a (funcall fn a))
        (match-b (funcall fn b)))
    (cond
     ((and match-a match-b) nil)
     (match-a -1)
     (match-b 1))))

(defun my/org-agenda--sort-test-num (fn compfn a b)
  "Compare the agenda strings A and B by the numbers that FN finds in them.
COMPFN orders two numbers.  Return -1 if A goes first, 1 if B goes first, and
nil if the numbers are equal or neither string has one."
  (let ((num-a (funcall fn a))
        (num-b (funcall fn b)))
    (cond
     ((and num-a num-b)
      (cond
       ((= num-a num-b) nil)
       ((funcall compfn num-a num-b) -1)
       (t 1)))
     (num-a -1)
     (num-b 1))))

(defun my/org-agenda-sort (a b)
  "Sort the agenda strings A and B: plain, due, late, today, scheduled late, pending.
Use it as `org-agenda-cmp-user-defined'."
  (or (my/org-agenda--sort-test #'my/org-agenda--plain-p a b)
      (my/org-agenda--sort-test #'my/org-agenda--due-deadline-p a b)
      (my/org-agenda--sort-test-num #'my/org-agenda--late-deadline #'> a b)
      (my/org-agenda--sort-test #'my/org-agenda--scheduled-today-p a b)
      (my/org-agenda--sort-test-num #'my/org-agenda--scheduled-late #'> a b)
      (my/org-agenda--sort-test-num #'my/org-agenda--pending-deadline #'< a b)))

;; View settings of the guide, adapted to the current Org variable names.
(use-package org-agenda
  :ensure nil
  :custom
  (org-agenda-show-future-repeats t)
  (org-agenda-show-all-dates t)
  (org-agenda-start-on-weekday 1)
  (org-agenda-time-grid '((daily today remove-match)
                          (900 1100 1300 1500 1700)
                          "......"
                          "----------------"))
  (org-agenda-tags-column -102)
  (org-agenda-cmp-user-defined #'my/org-agenda-sort))

;;;; Keys

;; The clock commands have no autoload before Org loads.
(dolist (command '(org-clock-update-time-maybe org-clock-in org-clock-out org-clock-goto))
  (autoload command "org-clock" nil t))

(my/hel-leader-bind
 "C-c a t" #'org-clock-update-time-maybe
 "C-c a i" #'org-clock-in
 "C-c a o" #'org-clock-out
 "C-c a p i" #'my/org-punch-in
 "C-c a p o" #'my/org-punch-out
 "C-c a g" #'org-clock-goto
 "C-c a s" #'my/org-clock-in-switch-task
 ;; The same keys with Control held, for the physical SPC c paths of Hel.
 "C-c C-t" #'org-clock-update-time-maybe
 "C-c C-i" #'org-clock-in
 "C-c C-o" #'org-clock-out
 "C-c C-p i" #'my/org-punch-in
 "C-c C-p o" #'my/org-punch-out
 "C-c C-g" #'org-clock-goto
 "C-c C-s" #'my/org-clock-in-switch-task)

(provide 'init-local-org-norang)
;;; init-local-org-norang.el ends here
