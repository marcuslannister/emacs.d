;;; init-local-anvil.el --- Anvil, the MCP server (off during the port) -*- lexical-binding: t -*-
;;; Commentary:
;; Anvil gives AI clients (Claude, Codex) tools that run inside this Emacs.  The
;; earlier configuration owns the MCP clients during the port, so Anvil is off
;; here: `my/anvil-enabled' is nil, and loading anvil.el alone only defines
;; things.  The tools exist only after `anvil-enable'.
;;
;; To test it: set `my/anvil-enabled' in user-lisp/custom.el (or run
;; M-x my/anvil-start), then run the bridge script that
;; M-x anvil-server-install writes to var/ with --socket=<socket of the server
;; named in `my/server-name'>.  At cutover, turn it on.
;;
;; macOS only: Windows does not use Anvil.  The Anvil packages come from
;; init-local-package-list.el.  The `worker' module stays out until cutover (see
;; `my/anvil-modules').
;;; Code:

(defvar anvil-modules)
(defvar anvil-optional-modules)
(defvar anvil-server-install-directory)
(defvar anvil--enabled)
(declare-function anvil-enable "anvil")
(declare-function anvil-server-start "anvil-server-commands")

(defcustom my/anvil-enabled nil
  "Non-nil starts Anvil a moment after startup."
  :type 'boolean
  :group 'tools)

;; `org' is left out on purpose.  Its tools wrote to ~/org files independently
;; of the interactive buffers visiting the same files, which raced with them and
;; caused repeated Syncthing sync-conflict storms.  Both lists must be set before
;; `anvil-enable', which reads them: `anvil-modules' defaults to a list that
;; includes `org', and `anvil-optional-modules' defaults to nil.
;;
;; `worker' is left out during the port.  Its daemons have fixed names
;; (anvil-worker-read-1, -read-2, -write-1, -batch-1), with no prefix setting,
;; and the spawn code skips a worker whose name is already alive.  The earlier
;; configuration runs exactly those daemons, so this Anvil would attach to them
;; (they load that configuration's init file), and the reset-pool tool would kill
;; them by name.  Add `worker' back at cutover, when this config owns them.
(defconst my/anvil-modules
  '(eval file host git proc fs emacs text clipboard data net)
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

(defconst my/anvil-bridge-directory (locate-user-emacs-file "var/")
  "Folder where `anvil-server-install' puts the stdio bridge script.")

;; Anvil writes the script to `user-emacs-directory' by default, which is the
;; repository root here, and Git does not ignore it.
(with-eval-after-load 'anvil-server
  (setq anvil-server-install-directory my/anvil-bridge-directory))

(defun my/anvil-start ()
  "Load Anvil, enable its modules, and start its server.
Warn and do nothing when Anvil cannot run here.  A second call does nothing."
  (interactive)
  (cond
   ((bound-and-true-p anvil--enabled))
   ((not (eq system-type 'darwin))
    (display-warning 'init-local-anvil "Anvil runs on macOS only here, so it is not started"))
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
      (anvil-server-start)))))

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
    (if (not (eq system-type 'darwin))
        (display-warning 'init-local-anvil
                         "my/anvil-enabled is set, but Anvil runs on macOS only here")
      (unless (fboundp 'anvil-server-process-jsonrpc)
        (defalias 'anvil-server-process-jsonrpc #'my/anvil--early-call))
      (run-with-idle-timer 2 nil #'my/anvil-start))))

(provide 'init-local-anvil)
;;; init-local-anvil.el ends here
