;;; make-tree.el --- PROTOTYPE scratch org tree -- WIPE ME  -*- lexical-binding: t; -*-

;; Builds a synthetic ~/org lookalike: same file names and same heading counts
;; as the real store, so the refile prompt has a realistic candidate list.
;; No real content is copied.

(setq proto-org "/tmp/org-gtd-proto/org/")

(defvar proto-files
  '(("ai-chat" . 8) ("ai" . 60) ("bookmark" . 39) ("camera" . 10)
    ("coffee" . 5) ("diary" . 13) ("docker" . 82) ("emacs-auto-fold" . 9)
    ("eshell-config" . 6) ("game" . 6) ("gptel-config" . 40) ("habits" . 3)
    ("hardware" . 32) ("journal" . 10) ("learning" . 12) ("movies" . 16)
    ("musics" . 4) ("network" . 113) ("notes" . 1) ("other" . 52)
    ("shopping" . 18) ("software" . 535) ("todo" . 2) ("travel" . 7)
    ("web" . 59) ("weekly" . 1) ("nerd-font" . 1) ("inbox-old" . 4)
    ("refile-old" . 2) ("now-old" . 1)))

(dolist (spec proto-files)
  (let ((name (car spec)) (n (cdr spec)))
    (with-temp-file (concat proto-org name ".org")
      (insert "#+title: " name "\n\n")
      (dotimes (i n)
        ;; depth cycles 1..4 so :maxlevel 5 sees a realistic outline path
        (let ((depth (1+ (mod i 4))))
          (insert (make-string depth ?*) " " name " topic " (number-to-string i) "\n"))))))

(message "wrote %d files, %d headings"
         (length proto-files)
         (apply #'+ (mapcar #'cdr proto-files)))
