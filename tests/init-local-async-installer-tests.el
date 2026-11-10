;;; init-local-async-installer-tests.el --- Pinned Git package tests -*- lexical-binding: t; -*-
;;; Commentary:
;; These tests need the async and async-installer packages that ./test-startup.sh
;; installs under elpa/.  Run: emacs -Q --batch -l tests/init-local-async-installer-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'ert)
(require 'cl-lib)
;; `display-warning' and `package-vc-install' start as autoloads.  The first
;; call of one loads its file, and the real definition then replaces a stub
;; set with `cl-letf' (the first test in a process lost its warning this way).
;; Load both files now, before any test stubs them.
(require 'warnings)
(require 'package)
(require 'package-vc)

(let ((root (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))))
  (dolist (dir (file-expand-wildcards (expand-file-name "elpa/async*" root)))
    (add-to-list 'load-path dir)))
(unless (require 'async-installer nil t)
  (error "async-installer is not installed; run ./test-startup.sh first"))

(load-file (expand-file-name "../user-lisp/init-local-async-installer.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(defun init-local-async-installer-tests--git (dir &rest args)
  "Run git with ARGS in DIR and fail the test unless it succeeds."
  (let ((default-directory (file-name-as-directory dir)))
    (should (eql 0 (apply #'call-process "git" nil nil nil
                          "-c" "user.name=test" "-c" "user.email=test"
                          args)))))

(defmacro init-local-async-installer-tests--with-warnings (&rest body)
  "Run BODY with `display-warning' collecting its calls in `warnings'."
  (declare (indent 0))
  `(let ((warnings nil))
     (cl-letf (((symbol-function 'display-warning)
                (lambda (type message &rest _) (push (cons type message) warnings))))
       ,@body)
     (nreverse warnings)))

(ert-deftest init-local-async-installer-native-compile-skips-unusable-files ()
  "Native-comp must skip package metadata and test helpers."
  (let ((async-installer-git-native-compile t)
        selector)
    (cl-letf (((symbol-function 'native-compile-async)
               (lambda (files &optional recursively load candidate)
                 (should (equal files "/tmp/org-gtd.el"))
                 (should recursively)
                 (should-not load)
                 (setq selector candidate))))
      (my/async-installer-native-compile "/tmp/org-gtd.el"))
    (should (funcall selector "/tmp/org-gtd.el/org-gtd.el"))
    (dolist (file '("/tmp/org-gtd.el/org-gtd-pkg.el"
                    "/tmp/org-gtd.el/test/helpers/processing.el"
                    "/tmp/org-gtd.el/tests/unit/horizons-test.el"))
      (should-not (funcall selector file)))))

(ert-deftest init-local-async-installer-update-fetches-new-tag ()
  "A tag added upstream after a detached tag checkout must be fetched.
A target that does not exist must fail and leave `.gitcommit' alone."
  (let* ((tmp (make-temp-file "async-git-" t))
         (origin (expand-file-name "origin" tmp))
         (async-installer-git-install-dir (expand-file-name "pkgs" tmp))
         (pkg (expand-file-name "pkg" async-installer-git-install-dir))
         (cache (expand-file-name ".gitcommit" pkg))
         result)
    (unwind-protect
        (cl-letf (((symbol-function 'async-start)
                   (lambda (start finish) (funcall finish (funcall start))))
                  ((symbol-function 'async-installer-git--native-compile) #'ignore))
          (make-directory origin)
          (init-local-async-installer-tests--git origin "init" "-q")
          (init-local-async-installer-tests--git origin "commit" "-q" "--allow-empty" "-m" "1")
          (init-local-async-installer-tests--git origin "tag" "v1")
          (init-local-async-installer-tests--git tmp "clone" "-q" origin pkg)
          (init-local-async-installer-tests--git pkg "checkout" "-q" "v1")
          (with-temp-file cache (insert "v1"))
          (init-local-async-installer-tests--git origin "commit" "-q" "--allow-empty" "-m" "2")
          (init-local-async-installer-tests--git origin "tag" "v2")
          (my/async-installer-git-update-one
           (list :repo "https://example.invalid/pkg.git" :tag "v2")
           (lambda (dir) (setq result dir)))
          (should (equal result pkg))
          (should (equal (with-temp-buffer (insert-file-contents cache) (buffer-string))
                         "v2"))
          (let ((default-directory (file-name-as-directory pkg)))
            (should (equal (string-trim
                            (shell-command-to-string "git describe --tags"))
                           "v2")))
          (my/async-installer-git-update-one
           (list :repo "https://example.invalid/pkg.git" :tag "v9")
           (lambda (dir) (setq result dir)))
          (should-not result)
          (should (equal (with-temp-buffer (insert-file-contents cache) (buffer-string))
                         "v2")))
      (delete-directory tmp t))))

(ert-deftest init-local-async-installer-update-fails-broken-clone ()
  "A package directory without `.git' must fail without running git."
  (let* ((async-installer-git-install-dir (make-temp-file "async-git-" t))
         (result 'unset))
    (unwind-protect
        (cl-letf (((symbol-function 'async-start)
                   (lambda (&rest _) (error "git must not run"))))
          (make-directory (expand-file-name "pkg" async-installer-git-install-dir))
          (my/async-installer-git-update-one
           (list :repo "https://example.invalid/pkg.git" :tag "v1")
           (lambda (dir) (setq result dir)))
          (should-not result))
      (delete-directory async-installer-git-install-dir t))))

(ert-deftest init-local-async-installer-clone-runs-without-shell-on-windows ()
  "On Windows the clone must start with SHELL unset; elsewhere nothing changes."
  (let ((process-environment (cons "SHELL=/usr/bin/bash" process-environment))
        seen-windows seen-other)
    (let ((system-type 'windows-nt))
      (my/async-installer--without-shell
       (lambda () (setq seen-windows (cons (getenv "SHELL") process-environment)))))
    (let ((system-type 'darwin))
      (my/async-installer--without-shell
       (lambda () (setq seen-other (cons (getenv "SHELL") process-environment)))))
    (should-not (car seen-windows))
    (should (equal "SHELL" (car (cdr seen-windows))))
    (should (equal "/usr/bin/bash" (car seen-other)))
    (should (eq process-environment (cdr seen-other)))
    ;; The caller's environment is back afterwards.
    (should (equal "/usr/bin/bash" (getenv "SHELL")))))

(ert-deftest init-local-async-installer-pin-at-target-checks-tag-commit-and-branch ()
  (let* ((tmp (make-temp-file "async-git-" t))
         (async-installer-git-install-dir tmp)
         (pkg (expand-file-name "pkg" tmp))
         (repo "https://example.invalid/pkg.git"))
    (unwind-protect
        (progn
          (make-directory pkg)
          (init-local-async-installer-tests--git pkg "init" "-q")
          (init-local-async-installer-tests--git pkg "commit" "-q" "--allow-empty" "-m" "1")
          (init-local-async-installer-tests--git pkg "tag" "v1")
          (init-local-async-installer-tests--git pkg "commit" "-q" "--allow-empty" "-m" "2")
          ;; HEAD is the second commit, which has no tag.
          (should-not (my/async-installer-pin-at-target-p (list :repo repo :tag "v1")))
          (init-local-async-installer-tests--git pkg "checkout" "-q" "v1")
          (should (my/async-installer-pin-at-target-p (list :repo repo :tag "v1")))
          (should-not (my/async-installer-pin-at-target-p (list :repo repo :tag "v2")))
          (let ((head (my/async-installer--git pkg "rev-parse" "HEAD")))
            (should (my/async-installer-pin-at-target-p
                     (list :repo repo :commit (substring head 0 8))))
            (should-not (my/async-installer-pin-at-target-p
                         (list :repo repo :commit "0000000"))))
          (init-local-async-installer-tests--git pkg "checkout" "-q" "-b" "feature")
          (should (my/async-installer-pin-at-target-p (list :repo repo :branch "feature")))
          (should-not (my/async-installer-pin-at-target-p (list :repo repo :branch "other")))
          ;; A directory that is not a clone is never at a target.
          (make-directory (expand-file-name "plain" tmp))
          (should-not (my/async-installer-pin-at-target-p
                       (list :repo "https://example.invalid/plain.git" :tag "v1"))))
      (delete-directory tmp t))))

(ert-deftest init-local-async-installer-install-missing-clones-only-absent-packages ()
  (let* ((tmp (make-temp-file "async-git-" t))
         (async-installer-git-install-dir tmp)
         (async-installer-git-list
          (list (list :repo "https://example.invalid/here.git" :tag "v1")
                (list :repo "https://example.invalid/gone.git" :tag "v1")))
         (my/async-installer--installing nil)
         cloned)
    (unwind-protect
        (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "git"))
                  ((symbol-function 'async-installer-git--install-one)
                   (lambda (package callback)
                     (push (plist-get package :repo) cloned)
                     (make-directory (my/async-installer--dir package) t)
                     (funcall callback (my/async-installer--dir package)))))
          (make-directory (expand-file-name "here" tmp))
          (should (my/async-installer-install-missing t))
          (should (equal cloned '("https://example.invalid/gone.git")))
          (should (file-directory-p (expand-file-name "gone" tmp)))
          ;; A second call has nothing left to clone.
          (setq cloned nil)
          (should (my/async-installer-install-missing t))
          (should-not cloned))
      (delete-directory tmp t))))

(ert-deftest init-local-async-installer-install-missing-warns-without-git ()
  (let* ((async-installer-git-install-dir (make-temp-file "async-git-" t))
         (async-installer-git-list
          (list (list :repo "https://example.invalid/gone.git" :tag "v1")))
         (my/async-installer--installing nil)
         result warnings)
    (unwind-protect
        (setq warnings
              (init-local-async-installer-tests--with-warnings
                (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
                          ((symbol-function 'async-installer-git--install-one)
                           (lambda (&rest _) (error "nothing may be cloned"))))
                  (setq result (my/async-installer-install-missing t)))))
      (delete-directory async-installer-git-install-dir t))
    (should-not result)
    (should (= 1 (length warnings)))
    (should (string-match-p "git is not on the PATH" (cdr (car warnings))))))

(ert-deftest init-local-async-installer-setup-adds-existing-clones-to-load-path ()
  (let* ((tmp (make-temp-file "async-git-" t))
         (saved-load-path load-path)
         (saved-hook (and (boundp 'nn-first-input-hook) nn-first-input-hook))
         (saved-dir async-installer-git-install-dir)
         (saved-list async-installer-git-list)
         (here (expand-file-name "here" tmp))
         (sub (expand-file-name "sub/lisp" tmp))
         result)
    (unwind-protect
        (progn
          (make-directory here)
          (make-directory sub t)
          (cl-letf (((symbol-function 'my/async-installer--ensure-package) (lambda () t))
                    ((symbol-function 'advice-add) #'ignore)
                    ((symbol-function 'async-installer-auto-reload-mode) #'ignore)
                    ((symbol-function 'async-installer-reload)
                     (lambda ()
                       (setq async-installer-git-list
                             (list (list :repo "https://example.invalid/here.git" :tag "v1")
                                   (list :repo "https://example.invalid/gone.git" :tag "v1")
                                   (list :repo "https://example.invalid/sub.git" :tag "v1"
                                         :subdir "lisp"))))))
            ;; The install directory comes from setup, so point it at TMP by
            ;; creating the packages where setup will look for them.
            (let ((user-emacs-directory (file-name-as-directory tmp)))
              (make-directory (expand-file-name "var/external-packages/here" tmp) t)
              (make-directory (expand-file-name "var/external-packages/sub/lisp" tmp) t)
              (setq result (my/async-installer-setup))
              (should result)
              (should (member (expand-file-name "var/external-packages/here" tmp) load-path))
              (should (member (expand-file-name "var/external-packages/sub/lisp" tmp) load-path))
              (should-not (member (expand-file-name "var/external-packages/gone" tmp)
                                  load-path))
              (should (memq 'my/async-installer--install-missing-in-session
                            nn-first-input-hook)))))
      (setq load-path saved-load-path
            nn-first-input-hook saved-hook
            async-installer-git-install-dir saved-dir
            async-installer-git-list saved-list)
      (delete-directory tmp t))))

(ert-deftest init-local-async-installer-setup-warns-and-goes-on-without-the-package ()
  "A failed install of async-installer must warn, return nil, and not signal."
  (let ((reloaded nil)
        ;; Even if a stub failed, nothing may reach a real package directory.
        (package-user-dir (make-temp-file "async-elpa-" t))
        result warnings)
    (setq warnings
          (init-local-async-installer-tests--with-warnings
            (let ((orig-require (symbol-function 'require)))
              (cl-letf (((symbol-function 'require)
                         (lambda (feature &rest args)
                           (if (eq feature 'async-installer)
                               nil
                             (apply orig-require feature args))))
                        ((symbol-function 'package-vc-install)
                         (lambda (&rest _) (error "boom")))
                        ((symbol-function 'async-installer-reload)
                         (lambda () (setq reloaded t))))
                (setq result (my/async-installer-setup))))))
    (should-not result)
    (should-not reloaded)
    (should (= 1 (length warnings)))
    (should (eq 'init-local-async-installer (car (car warnings))))
    (should (string-match-p "async-installer is not available.*boom"
                            (cdr (car warnings))))))

(provide 'init-local-async-installer-tests)
;;; init-local-async-installer-tests.el ends here
