#!/bin/sh -e

: "${EMACS:=emacs}"

"$EMACS" -Q --batch \
  --eval '(setq user-emacs-directory default-directory)' \
  --eval '
(setq package-user-dir
      (expand-file-name
       (format "elpa-%s.%s" emacs-major-version emacs-minor-version)
       user-emacs-directory))' \
  --funcall package-initialize \
  -l tests/init-local-vulpea-integration-tests.el \
  -f ert-run-tests-batch-and-exit
