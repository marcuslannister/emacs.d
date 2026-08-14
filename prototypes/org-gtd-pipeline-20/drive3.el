;;; drive3.el --- PROTOTYPE driver, part 3 -- WIPE ME  -*- lexical-binding: t; -*-

;; How does the refile prompt actually feel at this store's size?

(load "/tmp/org-gtd-proto/emacs/init.el")
(defun proto-say (fmt &rest args) (princ (concat (apply #'format fmt args) "\n")))

(proto-say "\n========== refile prompt cost and legibility ==========")
(let* ((org-refile-target-verify-function
        (org-gtd-refile--make-verify-function org-gtd-action))
       (org-refile-targets (append org-refile-targets '((org-agenda-files :maxlevel . 9))))
       (org-refile-use-outline-path t)
       (org-outline-path-complete-in-steps nil)
       (t0 (current-time))
       (targets (org-refile-get-targets))
       (elapsed (float-time (time-since t0)))
       (labels (mapcar #'car targets)))
  (proto-say "candidates: %d, built in %.3f s (cold)" (length targets) elapsed)
  (setq t0 (current-time))
  (org-refile-get-targets)
  (proto-say "second build: %.3f s" (float-time (time-since t0)))
  (proto-say "org-refile-use-outline-path is forced to `t' -> labels carry no file name:")
  (dolist (l (seq-take labels 3)) (proto-say "    %s" l))
  ;; how many labels are ambiguous across files?
  (let ((seen (make-hash-table :test 'equal)) (dupes 0))
    (dolist (l labels)
      (if (gethash l seen) (setq dupes (1+ dupes)) (puthash l t seen)))
    (proto-say "duplicate labels (same text, different file): %d" dupes)))

(proto-say "\n========== what org-gtd-update-ack is for ==========")
(proto-say "org-gtd-update-ack = %S" (bound-and-true-p org-gtd-update-ack))
(proto-say "%s"
           (or (ignore-errors
                 (documentation-property 'org-gtd-update-ack 'variable-documentation))
               "<undocumented>"))
