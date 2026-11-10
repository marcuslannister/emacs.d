;;; init-local-anvil-tests.el --- Anvil switch tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-anvil-tests.el -f ert-run-tests-batch-and-exit
;; The tests never load Anvil.  They bind the two directory constants of the
;; module to temp folders, so no test can create a folder under a real config.
;;; Code:

(require 'ert)
(require 'cl-lib)
;; `display-warning' starts as an autoload; load it before a test stubs it.
(require 'warnings)

(defvar anvil-modules)
(defvar anvil-optional-modules)
(defvar anvil-server-install-directory)
(defvar anvil--enabled)

(load-file (expand-file-name "../user-lisp/init-local-anvil.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(defmacro init-local-anvil-tests--collecting (&rest body)
  "Run BODY; return the list of warnings it raised as (TYPE . MESSAGE)."
  (declare (indent 0))
  `(let ((collected nil))
     (cl-letf (((symbol-function 'display-warning)
                (lambda (type message &rest _) (push (cons type message) collected))))
       ,@body)
     (nreverse collected)))

(ert-deftest init-local-anvil-is-off-by-default ()
  (should-not (eval (car (get 'my/anvil-enabled 'standard-value)))))

(ert-deftest init-local-anvil-modules-leave-org-out ()
  (should-not (memq 'org my/anvil-modules))
  (should-not (memq 'org my/anvil-optional-modules)))

(ert-deftest init-local-anvil-setup-does-nothing-when-off ()
  (let ((my/anvil-enabled nil)
        (noninteractive nil)
        (system-type 'darwin)
        timers)
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest args) (push args timers))))
      (my/anvil-setup))
    (should-not timers)
    (should-not (fboundp 'anvil-server-process-jsonrpc))))

(ert-deftest init-local-anvil-setup-does-nothing-in-batch ()
  (let ((my/anvil-enabled t)
        (noninteractive t)
        (system-type 'darwin)
        timers)
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest args) (push args timers))))
      (my/anvil-setup))
    (should-not timers)))

(ert-deftest init-local-anvil-setup-schedules-the-start-when-on-macos ()
  (let ((my/anvil-enabled t)
        (noninteractive nil)
        (system-type 'darwin)
        timers)
    (unwind-protect
        (cl-letf (((symbol-function 'run-with-idle-timer)
                   (lambda (&rest args) (push args timers))))
          (my/anvil-setup)
          (should (equal timers '((2 nil my/anvil-start))))
          ;; A client that calls in early finds a function, not a void one.
          (should (fboundp 'anvil-server-process-jsonrpc)))
      (fmakunbound 'anvil-server-process-jsonrpc))))

(ert-deftest init-local-anvil-setup-warns-when-on-but-not-macos ()
  (let ((my/anvil-enabled t)
        (noninteractive nil)
        (system-type 'windows-nt)
        timers warnings)
    (setq warnings
          (init-local-anvil-tests--collecting
            (cl-letf (((symbol-function 'run-with-idle-timer)
                       (lambda (&rest args) (push args timers))))
              (my/anvil-setup))))
    (should-not timers)
    (should (= 1 (length warnings)))
    (should (string-match-p "macOS only" (cdr (car warnings))))))

(ert-deftest init-local-anvil-start-warns-and-goes-on-off-macos ()
  (let ((system-type 'windows-nt)
        (anvil--enabled nil)
        warnings)
    (setq warnings
          (init-local-anvil-tests--collecting
            (cl-letf (((symbol-function 'require)
                       (lambda (&rest _) (error "nothing may be loaded")))
                      ((symbol-function 'anvil-enable)
                       (lambda () (error "Anvil must not start"))))
              (my/anvil-start))))
    (should (= 1 (length warnings)))
    (should (string-match-p "macOS only" (cdr (car warnings))))))

(ert-deftest init-local-anvil-start-warns-when-the-package-is-missing ()
  (let ((system-type 'darwin)
        (anvil--enabled nil)
        warnings)
    (setq warnings
          (init-local-anvil-tests--collecting
            (let ((orig-require (symbol-function 'require)))
              (cl-letf (((symbol-function 'require)
                         (lambda (feature &rest args)
                           (if (eq feature 'anvil)
                               nil
                             (apply orig-require feature args)))))
                (my/anvil-start)))))
    (should (= 1 (length warnings)))
    (should (string-match-p "anvil.el is not installed" (cdr (car warnings))))))

(ert-deftest init-local-anvil-start-enables-without-org-and-keeps-state-in-var ()
  (let* ((tmp (make-temp-file "anvil-test-" t))
         (my/anvil-state-directory (file-name-as-directory (expand-file-name "state" tmp)))
         (my/anvil-bridge-directory (file-name-as-directory (expand-file-name "bridge" tmp)))
         (system-type 'darwin)
         (anvil--enabled nil)
         (anvil-modules nil)
         (anvil-optional-modules nil)
         (anvil-server-install-directory nil)
         (outer-dir user-emacs-directory)
         seen started)
    (unwind-protect
        (let ((orig-require (symbol-function 'require)))
          (cl-letf (((symbol-function 'require)
                     (lambda (feature &rest args)
                       (if (memq feature '(anvil anvil-server-commands))
                           feature
                         (apply orig-require feature args))))
                    ((symbol-function 'anvil-enable)
                     (lambda ()
                       (setq seen (list anvil-modules anvil-optional-modules
                                        user-emacs-directory
                                        anvil-server-install-directory))))
                    ((symbol-function 'anvil-server-start)
                     (lambda () (setq started t))))
            (my/anvil-start)
            (should started)
            (should-not (memq 'org (nth 0 seen)))
            (should-not (memq 'org (nth 1 seen)))
            (should (memq 'state (nth 1 seen)))
            ;; The state files of the modules land in the state folder.
            (should (equal my/anvil-state-directory (nth 2 seen)))
            (should (equal my/anvil-bridge-directory (nth 3 seen)))
            (should (file-directory-p my/anvil-state-directory))
            ;; The caller's value is back afterwards.
            (should (equal outer-dir user-emacs-directory))))
      (delete-directory tmp t))))

(ert-deftest init-local-anvil-start-is-idempotent ()
  (let ((anvil--enabled t)
        (system-type 'darwin))
    (cl-letf (((symbol-function 'require)
               (lambda (&rest _) (error "a second start must load nothing")))
              ((symbol-function 'anvil-enable)
               (lambda () (error "a second start must not enable again"))))
      (my/anvil-start))))

(ert-deftest init-local-anvil-early-call-starts-anvil-then-calls-the-real-function ()
  (unwind-protect
      (progn
        (defalias 'anvil-server-process-jsonrpc #'my/anvil--early-call)
        (cl-letf (((symbol-function 'my/anvil-start)
                   (lambda ()
                     ;; The real definition replaces the stub, as anvil-server.el does.
                     (fset 'anvil-server-process-jsonrpc
                           (lambda (request) (list 'real request))))))
          (should (equal '(real 7) (anvil-server-process-jsonrpc 7)))))
    (fmakunbound 'anvil-server-process-jsonrpc)))

(ert-deftest init-local-anvil-early-call-fails-clearly-when-anvil-does-not-start ()
  (unwind-protect
      (progn
        (defalias 'anvil-server-process-jsonrpc #'my/anvil--early-call)
        (cl-letf (((symbol-function 'my/anvil-start) #'ignore))
          (should-error (anvil-server-process-jsonrpc 7))))
    (fmakunbound 'anvil-server-process-jsonrpc)))

(provide 'init-local-anvil-tests)
;;; init-local-anvil-tests.el ends here
