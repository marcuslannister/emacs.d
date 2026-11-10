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
                              ;; Warnings queued during early startup show up
                              ;; from the command loop, which batch Emacs lacks.
                              (run-hooks (quote delayed-warnings-hook))
                              ;; The Base defers most modes to these hooks. Run
                              ;; them, so the test loads that code too.
                              (run-hooks (quote nn-first-file-hook)
                                         (quote nn-first-input-hook))
                              ;; These checks need the real load order, so a
                              ;; unit test cannot do them.
                              ;; The case guard must be on before any command runs.
                              (unless (advice-member-p (quote my/case-guard)
                                                       (quote upcase-region))
                                (error "The case guard is not active"))
                              ;; Trailing whitespace is trimmed per mode, never
                              ;; on every save: that rewrites files we only open.
                              (when (memq (quote delete-trailing-whitespace)
                                          (default-value (quote before-save-hook)))
                                (error "before-save-hook trims whitespace in every buffer"))
                              ;; ...and only in programming buffers, by edited line.
                              (unless (memq (quote ws-butler-mode) prog-mode-hook)
                                (error "ws-butler is not on prog-mode-hook"))
                              (when (memq (quote ws-butler-mode) text-mode-hook)
                                (error "ws-butler is on text-mode-hook"))
                              ;; The pinned Git packages must be present at their
                              ;; pinned targets. async-installer clones them in the
                              ;; background, and batch Emacs would exit before the
                              ;; clones finish, so wait here. Otherwise a green
                              ;; run would prove nothing about the pins.
                              (unless (fboundp (quote my/async-installer-install-missing))
                                (error "The Git pin installer is not loaded"))
                              (setq async-installer-git-native-compile nil)
                              (my/async-installer-install-missing t)
                              (unless (equal (sort (mapcar (lambda (pin)
                                                             (file-name-base
                                                              (plist-get pin :repo)))
                                                           async-installer-git-list)
                                                   (function string<))
                                             (quote ("anvil.el" "hel" "hel-leader" "org-gtd.el")))
                                (error "The pin list is wrong: %S" async-installer-git-list))
                              (dolist (pin async-installer-git-list)
                                (unless (my/async-installer-pin-at-target-p pin)
                                  (error "Git package %s is not at its pinned target"
                                         (plist-get pin :repo))))
                              ;; JIT native compilation is on everywhere. Windows is
                              ;; the exception: the helper turns it off, with a
                              ;; warning, when no MINGW64 toolchain is found.
                              (princ (format "Native compilation: available=%S jit=%S\n"
                                             (and (fboundp (quote native-comp-available-p))
                                                  (native-comp-available-p))
                                             (and (boundp (quote native-comp-jit-compilation))
                                                  native-comp-jit-compilation)))
                              (when (and (fboundp (quote native-comp-available-p))
                                         (native-comp-available-p)
                                         (not (eq system-type (quote windows-nt))))
                                (unless native-comp-jit-compilation
                                  (error "native-comp-jit-compilation is off")))
                              ;; C-x C-u is one slip from C-x u (undo), and it
                              ;; upcases mark-to-point with no prompt.
                              (with-temp-buffer
                                (when (key-binding (kbd "C-x C-u"))
                                  (error "C-x C-u should be unbound, got %S"
                                         (key-binding (kbd "C-x C-u")))))
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
