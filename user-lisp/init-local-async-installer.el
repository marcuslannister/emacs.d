;;; init-local-async-installer.el --- Install and update the pinned Git packages -*- lexical-binding: t -*-
;;; Commentary:
;; Four packages come from Git, not from an archive: Anvil, Hel, hel-leader, and
;; org-gtd.  `package-vc' does not resolve their VC dependencies, and
;; `my/update-all-packages' also refreshes the Anvil bridge script, so they go
;; through `async-installer', a third-party Git installer that clones in the
;; background.  The list is in init-local-package-list.el.  Each entry names a
;; tag, and the tag is the pin.
;;
;; `async-installer' has no licence file.  This module only uses it, and never
;; copies its code.  It is installed by `package-vc' at the exact commit that
;; was read, in `my/async-installer-revision', so an upstream change cannot reach
;; this config unseen.  The two repairs below override internal functions of that
;; revision, so move the two together.
;;
;; The clones live in var/external-packages/, which Git ignores.  `async-installer'
;; extends `load-path' only right after a clone, and it skips a clone that
;; already exists.  `my/async-installer-setup' therefore adds each existing clone
;; on every start, once, for all packages.
;;
;; Loading this file has no side effects.  `init-local' calls
;; `my/async-installer-setup', and the tests load the file alone.
;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar async-installer-git-list)
(defvar async-installer-git-install-dir)
(defvar async-installer-git-native-compile)
(defvar async-installer-reload-files)
(defvar user-lisp-directory)
(defvar nn-first-input-hook)
(declare-function async-start "async")
(declare-function async-installer-reload "async-installer")
(declare-function async-installer-auto-reload-mode "async-installer")
(declare-function async-installer-git--install-one "async-installer")
(declare-function async-installer-git--install-all "async-installer")
(declare-function async-installer-git--update-all "async-installer")
(declare-function async-installer-git--native-compile "async-installer")
(declare-function package-vc-install "package-vc")
(declare-function anvil-server-install "anvil")

(defconst my/async-installer-revision "90c8fee9ab60c0b97883c05ceb0c68d9a7c19372"
  "Commit of zawatton/async-installer that `package-vc' installs.")

(defvar my/async-installer-wait-seconds 600
  "Longest wait, in seconds, of `my/async-installer-install-missing' with WAIT.")

(defvar my/async-installer--installing nil
  "Non-nil while a background install runs.")

;;;; Repairs to async-installer

(defun my/async-installer-native-compile (dir)
  "Native-compile DIR without loading package metadata or tests."
  (when (and async-installer-git-native-compile
             (fboundp 'native-compile-async))
    (message "[async-git] native-compile queued: %s" dir)
    (native-compile-async
     ;; LOAD nil: t loads every compiled file, including benchmark and demo scripts.
     dir 2 nil
     (lambda (file)
       (not (or (string-match-p "[/\\\\]tests?[/\\\\]" file)
                (string-suffix-p "-pkg.el" file)))))))

(defun my/async-installer-git-update-one (package callback)
  "Update PACKAGE like `async-installer-git--update-one', but check git.
The original runs `git pull', which fails on the detached HEAD of a tag
checkout without fetching the new tag.  It ignores the exit codes and writes
`.gitcommit' anyway, so each later run reports \"Already at\" and skips the
package.  A failed clone leaves a directory without `.git'; git would then
run in the parent repository, so such a package fails instead.
Call CALLBACK with the package directory, or nil on failure."
  (let* ((tgt (or (plist-get package :commit) (plist-get package :branch)
                  (plist-get package :tag) "main"))
         (name (my/async-installer--name package))
         (dir (my/async-installer--dir package))
         (cache-file (expand-file-name ".gitcommit" dir))
         (cached (if (file-exists-p cache-file)
                     (with-temp-buffer
                       (insert-file-contents cache-file)
                       (string-trim (buffer-string)))
                   ""))
         ;; Only a branch target can move after the checkout.
         (cmds `(("fetch" "--tags" "origin") ("checkout" ,tgt)
                 ,@(unless (or (plist-get package :commit) (plist-get package :tag))
                     '(("pull" "--ff-only"))))))
    (cond
     ((not (file-directory-p dir))
      (message "[async-git] Not installed, skip update: %s" name)
      (funcall callback nil))
     ((not (file-exists-p (expand-file-name ".git" dir)))
      (message "[async-git] Broken clone, delete and reinstall: %s" name)
      (funcall callback nil))
     ((string= cached tgt)
      (message "[async-git] Already at %s: %s" tgt name)
      (funcall callback dir))
     (t
      (message "[async-git] Updating %s: %s -> %s" name cached tgt)
      (async-start
       (lambda ()
         (let ((default-directory dir))
           (catch 'fail
             (dolist (args cmds t)
               (unless (eql 0 (apply #'call-process "git" nil nil nil args))
                 (throw 'fail nil))))))
       (lambda (ok)
         (if (not ok)
             (progn
               (message "[async-git] Update failed: %s" name)
               (funcall callback nil))
           (with-temp-file cache-file (insert tgt))
           (message "[async-git] Updated: %s -> %s" name tgt)
           (async-installer-git--native-compile dir)
           (funcall callback dir))))))))

(defun my/async-installer--without-shell (orig &rest args)
  "Call ORIG with ARGS and no SHELL in the environment of child processes, on Windows.
The Base sets SHELL to Git bash.  The child Emacs that `async-start' runs
inherits it, and `async-installer' then runs its clone script there as
`cmd /c script.bat'.  Git bash cannot run that, so every clone failed on
Windows.  With SHELL unset, the child falls back to cmdproxy.exe."
  (let ((process-environment (if (eq system-type 'windows-nt)
                                 (cons "SHELL" process-environment)
                               process-environment)))
    (apply orig args)))

;;;; Where each package lives

(defun my/async-installer--name (package)
  "Return the directory name of PACKAGE, taken from its repository URL."
  (file-name-nondirectory (string-remove-suffix ".git" (plist-get package :repo))))

(defun my/async-installer--dir (package)
  "Return the clone directory of PACKAGE."
  (expand-file-name (my/async-installer--name package) async-installer-git-install-dir))

(defun my/async-installer--load-dir (package)
  "Return the directory of PACKAGE that belongs on `load-path'."
  (let ((dir (my/async-installer--dir package))
        (subdir (plist-get package :subdir)))
    (if subdir (expand-file-name subdir dir) dir)))

(defun my/async-installer-present-p (package)
  "Return non-nil when the clone directory of PACKAGE exists."
  (file-directory-p (my/async-installer--dir package)))

(defun my/async-installer--git (dir &rest args)
  "Run git with ARGS in DIR; return its trimmed output, or nil on failure."
  (let ((default-directory (file-name-as-directory dir)))
    (with-temp-buffer
      (when (eql 0 (apply #'call-process "git" nil t nil args))
        (string-trim (buffer-string))))))

(defun my/async-installer-pin-at-target-p (package)
  "Return non-nil when the clone of PACKAGE sits at its pinned target.
The target is the commit, else the branch, else the tag of the entry."
  (let ((dir (my/async-installer--dir package))
        (commit (plist-get package :commit))
        (branch (plist-get package :branch))
        (tag (plist-get package :tag)))
    (and (file-exists-p (expand-file-name ".git" dir))
         (cond
          (commit (let ((head (my/async-installer--git dir "rev-parse" "HEAD")))
                    (and head (string-prefix-p commit head))))
          (branch (equal (my/async-installer--git dir "rev-parse" "--abbrev-ref" "HEAD")
                         branch))
          (tag (member tag (split-string
                            (or (my/async-installer--git dir "tag" "--points-at" "HEAD")
                                "")
                            "\n" t)))))))

;;;; Install

(defun my/async-installer-install-missing (&optional wait)
  "Clone each registered Git package whose directory is missing, in the background.
With WAIT, block until the clones finish or `my/async-installer-wait-seconds'
pass.  Batch Emacs needs that, because it would exit before the clones end.
Return non-nil when every package is present."
  (interactive)
  (let ((missing (seq-remove #'my/async-installer-present-p async-installer-git-list)))
    (cond
     ((null missing))
     ((not (executable-find "git"))
      (display-warning 'init-local-async-installer
                       "git is not on the PATH, so the Git packages are not installed"))
     (my/async-installer--installing)
     (t
      (setq my/async-installer--installing t)
      (let ((queue (copy-sequence missing)))
        (cl-labels
            ((step ()
               (if (null queue)
                   (setq my/async-installer--installing nil)
                 (let ((package (pop queue)))
                   (condition-case err
                       (async-installer-git--install-one
                        package
                        (lambda (dir)
                          (unless dir
                            (display-warning
                             'init-local-async-installer
                             (format "Clone failed: %s" (plist-get package :repo))))
                          (step)))
                     (error
                      (display-warning
                       'init-local-async-installer
                       (format "Install of %s failed: %s" (plist-get package :repo)
                               (error-message-string err)))
                      (step)))))))
          (step)))))
    (when wait
      (let ((deadline (+ (float-time) my/async-installer-wait-seconds)))
        (while (and my/async-installer--installing (< (float-time) deadline))
          (accept-process-output nil 0.2))
        (when my/async-installer--installing
          (display-warning 'init-local-async-installer
                           "The Git package install did not finish in time"))))
    (seq-every-p #'my/async-installer-present-p async-installer-git-list)))

(defun my/async-installer--install-missing-in-session ()
  "Install the missing Git packages in an interactive session, not in batch."
  (unless noninteractive
    (my/async-installer-install-missing)))

;;;; Setup

(defun my/async-installer--ensure-package ()
  "Return non-nil when `async-installer' can be loaded; install it if needed.
On failure, warn and return nil, so that startup goes on."
  (or (require 'async-installer nil t)
      (condition-case err
          (progn
            ;; The `async' package comes from an archive, and package-vc
            ;; installs only the VC package itself.
            (use-package async)
            (package-vc-install '(async-installer
                                  :url "https://github.com/zawatton/async-installer.git")
                                my/async-installer-revision)
            (require 'async-installer nil t))
        (error
         (display-warning 'init-local-async-installer
                          (format "async-installer is not available, so the Git packages are skipped: %s"
                                  (error-message-string err)))
         nil))))

(defun my/async-installer-setup ()
  "Make the pinned Git packages available.
Install `async-installer' if needed, register the packages, and add each
existing clone to `load-path'.  Warn and return nil when `async-installer'
cannot be loaded."
  (when (my/async-installer--ensure-package)
    (setq async-installer-git-install-dir (locate-user-emacs-file "var/external-packages")
          async-installer-git-native-compile (and (fboundp 'native-comp-available-p)
                                                  (native-comp-available-p))
          async-installer-reload-files
          (list (expand-file-name "init-local-package-list.el" user-lisp-directory)))
    (advice-add 'async-installer-git--native-compile
                :override #'my/async-installer-native-compile)
    (advice-add 'async-installer-git--update-one
                :override #'my/async-installer-git-update-one)
    (advice-add 'async-installer-git--install-one
                :around #'my/async-installer--without-shell)
    (async-installer-reload)
    (async-installer-auto-reload-mode 1)
    (dolist (package async-installer-git-list)
      (when (my/async-installer-present-p package)
        (add-to-list 'load-path (my/async-installer--load-dir package))))
    (add-hook 'nn-first-input-hook #'my/async-installer--install-missing-in-session)
    t))

;;;; Update

(defun my/update-vc-packages ()
  "Upgrade every `package-vc' package except `async-installer'.
`async-installer' is pinned at `my/async-installer-revision'.  `package-vc-upgrade'
runs `vc-pull', which could move that checkout past the commit that was read,
and would show nothing but a demoted error message when it did not."
  (dolist (package package-alist)
    (dolist (pkg-desc (cdr package))
      (when (and (package-vc-p pkg-desc)
                 (not (eq (package-desc-name pkg-desc) 'async-installer)))
        (package-vc-upgrade pkg-desc)))))

(defun my/update-all-packages ()
  "Update all installed packages, including async-installer Git packages.
Clone the Git packages before updating them.  The update pass skips a
package whose directory in var/external-packages is absent and counts it as a
failure, so a deleted clone never repairs itself; the install pass clones
what is missing and skips what is already there.  Both passes are
asynchronous, so the install callback chains the update rather than
running the two side by side.  A clone that failed and left a directory
without `.git' fails in the update pass; see
`my/async-installer-git-update-one'."
  (interactive)
  ;; Read the package list again so a `:tag' bump takes effect without a restart.
  (async-installer-reload)
  (package-refresh-contents)
  (package-upgrade-all)
  (my/update-vc-packages)
  (async-installer-git--install-all
   (lambda (ok ng)
     (message "[async-git] Install done! success=%d, fail=%d" ok ng)
     (async-installer-git--update-all
      (lambda (ok ng)
        (message "[async-git] Update done! success=%d, fail=%d" ok ng)
        ;; The MCP bridge is a copy of the checkout's script; refresh it so a
        ;; bump cannot leave the old one behind.  Skip its "Overwrite?" prompt.
        (when (fboundp 'anvil-server-install)
          (cl-letf (((symbol-function 'yes-or-no-p) #'always))
            (anvil-server-install))))))))

(provide 'init-local-async-installer)
;;; init-local-async-installer.el ends here
