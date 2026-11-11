;;; init-local-server.el --- Name and start the Emacs server -*- lexical-binding: t -*-
;;; Commentary:
;; All Emacs servers of one user share one folder ($TMPDIR/emacs<uid>/, or a
;; server file on Windows).  A second server with the same name fails to start
;; and leaves the first one running.  The earlier configuration owns the default
;; name, so during the port this server is named `nn' on macOS.  Reach it with
;; `emacsclient -s nn ...'.  At cutover, set `my/server-name' to "server".
;; On Windows the earlier configuration no longer runs, so the server there has the
;; default name "server", and plain `emacsclient' reaches it.
;;
;; The Base starts no server, so this module starts it.  Batch Emacs and a
;; daemon do not start one here: a daemon starts its own.
;;; Code:

(defvar server-name)
(declare-function server-start "server")
(declare-function server-running-p "server")

(defcustom my/server-name (if (eq system-type 'windows-nt) "server" "nn")
  "Name of the Emacs server of this config.
It is \"server\" (the Emacs default) on Windows, and \"nn\" elsewhere until the
cutover; then set it to \"server\" everywhere."
  :type 'string
  :group 'server)

(defun my/server-start ()
  "Start the Emacs server under `my/server-name'.
If a server of that name already runs, warn and do not start another one."
  (unless (or noninteractive (daemonp))
    (require 'server)
    (setq server-name my/server-name)
    (if (server-running-p)
        (display-warning 'init-local-server
                         (format "An Emacs server named %s already runs, so none starts here"
                                 server-name))
      (server-start))))

(provide 'init-local-server)
;;; init-local-server.el ends here
