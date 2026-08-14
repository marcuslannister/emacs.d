;;; init.el --- PROTOTYPE org-gtd pipeline probe -- WIPE ME  -*- lexical-binding: t; -*-

;; Throwaway rig for wayfinder ticket #20 (map: Org GTD Pipeline Wayfinding, #15).
;; Answers: does a Task really travel capture -> clarify -> organize -> a topic file?
;;
;; Touches NOTHING under ~/org or ~/.emacs.d.  Everything lives in /tmp/org-gtd-proto/.

(setq proto-root "/tmp/org-gtd-proto/")
(setq proto-org (concat proto-root "org/"))

(require 'package)
(setq package-user-dir (concat proto-root "emacs/elpa/"))
(setq package-archives
      '(("gnu"          . "https://elpa.gnu.org/packages/")
        ("nongnu"       . "https://elpa.nongnu.org/nongnu/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")
        ("melpa"        . "https://melpa.org/packages/")))
;; melpa-stable first: it serves tagged releases, which is the version-pin the map
;; already decided on (see #16).
(setq package-archive-priorities
      '(("melpa-stable" . 30) ("gnu" . 20) ("nongnu" . 10) ("melpa" . 0)))
(package-initialize)

;; --- the configuration the map proposes -------------------------------------

(setq org-gtd-directory (concat proto-org "gtd/"))
(setq org-gtd-update-ack "4.0.0")

;; Clarify (WIP) buffers out of the synced tree.
(setq org-edna-use-inheritance t)

;; The destination: single actions and projects prompt for a topic file,
;; everything else auto-files into the GTD directory.
(setq org-gtd-refile-to-any-target nil)
;; NOTE: symbols, not strings -- `org-gtd-refile--should-prompt-p' uses `memq'.
(setq org-gtd-refile-prompt-for-types
      '(single-action project-heading project-task))

(setq org-agenda-files (list proto-org (concat proto-org "gtd/")))
(setq org-refile-targets `((,(directory-files-recursively proto-org "\\.org$")
                            :maxlevel . 5)))
(setq org-refile-use-outline-path 'file)
(setq org-outline-path-complete-in-steps nil)
(setq org-id-locations-file (concat proto-root "org-id-locations"))

(setq org-todo-keywords '((sequence "TODO" "NEXT" "WAIT" "|" "DONE" "CNCL")))

(require 'org-gtd)
(org-gtd-mode 1)

(setq inhibit-startup-screen t)
(message "PROTOTYPE ready: org-gtd %s, %d refile targets"
         (or (ignore-errors (package-desc-version
                             (cadr (assq 'org-gtd package-alist))))
             "?")
         (length (org-refile-get-targets)))

;;; init.el ends here
