;;; init-local-async-installer-tests.el --- Tests for Git-install native-comp -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(let* ((root (expand-file-name ".."
                              (file-name-directory load-file-name)))
       (async-dir (car (file-expand-wildcards
                        (expand-file-name "elpa-*/async-*" root)))))
  (setq user-emacs-directory root)
  (when async-dir
    (add-to-list 'load-path async-dir)))

(load-file (expand-file-name "../lisp/init-local-async-installer.el"
                             (file-name-directory load-file-name)))

(ert-deftest init-local-async-installer-native-compile-skips-unusable-files ()
  "Native-comp must skip package metadata and test helpers."
  (let (selector)
    (cl-letf (((symbol-function 'native-compile-async)
               (lambda (files &optional recursively load candidate)
                 (should (equal files "/tmp/org-gtd.el"))
                 (should recursively)
                 (should-not load)
                 (setq selector candidate))))
      (init-local-async-installer-native-compile "/tmp/org-gtd.el"))
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
         (git (lambda (dir &rest args)
                (let ((default-directory (file-name-as-directory dir)))
                  (should (eql 0 (apply #'call-process "git" nil nil nil
                                        "-c" "user.name=t" "-c" "user.email=t@t"
                                        args))))))
         result)
    (unwind-protect
        (cl-letf (((symbol-function 'async-start)
                   (lambda (start finish) (funcall finish (funcall start))))
                  ((symbol-function 'async-installer-git--native-compile) #'ignore))
          (make-directory origin)
          (funcall git origin "init" "-q")
          (funcall git origin "commit" "-q" "--allow-empty" "-m" "1")
          (funcall git origin "tag" "v1")
          (funcall git tmp "clone" "-q" origin pkg)
          (funcall git pkg "checkout" "-q" "v1")
          (with-temp-file cache (insert "v1"))
          (funcall git origin "commit" "-q" "--allow-empty" "-m" "2")
          (funcall git origin "tag" "v2")
          (init-local-async-installer-git-update-one
           (list :repo "https://example.invalid/pkg.git" :tag "v2")
           (lambda (dir) (setq result dir)))
          (should (equal result pkg))
          (should (equal (with-temp-buffer (insert-file-contents cache) (buffer-string))
                         "v2"))
          (let ((default-directory (file-name-as-directory pkg)))
            (should (equal (string-trim
                            (shell-command-to-string "git describe --tags"))
                           "v2")))
          (init-local-async-installer-git-update-one
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
          (init-local-async-installer-git-update-one
           (list :repo "https://example.invalid/pkg.git" :tag "v1")
           (lambda (dir) (setq result dir)))
          (should-not result))
      (delete-directory async-installer-git-install-dir t))))
