;;; drive.el --- PROTOTYPE driver -- WIPE ME  -*- lexical-binding: t; -*-

;; Walks one Task from capture to a topic file, in batch, and prints the state
;; after every step.  Answers wayfinder ticket #20.

(load "/tmp/org-gtd-proto/emacs/init.el")

(defun proto-say (fmt &rest args)
  (princ (concat (apply #'format fmt args) "\n")))

(defun proto-file-contents (path)
  (if (file-exists-p path)
      (with-temp-buffer (insert-file-contents path) (buffer-string))
    (format "<<no such file: %s>>" path)))

(proto-say "\n========== STEP 0: what is installed ==========")
(proto-say "org-gtd %s / org %s / emacs %s"
           (package-desc-version (cadr (assq 'org-gtd package-alist)))
           (org-version) emacs-version)
(proto-say "org-gtd-directory      = %s" org-gtd-directory)
(proto-say "refile-to-any-target   = %s" org-gtd-refile-to-any-target)
(proto-say "refile-prompt-for-types= %s" org-gtd-refile-prompt-for-types)
(proto-say "WIP temp dir           = %s"
           (expand-file-name "org-gtd" temporary-file-directory))

(proto-say "\n========== STEP 1: how big is the refile prompt ==========")
;; What the user's own config would offer:
(proto-say "user org-refile-targets (:maxlevel 5) -> %d candidates"
           (length (org-refile-get-targets)))
;; What org-gtd actually binds inside `org-gtd-refile--do' when it prompts:
(let* ((org-refile-target-verify-function
        (org-gtd-refile--make-verify-function org-gtd-action))
       (org-refile-targets (append org-refile-targets
                                   '((org-agenda-files :maxlevel . 9))))
       (org-refile-use-outline-path t)
       (org-outline-path-complete-in-steps nil)
       (targets (org-refile-get-targets)))
  (proto-say "org-gtd's own prompt binding      -> %d candidates" (length targets))
  (proto-say "first three look like: %S"
             (mapcar #'car (seq-take targets 3))))

(proto-say "\n========== STEP 2: capture ==========")
(let ((org-capture-templates org-gtd-capture-templates))
  (org-capture nil "i")
  (insert "Buy a new coffee grinder")
  (org-capture-finalize))
(org-save-all-org-buffers)
(proto-say "inbox now:\n%s" (proto-file-contents (org-gtd--path "inbox")))

(proto-say "\n========== STEP 3: clarify + organize as single action ==========")
;; Answer the refile prompt with a fixed topic file, non-interactively.
(defvar proto-chosen-target nil)
(defun proto-pick-target (&rest _)
  "Stand in for the human at the refile prompt: always pick shopping.org."
  (let* ((targets (org-refile-get-targets))
         (hit (seq-find (lambda (tgt)
                          (string-match-p "shopping\\.org" (or (nth 1 tgt) "")))
                        targets)))
    (setq proto-chosen-target (car hit))
    (car hit)))
(advice-add 'completing-read :override #'proto-pick-target)

(let* ((inbox (find-file-noselect (org-gtd--path "inbox")))
       (marker (with-current-buffer inbox
                 (goto-char (point-min))
                 (org-next-visible-heading 1)
                 (point-marker))))
  (org-gtd-clarify-item marker)
  (org-gtd-single-action))
(advice-remove 'completing-read #'proto-pick-target)
(org-save-all-org-buffers)
(proto-say "prompt answered with: %S" proto-chosen-target)

(proto-say "\n--- shopping.org, the refiled Task verbatim ---")
(with-temp-buffer
  (insert-file-contents (concat proto-org "shopping.org"))
  (goto-char (point-min))
  (if (re-search-forward "coffee grinder" nil t)
      (progn (org-mode) (org-back-to-heading t)
             (proto-say "%s" (buffer-substring-no-properties
                              (point) (progn (org-end-of-subtree t) (point)))))
    (proto-say "!! not found in shopping.org")))
(proto-say "--- inbox after the refile ---\n%s"
           (proto-file-contents (org-gtd--path "inbox")))
(proto-say "--- org-gtd-tasks.org after the refile ---\n%s"
           (proto-file-contents (org-gtd--path org-gtd-default-file-name)))

(proto-say "\n========== STEP 4: do the views see it ==========")
(dolist (cmd '(org-gtd-engage org-gtd-show-all-next))
  (condition-case err
      (progn
        (funcall cmd)
        (with-current-buffer org-agenda-buffer-name
          (proto-say "--- %s (%d chars) ---\n%s" cmd (buffer-size)
                     (buffer-substring-no-properties (point-min) (point-max)))))
    (error (proto-say "!! %s failed: %S" cmd err))))

(proto-say "\n========== DONE ==========")
