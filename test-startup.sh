#!/bin/sh -e
# Load this config in batch Emacs and fail on the first error.
cd "$(dirname "$0")"

# A literal no-break space is invisible in review and easy to lose in an edit.
dirs=user-lisp
[ -d tests ] && dirs="$dirs tests"
if grep -rl --include='*.el' "$(printf '\302\240')" $dirs; then
  echo "Literal U+00A0 in the files above; write it as \\u00a0 in Lisp strings." >&2
  exit 1
fi

echo "Attempting startup..."
# Batch Emacs skips the init files and package activation, so each step of
# startup.el runs by hand, in the same order.
${EMACS:=emacs} --batch --init-directory . \
                --eval '(progn
                        (defvar url-show-status)
                        (let ((debug-on-error t)
                              (url-show-status nil))
                          (load-file "early-init.el")
                          (package-activate-all)
                          (prepare-user-lisp (not user-lisp-auto-scrape))
                          (load-file "init.el")
                          ;; early-init.el sets inhibit-message; window-setup-hook
                          ;; clears it.  Batch Emacs skips that hook.
                          (run-hooks (quote after-init-hook)
                                     (quote emacs-startup-hook)
                                     (quote window-setup-hook))
                          ;; Most modes wait for these hooks; run them so the
                          ;; test loads that code too.
                          (run-hooks (quote nn-first-file-hook)
                                     (quote nn-first-input-hook))
                          (when inhibit-message
                            (error "inhibit-message is still set; warnings stay hidden"))
                          ;; display-warning keeps its text here even when the
                          ;; echo area is quiet.
                          (when-let* ((buf (get-buffer "*Warnings*")))
                            (princ (format "Warnings during startup:\n%s\n"
                                           (with-current-buffer buf
                                             (buffer-string)))))))'
echo "Startup successful"
