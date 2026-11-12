;;; init-local-anvil.el --- Anvil, the MCP server -*- lexical-binding: t -*-
;;; Commentary:
;; Anvil gives AI clients (Claude, Codex) tools that run inside this Emacs.
;; Loading anvil.el alone only defines things.  The tools exist only after
;; `anvil-enable'.
;;
;; Anvil runs on macOS and Windows (`my/anvil-systems'), and starts a moment after
;; startup there (`my/anvil-enabled').
;;
;; The MCP clients start the bridge script anvil-stdio.sh in the config root, where
;; they always looked for it.  Anvil copies it there when it is missing, and Git
;; ignores it.  The server has the default name, so the bridge needs no --socket
;; option.  Only one Emacs may run the worker daemons (see `my/anvil-modules'):
;; close the earlier configuration first.
;;
;; The Anvil packages come from init-local-package-list.el.
;;; Code:

(defvar anvil-modules)
(defvar anvil-optional-modules)
(defvar anvil-server-install-directory)
(defvar anvil--enabled)
(declare-function anvil-enable "anvil")
(declare-function anvil-server-start "anvil-server-commands")
(declare-function anvil-server-install "anvil-server-commands")

(defconst my/anvil-systems '(darwin windows-nt)
  "Values of `system-type' on which Anvil runs.")

(defcustom my/anvil-enabled (and (memq system-type my/anvil-systems) t)
  "Non-nil starts Anvil a moment after startup.
On by default on the systems where Anvil runs."
  :type 'boolean
  :group 'tools)

;; `org' is left out on purpose.  Its tools wrote to ~/org files independently
;; of the interactive buffers visiting the same files, which raced with them and
;; caused repeated Syncthing sync-conflict storms.  Both lists must be set before
;; `anvil-enable', which reads them: `anvil-modules' defaults to a list that
;; includes `org', and `anvil-optional-modules' defaults to nil.
;;
;; `worker' starts four daemons with fixed names (anvil-worker-read-1, -read-2,
;; -write-1, -batch-1), with no prefix setting.  The spawn code skips a worker
;; whose name is already alive, and the reset-pool tool kills them by name.  So only
;; one Emacs configuration may run them: close the earlier configuration first, or
;; both share the daemons, which load the init file of whichever started them.
(defconst my/anvil-modules
  '(eval file host git proc fs emacs text clipboard data net worker)
  "Anvil modules to load.")

;; `state' comes before `shell-filter' and `context', which both need its
;; SQLite store.  `disclosure' only reads org files and never enables the org
;; module's write tools.  `xlsx' and `pdf' need openpyxl and pymupdf in the
;; Python on `exec-path'; a module whose dependency is missing is skipped.
(defconst my/anvil-optional-modules
  '(xlsx pdf http cron browser state shell-filter context disclosure sexp)
  "Optional Anvil modules to load.")

(defconst my/anvil-state-directory (locate-user-emacs-file "var/anvil/")
  "Folder for the state files of Anvil.")

(defconst my/anvil-bridge-directory (expand-file-name user-emacs-directory)
  "Folder where `anvil-server-install' puts the stdio bridge script.
It is the config root, where the MCP clients look for it.  .gitignore lists the file.")

;; Anvil's own default is `user-emacs-directory', but `my/anvil-start' binds that
;; to the state folder while Anvil loads, so the folder is set here.
(with-eval-after-load 'anvil-server
  (setq anvil-server-install-directory my/anvil-bridge-directory))

;; `anvil-worker--generate-init-file' writes anvil-worker-init.el into
;; `user-emacs-directory' when a worker spawns, which is after `my/anvil-start' has
;; returned.  Point it at the state folder, so the config root gets no stray file.
;; Do not set `anvil-worker-init-file': a non-nil value turns the generation off.
(defun my/anvil--worker-init-in-state-dir (generate)
  "Call GENERATE with `user-emacs-directory' set to the Anvil state folder."
  (let ((user-emacs-directory my/anvil-state-directory))
    (funcall generate)))

(with-eval-after-load 'anvil-worker
  (advice-add 'anvil-worker--generate-init-file :around #'my/anvil--worker-init-in-state-dir))

(defun my/anvil-start ()
  "Load Anvil, enable its modules, and start its server.
Warn and do nothing when Anvil cannot run here.  A second call does nothing."
  (interactive)
  (cond
   ((bound-and-true-p anvil--enabled))
   ((not (memq system-type my/anvil-systems))
    (display-warning 'init-local-anvil
                     "Anvil runs on macOS and Windows only here, so it is not started"))
   ((not (require 'anvil nil t))
    (display-warning 'init-local-anvil
                     "anvil.el is not installed, so Anvil is not started"))
   (t
    ;; About fifteen Anvil modules build the names of their state files from
    ;; `user-emacs-directory' when they load.  Bind it to var/anvil/ for the
    ;; load, so that none of them writes into the repository root.
    (make-directory my/anvil-state-directory t)
    (let ((user-emacs-directory my/anvil-state-directory))
      (setq anvil-modules my/anvil-modules
            anvil-optional-modules my/anvil-optional-modules)
      (require 'anvil-server-commands)
      (setq anvil-server-install-directory my/anvil-bridge-directory)
      (anvil-enable)
      (anvil-server-start)
      ;; The clients start this script, so it must exist after the first start.
      (unless (file-exists-p (expand-file-name "anvil-stdio.sh" my/anvil-bridge-directory))
        (anvil-server-install))))))

(defun my/anvil--early-call (&rest args)
  "Start Anvil, then call the real `anvil-server-process-jsonrpc' with ARGS.
A client that connects before the idle start finds this function, instead of
a missing one.  `my/anvil-start' replaces it with the real definition."
  (my/anvil-start)
  (if (eq (symbol-function 'anvil-server-process-jsonrpc) 'my/anvil--early-call)
      (error "Anvil did not start")
    (apply #'anvil-server-process-jsonrpc args)))

(defun my/anvil-setup ()
  "Schedule the start of Anvil when `my/anvil-enabled' is non-nil.
Does nothing in batch Emacs.  When Anvil is off, it loads nothing."
  (when (and my/anvil-enabled (not noninteractive))
    (if (not (memq system-type my/anvil-systems))
        (display-warning 'init-local-anvil
                         "my/anvil-enabled is set, but Anvil runs on macOS and Windows only here")
      (unless (fboundp 'anvil-server-process-jsonrpc)
        (defalias 'anvil-server-process-jsonrpc #'my/anvil--early-call))
      (run-with-idle-timer 2 nil #'my/anvil-start))))

(provide 'init-local-anvil)
;;; init-local-anvil.el ends here
