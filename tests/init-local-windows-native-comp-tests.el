;;; init-local-windows-native-comp-tests.el --- MINGW64 libgccjit lookup tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst init-local-windows-native-comp-tests--file
  (expand-file-name "../user-lisp/init-local-windows-native-comp.el"
                    (file-name-directory (or load-file-name buffer-file-name))))

(defun init-local-windows-native-comp-tests--load (path)
  "Load the lookup file with PATH, a fresh Emacs dir and no Scoop.
Return the resulting PATH, JIT flag, trampoline flag and warning type."
  (let* ((emacs-dir (make-temp-file "wnc-emacs" t))
         (invocation-directory (file-name-as-directory emacs-dir))
         (process-environment (append (list (concat "PATH=" path)
                                            (concat "SCOOP=" emacs-dir "/no-scoop"))
                                      process-environment))
         (native-comp-jit-compilation t)
         (native-comp-enable-subr-trampolines t)
         (delayed-warnings-list nil))
    (unwind-protect
        (progn
          (load init-local-windows-native-comp-tests--file nil t)
          (list (getenv "PATH") native-comp-jit-compilation
                native-comp-enable-subr-trampolines (caar delayed-warnings-list)))
      (delete-directory emacs-dir t))))

(ert-deftest init-local-windows-native-comp-finds-mingw64-beside-path-entry ()
  "An MSYS2 ucrt64/bin on PATH leads to its mingw64/bin, which goes first."
  (let* ((root (make-temp-file "wnc-msys64" t))
         (ucrt (expand-file-name "ucrt64/bin" root))
         (mingw (expand-file-name "mingw64/bin" root)))
    (unwind-protect
        (progn
          (make-directory ucrt t)
          (make-directory mingw t)
          (write-region "" nil (expand-file-name "libgccjit-0.dll" mingw))
          (pcase-let ((`(,path ,jit ,tramp ,warning)
                       (init-local-windows-native-comp-tests--load ucrt)))
            (should (string-prefix-p (convert-standard-filename
                                      (file-name-as-directory mingw))
                                     path))
            (should jit)
            (should tramp)
            (should-not warning)))
      (delete-directory root t))))

(ert-deftest init-local-windows-native-comp-off-without-mingw64 ()
  "Without a MINGW64 libgccjit, native compilation is off and a warning queues."
  (let ((empty (make-temp-file "wnc-empty" t)))
    (unwind-protect
        (pcase-let ((`(,path ,jit ,tramp ,warning)
                     (init-local-windows-native-comp-tests--load empty)))
          (should (equal path empty))
          (should-not jit)
          (should-not tramp)
          (should (eq warning 'windows-native-comp)))
      (delete-directory empty t))))

(ert-deftest init-local-windows-native-comp-skips-bundled-libgccjit ()
  "A build with libgccjit beside emacs.exe keeps PATH and native compilation."
  (let ((empty (make-temp-file "wnc-empty" t)))
    (unwind-protect
        (cl-letf* ((orig (symbol-function 'file-exists-p))
                   ((symbol-function 'file-exists-p)
                    (lambda (f) (or (string-suffix-p "libgccjit-0.dll" f)
                                    (funcall orig f)))))
          (pcase-let ((`(,path ,jit ,_ ,warning)
                       (init-local-windows-native-comp-tests--load empty)))
            (should (equal path empty))
            (should jit)
            (should-not warning)))
      (delete-directory empty t))))
