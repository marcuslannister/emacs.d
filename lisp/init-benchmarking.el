;;; init-benchmarking.el --- Measure startup and require times -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defun sanityinc/time-subtract-millis (b a)
  (* 1000.0 (float-time (time-subtract b a))))


(defvar sanityinc/require-times nil
  "A list of (FEATURE LOAD-START-TIME LOAD-DURATION).
LOAD-DURATION is the time taken in milliseconds to load FEATURE.")

(defun sanityinc/require-times-wrapper (orig feature &rest args)
  "Note in `sanityinc/require-times' the time taken to require each feature."
  (let* ((already-loaded (memq feature features))
         (require-start-time (and (not already-loaded) (current-time))))
    (prog1
        (apply orig feature args)
      (when (and (not already-loaded) (memq feature features))
        (let ((time (sanityinc/time-subtract-millis (current-time) require-start-time)))
          (add-to-list 'sanityinc/require-times
                       (list feature require-start-time time)
                       t))))))

(advice-add 'require :around 'sanityinc/require-times-wrapper)


(define-derived-mode sanityinc/require-times-mode tabulated-list-mode "Require-Times"
  "Show times taken to `require' packages."
  (setq tabulated-list-format
        [("Start time (ms)" 20 sanityinc/require-times-sort-by-start-time-pred)
         ("Feature" 30 t)
         ("Time (ms)" 12 sanityinc/require-times-sort-by-load-time-pred)
         ("Self (ms)" 12 sanityinc/require-times-sort-by-self-time-pred)])
  (setq tabulated-list-sort-key (cons "Start time (ms)" nil))
  ;; (setq tabulated-list-padding 2)
  (setq tabulated-list-entries #'sanityinc/require-times-tabulated-list-entries)
  (tabulated-list-init-header)
  (when (fboundp 'tablist-minor-mode)
    (tablist-minor-mode)))

(defun sanityinc/require-times-sort-by-start-time-pred (entry1 entry2)
  (< (string-to-number (elt (nth 1 entry1) 0))
     (string-to-number (elt (nth 1 entry2) 0))))

(defun sanityinc/require-times-sort-by-load-time-pred (entry1 entry2)
  (> (string-to-number (elt (nth 1 entry1) 2))
     (string-to-number (elt (nth 1 entry2) 2))))

(defun sanityinc/require-times-sort-by-self-time-pred (entry1 entry2)
  (> (string-to-number (elt (nth 1 entry1) 3))
     (string-to-number (elt (nth 1 entry2) 3))))

(defun sanityinc/require-times-self-times ()
  "Return a hash table from feature to its load time minus nested requires, in ms.
`sanityinc/require-times' durations include every feature a file requires, so
they overlap.  A feature is nested in the latest earlier one that was still
loading when it started."
  (let ((self (make-hash-table :test 'eq))
        (stack nil))
    (dolist (entry (sort (copy-sequence sanityinc/require-times)
                         (lambda (a b) (time-less-p (nth 1 a) (nth 1 b)))))
      (pcase-let ((`(,feature ,start ,millis) entry))
        (while (and stack
                    (not (time-less-p start (nth 1 (car stack))))
                    (>= (sanityinc/time-subtract-millis start (nth 1 (car stack)))
                        (nth 2 (car stack))))
          (pop stack))
        (puthash feature millis self)
        (when stack
          (cl-decf (gethash (car (car stack)) self) millis))
        (push entry stack)))
    self))

(defun sanityinc/require-times-tabulated-list-entries ()
  (let ((self (sanityinc/require-times-self-times)))
    (cl-loop for (feature start-time millis) in sanityinc/require-times
             with order = 0
             do (cl-incf order)
             collect (list order
                           (vector
                            (format "%.3f" (sanityinc/time-subtract-millis start-time before-init-time))
                            (symbol-name feature)
                            (format "%.3f" millis)
                            (format "%.3f" (gethash feature self millis)))))))

(defun sanityinc/require-times ()
  "Show a tabular view of how long various libraries took to load."
  (interactive)
  (with-current-buffer (get-buffer-create "*Require Times*")
    (sanityinc/require-times-mode)
    (tabulated-list-revert)
    (display-buffer (current-buffer))))




(defun sanityinc/show-init-time ()
  (message "init completed in %.2fms"
           (sanityinc/time-subtract-millis after-init-time before-init-time)))

(add-hook 'after-init-hook 'sanityinc/show-init-time)


(provide 'init-benchmarking)
;;; init-benchmarking.el ends here
