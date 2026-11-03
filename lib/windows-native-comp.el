;;; windows-native-comp.el --- MINGW64 libgccjit for native compilation  -*- lexical-binding: t; -*-

;;; Commentary:

;; The official GNU Emacs build for Windows ships no libgccjit and needs the
;; MSYS2 MINGW64 toolchain; with only the UCRT64 one on PATH, every native
;; compile crashes.  Put the first MINGW64 bin with libgccjit first on the
;; PATH of Emacs only.  If none exists, turn native compilation off and warn.
;; Third-party builds that bundle libgccjit, such as kiennq's, skip this.
;; early-init.el loads this file before `package-initialize', which can start
;; native compiles.  See docs/windows-setup.md.

;;; Code:

(let ((name "libgccjit-0.dll"))
  (unless (file-exists-p (expand-file-name name invocation-directory))
    ;; MSYS2 keeps mingw64/bin beside its other bin folders, so any MSYS2 bin
    ;; on PATH (such as ucrt64/bin or usr/bin) gives its root.  Scoop's msys2
    ;; adds nothing to PATH, so also try Scoop's own install folder.
    (let ((dll (locate-file
                name
                (cons (expand-file-name "apps/msys2/current/mingw64/bin"
                                        (or (getenv "SCOOP")
                                            (expand-file-name "scoop" (getenv "USERPROFILE"))))
                      (mapcar (lambda (dir) (expand-file-name "../../mingw64/bin" dir))
                              (delq nil (parse-colon-path (getenv "PATH"))))))))
      ;; libgccjit finds gcc, as and ld through the process PATH, not `exec-path'.
      (if dll
          (setenv "PATH" (concat (convert-standard-filename (file-name-directory dll))
                                 path-separator (getenv "PATH")))
        ;; Byte code instead of a crash.
        (setq native-comp-jit-compilation nil
              native-comp-enable-subr-trampolines nil)
        ;; `display-warning' cannot run this early: no frame exists yet.  Emacs
        ;; shows this list with `display-warning' after init.
        (push '(windows-native-comp
                "No MSYS2 MINGW64 libgccjit found, so native compilation is off. \
Run: scoop install msys2, then in MSYS2: pacman -S --needed mingw-w64-x86_64-gcc \
mingw-w64-x86_64-libgccjit.  See docs/windows-setup.md."
                :warning)
              delayed-warnings-list)))))

(provide 'windows-native-comp)
;;; windows-native-comp.el ends here
