;;; init-local-case-guard-tests.el --- Case guard regression tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-case-guard-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)

(let* ((root (file-name-directory
              (directory-file-name
               (file-name-directory (or load-file-name buffer-file-name)))))
       (user-emacs-directory root))
  (load (expand-file-name "lisp/init-local-case-guard.el" root) nil t))

(defmacro init-local-case-guard-tests--with-org-file (contents &rest body)
  "Visit a temporary guarded file holding CONTENTS, then run BODY."
  (declare (indent 1))
  `(let* ((directory (make-temp-file "case-guard-test-" t))
          (file (expand-file-name "software.org" directory))
          (ml-case-guard-directories (list directory))
          (ml-case-guard-log-file (expand-file-name "case-guard.log" directory))
          ;; The guard must never prompt in batch, so simulate an interactive
          ;; session.  `init-local-case-guard-batch-refuses-without-a-prompt'
          ;; covers the batch behaviour on its own.
          (noninteractive nil))
     (unwind-protect
         (with-current-buffer (find-file-noselect file)
           (unwind-protect
               (progn (insert ,contents)
                      (ml-case-guard--watch-buffer)
                      ,@body)
             (set-buffer-modified-p nil)
             (kill-buffer)))
       (delete-directory directory t))))

(defun init-local-case-guard-tests--lines (&rest lines)
  "Join LINES into buffer text, one Org line each."
  (mapconcat #'identity (append lines '("")) "\n"))

(defconst init-local-case-guard-tests--healthy
  (init-local-case-guard-tests--lines
   "#+title: software"
   ""
   "* NEXT Add a raycast plugin"
   ":PROPERTIES:"
   ":ORG_GTD:  Actions"
   ":TRIGGER:  self org-gtd-update-project-after-task-done!"
   ":END:"
   ":LOGBOOK:"
   "- State \"DONE\"       from \"TODO\"       [2026-08-23 Sun 21:15]"
   ":END:")
  "An undamaged Org task, in the shape org-gtd writes it.")

(defconst init-local-case-guard-tests--damaged
  (init-local-case-guard-tests--lines
   "#+TITLE: SOFTWARE"
   ""
   "* NEXT ADD A RAYCAST PLUGIN"
   ":PROPERTIES:"
   ":ORG_GTD:  ACTIONS"
   ":ORG_GTD_PROJECT: EMACS"
   ":TRIGGER:  SELF ORG-GTD-UPDATE-PROJECT-AFTER-TASK-DONE!"
   ":END:"
   ":LOGBOOK:"
   "- STATE \"DONE\"       FROM \"TODO\"       [2026-08-23 SUN 21:15]"
   "- STATE \"DONE\"       FROM \"TODO\"       [2026-08-24 MON 21:15]"
   "- STATE \"DONE\"       FROM \"TODO\"       [2026-08-25 TUE 21:15]"
   "- STATE \"DONE\"       FROM \"TODO\"       [2026-08-26 WED 21:15]"
   "- STATE \"DONE\"       FROM \"TODO\"       [2026-08-27 THU 21:15]"
   ":END:")
  "The same task after an accidental upcase.")

(defun init-local-case-guard-tests--filler ()
  "Return text longer than the region threshold, for guard tests."
  (make-string (* 4 ml-case-guard-region-threshold) ?a))

(ert-deftest init-local-case-guard-blocks-save-of-upcased-file ()
  "Saving upcased metadata must fail and must leave the file unwritten."
  (init-local-case-guard-tests--with-org-file
      init-local-case-guard-tests--damaged
    ;; Keep clear of the threshold, so trimming the fixture cannot mask a fault.
    (should (> (ml-case-guard-canary-count) ml-case-guard-canary-threshold))
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
      (should-error (save-buffer) :type 'user-error))
    (should (buffer-modified-p))
    (should-not (file-exists-p (buffer-file-name)))))

(ert-deftest init-local-case-guard-allows-save-of-healthy-file ()
  "An undamaged guarded file must still save without a prompt."
  (init-local-case-guard-tests--with-org-file
      init-local-case-guard-tests--healthy
    (should (= 0 (ml-case-guard-canary-count)))
    (cl-letf (((symbol-function 'yes-or-no-p)
               (lambda (&rest _) (error "Must not prompt"))))
      (save-buffer))
    (should (file-exists-p (buffer-file-name)))
    (should-not (buffer-modified-p))))

(ert-deftest init-local-case-guard-refuses-large-upcase-region ()
  "A large `upcase-region' on a guarded file must not change the buffer."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    (let ((before (buffer-string)))
      (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
        (should-error (upcase-region (point-min) (point-max)) :type 'user-error))
      (should (equal before (buffer-string))))))

(ert-deftest init-local-case-guard-refuses-large-upcase-word ()
  "`upcase-word' is a separate subr and must not slip past the guard.
This is the route plain \\[upcase-word] and `upcase-dwim' take with no region."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    (let ((before (buffer-string)))
      (goto-char (point-min))
      (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
        (should-error (upcase-word 4000) :type 'user-error))
      (should (equal before (buffer-string))))))

(ert-deftest init-local-case-guard-allows-small-upcase-word ()
  "One ordinary word must not raise a prompt."
  (init-local-case-guard-tests--with-org-file
      "hello world"
    (goto-char (point-min))
    (cl-letf (((symbol-function 'yes-or-no-p)
               (lambda (&rest _) (error "Must not prompt"))))
      (upcase-word 1))
    (should (equal (buffer-string) "HELLO world"))))

(ert-deftest init-local-case-guard-allows-confirmed-upcase-region ()
  "A confirmed large `upcase-region' must still run."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
      (upcase-region (point-min) (point-max)))
    (should (equal (buffer-string) (upcase (init-local-case-guard-tests--filler))))))

(ert-deftest init-local-case-guard-ignores-unguarded-buffers ()
  "A buffer outside `ml-case-guard-directories' must be left alone."
  (let ((ml-case-guard-directories (list (expand-file-name "org/" "~"))))
    (with-temp-buffer
      (insert (make-string (* 4 ml-case-guard-region-threshold) ?a))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) (error "Must not prompt"))))
        (upcase-region (point-min) (point-max)))
      (should (equal (buffer-string)
                     (make-string (* 4 ml-case-guard-region-threshold) ?A))))))

(ert-deftest init-local-case-guard-logs-a-refusal-with-a-backtrace ()
  "A refusal must leave a log entry that names the caller."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
      (ignore-errors (upcase-region (point-min) (point-max))))
    (should (file-exists-p ml-case-guard-log-file))
    (with-temp-buffer
      (insert-file-contents ml-case-guard-log-file)
      (should (string-match-p "refused" (buffer-string)))
      (should (string-match-p "upcase-region" (buffer-string))))))

(ert-deftest init-local-case-guard-logs-an-unattributed-rewrite ()
  "A large equal-length rewrite must be logged even when no case command ran.
This is the only layer that can name the still-unknown caller."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    ;; Rewrite in place, the way a casify does: one change that puts back
    ;; exactly as many characters as it took out.  A delete plus an insert is
    ;; two changes of unequal length and is deliberately not the signature.
    (subst-char-in-region (point-min) (point-max) ?a ?B)
    (should (file-exists-p ml-case-guard-log-file))
    (with-temp-buffer
      (insert-file-contents ml-case-guard-log-file)
      (should (string-match-p "equal-length-rewrite" (buffer-string))))))

(ert-deftest init-local-case-guard-follows-indirect-buffers ()
  "An indirect buffer carries no file name, but org-gtd clarifies tasks in one."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    (let ((indirect (make-indirect-buffer (current-buffer) "case-guard-indirect")))
      (unwind-protect
          (with-current-buffer indirect
            (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
              (should-error (upcase-region (point-min) (point-max))
                            :type 'user-error)))
        (kill-buffer indirect)))))

(ert-deftest init-local-case-guard-batch-refuses-without-a-prompt ()
  "A batch session must refuse instead of blocking on a prompt."
  (init-local-case-guard-tests--with-org-file
      (init-local-case-guard-tests--filler)
    (let ((noninteractive t))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) (error "Must not prompt in batch"))))
        (should-error (upcase-region (point-min) (point-max))
                      :type 'user-error)))))

(ert-deftest init-local-case-guard-escape-hatch-removes-every-advice ()
  "The documented escape hatch must clear all of the advice, not just the save."
  (let ((guarded (copy-sequence ml-case-guard-guarded-functions)))
    (unwind-protect
        (progn
          (dolist (f guarded) (advice-remove f 'ml-case-guard))
          (dolist (f guarded)
            (should-not (advice-member-p 'ml-case-guard f))))
      (dolist (command '(upcase-region downcase-region
                         capitalize-region upcase-initials-region))
        (advice-add command :around #'ml-case-guard--region
                    '((name . ml-case-guard))))
      (dolist (command '(upcase-word downcase-word capitalize-word))
        (advice-add command :around #'ml-case-guard--word
                    '((name . ml-case-guard))))
      (advice-add 'basic-save-buffer :before #'ml-case-guard--check-save
                  '((name . ml-case-guard))))))

(provide 'init-local-case-guard-tests)
;;; init-local-case-guard-tests.el ends here
