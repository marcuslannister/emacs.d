;;; init-local-windows-native-comp-tests.el --- byte-code-only tests -*- lexical-binding: t; -*-

(require 'ert)

(defconst init-local-windows-native-comp-tests--file
  (expand-file-name "../user-lisp/init-local-windows-native-comp.el"
                    (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest init-local-windows-native-comp-turns-native-code-off ()
  "The helper turns off JIT and trampolines, and moves the .eln lookup away."
  (let ((native-comp-jit-compilation t)
        (native-comp-enable-subr-trampolines t)
        (native-comp-eln-load-path '("/eln-cache/" "/system/native-lisp/"))
        (user-emacs-directory (file-name-as-directory (make-temp-file "wnc" t))))
    (unwind-protect
        (progn
          (load init-local-windows-native-comp-tests--file nil t)
          (should-not native-comp-jit-compilation)
          (should-not native-comp-enable-subr-trampolines)
          (should (= 1 (length native-comp-eln-load-path)))
          (should (file-in-directory-p (car native-comp-eln-load-path) user-emacs-directory)))
      (delete-directory user-emacs-directory t))))

(defun init-local-windows-native-comp-tests--org-native-p (&rest args)
  "Return the printed `native-comp-function-p' of `org-mode' in a child Emacs run with ARGS."
  (with-temp-buffer
    ;; Discard stderr, so a warning cannot change the printed value.
    (apply #'call-process (expand-file-name invocation-name invocation-directory)
           nil '(t nil) nil "-Q" "--batch"
           (append args
                   '("--eval" "(progn (require 'org)
                                     (princ (native-comp-function-p
                                             (symbol-function 'org-mode))))")))
    (buffer-string)))

(ert-deftest init-local-windows-native-comp-loads-built-in-library-as-byte-code ()
  "With the helper loaded, a library that Emacs ships as .eln loads as .elc."
  ;; Without the helper, org must load as native code, or the test proves nothing.
  (skip-unless (equal (init-local-windows-native-comp-tests--org-native-p) "t"))
  (should (equal (init-local-windows-native-comp-tests--org-native-p
                  "-l" init-local-windows-native-comp-tests--file)
                 "nil")))
