#!/bin/sh -e
# Time a batch load of early-init.el and init.el.
# Usage: ./bench-startup.sh [RUNS]   (default 3)
# Batch runs require the idle-loaded modules at once, so compare runs of this
# script with each other.  For real startup use `M-x emacs-init-time'.
cd "$(dirname "$0")"
runs=${1:-3}
i=0
while [ "$i" -lt "$runs" ]; do
  ${EMACS:=emacs} -nw --batch --eval '(let ((user-emacs-directory default-directory)
                                (early-init-file (expand-file-name "early-init.el"))
                                (user-init-file (expand-file-name "init.el"))
                                (load-path (delq default-directory load-path))
                                (start (float-time)))
    (setq package-check-signature nil)
    (load-file early-init-file)
    (load-file user-init-file)
    (message "BENCH %.2f s" (- (float-time) start)))' 2>&1 | rg '^BENCH'
  i=$((i + 1))
done
