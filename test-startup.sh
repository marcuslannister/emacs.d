#!/bin/sh -e
# Smoke test: start this config in batch Emacs and stop at the first error.
cd "$(dirname "$0")"

# A no-break space looks like a plain space in review, so reject it in the sources.
dirs=user-lisp
[ -d tests ] && dirs="$dirs tests"
if grep -rl --include='*.el' "$(printf '\302\240')" $dirs; then
  echo "A literal U+00A0 is in the files above. Write \\u00a0 in Lisp strings." >&2
  exit 1
fi

echo "Starting the config in batch Emacs..."
# Batch Emacs skips the init files and package activation. This script repeats
# the steps of startup.el, in the same order.
${EMACS:=emacs} --batch --init-directory . \
                --eval '(progn
                        (require (quote url-vars))
                        (setq debug-on-error t
                              url-show-status nil)
                        (unwind-protect
                            (progn
                              (load-file "early-init.el")
                              (package-activate-all)
                              (prepare-user-lisp (not user-lisp-auto-scrape))
                              (load-file "init.el")
                              ;; early-init.el sets inhibit-message, and only
                              ;; window-setup-hook clears it. Batch Emacs never
                              ;; runs that hook on its own.
                              (run-hooks (quote after-init-hook)
                                         (quote emacs-startup-hook)
                                         (quote window-setup-hook))
                              ;; The Base defers most modes to these hooks. Run
                              ;; them, so the test loads that code too.
                              (run-hooks (quote nn-first-file-hook)
                                         (quote nn-first-input-hook))
                              (when inhibit-message
                                (error "inhibit-message is still set; warnings stay hidden"))
                              ;; display-warning keeps its text in this buffer
                              ;; even when the echo area is quiet.
                              (when-let* ((buf (get-buffer "*Warnings*")))
                                (princ (format "Warnings during startup:\n%s\n"
                                               (with-current-buffer buf
                                                 (buffer-string))))))
                          ;; The exit hooks save recentf and savehist into var/.
                          ;; This folder can also be the folder of a running
                          ;; trial Emacs, and a test run must not overwrite its
                          ;; history.
                          (setq kill-emacs-hook nil)))'
echo "Startup check passed"
