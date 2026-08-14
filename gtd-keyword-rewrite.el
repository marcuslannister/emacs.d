;;; gtd-keyword-rewrite.el --- One-shot rewrite of retired TODO keywords  -*- lexical-binding: t; -*-
;;; Commentary:
;; Record of the 20-heading rewrite in ~/org/.  Run once as:
;;
;;   emacs -Q --batch -l gtd-keyword-rewrite.el
;;
;; Selects headings with `org-map-entries', matched on the TODO keyword, with
;; logging inhibited.  Not a text replace: the old keywords appear far more
;; often in prose and logbooks than in headings.  Takes the five file names
;; literally, so `.stversions', `org-supertag' and archives are excluded by
;; construction.
;;; Code:

(require 'org)

(defconst gtd-keyword-rewrite-mapping
  '(("HOLD" . "WAIT")
    ("WAITING" . "WAIT")
    ("CANCELLED" . "CNCL"))
  "Old TODO keyword to new TODO keyword.")

(defconst gtd-keyword-rewrite-files
  (mapcar (lambda (name)
            (expand-file-name name "~/org/"))
          '("software.org" "network.org" "bookmark.org" "ai.org" "hardware.org"))
  "The five topic files that hold the 20 headings to rewrite.")

(defun gtd-keyword-rewrite--run ()
  "Rewrite retired TODO keywords in `gtd-keyword-rewrite-files'."
  (let ((org-inhibit-logging t)
        (org-todo-keywords '((sequence "TODO" "NEXT" "WAIT" "HOLD" "WAITING"
                                       "|" "DONE" "CNCL" "CANCELLED")))
        (changed 0))
    (dolist (file gtd-keyword-rewrite-files)
      (unless (file-readable-p file)
        (error "gtd-keyword-rewrite: missing file %s" file))
      (with-current-buffer (find-file-noselect file)
        (org-mode)
        (org-map-entries
         (lambda ()
           (let* ((old (org-get-todo-state))
                  (new (cdr (assoc old gtd-keyword-rewrite-mapping))))
             (unless new
               (error "gtd-keyword-rewrite: unexpected keyword %S in %s"
                      old file))
             (message "%s:%d  %s -> %s  %s"
                      file (line-number-at-pos) old new
                      (org-get-heading t t t t))
             (org-todo new)
             (setq changed (1+ changed))))
         "/HOLD|WAITING|CANCELLED" 'file)
        (save-buffer)))
    (message "gtd-keyword-rewrite: changed %d headings" changed)))

(gtd-keyword-rewrite--run)

(provide 'gtd-keyword-rewrite)
;;; gtd-keyword-rewrite.el ends here
