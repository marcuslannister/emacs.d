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
               (lambda (files &optional recursively _load candidate)
                 (should (equal files "/tmp/org-gtd.el"))
                 (should recursively)
                 (setq selector candidate))))
      (init-local-async-installer-native-compile "/tmp/org-gtd.el"))
    (should (funcall selector "/tmp/org-gtd.el/org-gtd.el"))
    (dolist (file '("/tmp/org-gtd.el/org-gtd-pkg.el"
                    "/tmp/org-gtd.el/test/helpers/processing.el"
                    "/tmp/org-gtd.el/tests/unit/horizons-test.el"))
      (should-not (funcall selector file)))))
