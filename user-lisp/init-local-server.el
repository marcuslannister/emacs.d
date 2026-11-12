;;; init-local-server.el --- Name and start the Emacs server -*- lexical-binding: t -*-
;;; Commentary:
;; All Emacs servers of one user share one folder ($TMPDIR/emacs<uid>/, or a
;; server file on Windows).  A second server with the same name fails to start
;; and leaves the first one running.  This config uses the default name "server",
;; so plain `emacsclient' reaches it, and the Anvil bridge needs no option.  Close
;; any other Emacs first (for example a copy of the earlier configuration): it
;; would keep the name, and this config would warn and start no server.
;;
;; The Base starts no server, so this module starts it.  Batch Emacs and a
;; daemon do not start one here: a daemon starts its own.
;;; Code:

(defvar server-name)
(declare-function server-start "server")
(declare-function server-running-p "server")

(defcustom my/server-name "server"
  "Name of the Emacs server of this config.
\"server\" is the Emacs default, so plain `emacsclient' reaches it."
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
