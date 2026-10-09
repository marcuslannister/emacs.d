;;; init-local-idle-tests.el --- Idle loading tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Load only the helper, without running the rest of init-local.el.
(with-temp-buffer
  (insert-file-contents
   (expand-file-name "../lisp/init-local.el"
                     (file-name-directory load-file-name)))
  (search-forward "(defun init-local--require-when-idle ")
  (beginning-of-line)
  (eval (read (current-buffer)) t))

(ert-deftest init-local-require-when-idle-batch-requires-at-once ()
  "A batch run has no idle time, so the feature loads and no timer starts."
  (let ((noninteractive t) required timers)
    (cl-letf (((symbol-function 'require)
               (lambda (feature &rest _) (push feature required)))
              ((symbol-function 'run-with-idle-timer)
               (lambda (&rest args) (push args timers))))
      (init-local--require-when-idle 'some-feature 2))
    (should (equal '(some-feature) required))
    (should-not timers)))

(ert-deftest init-local-require-when-idle-interactive-sets-timer ()
  "An interactive session waits DELAY seconds idle, then requires the feature."
  (let ((noninteractive nil) required timers)
    (cl-letf (((symbol-function 'require)
               (lambda (feature &rest _) (push feature required)))
              ((symbol-function 'run-with-idle-timer)
               (lambda (&rest args) (push args timers))))
      (init-local--require-when-idle 'some-feature 2))
    (should-not required)
    (should (= 1 (length timers)))
    (pcase-let ((`(,delay ,repeat ,fn . ,args) (car timers)))
      (should (= 2 delay))
      (should-not repeat)
      (cl-letf (((symbol-function 'require)
                 (lambda (feature &rest _) (push feature required))))
        (apply fn args))
      (should (equal '(some-feature) required)))))
