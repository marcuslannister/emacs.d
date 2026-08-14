;;; drive2.el --- PROTOTYPE driver, part 2 -- WIPE ME  -*- lexical-binding: t; -*-

;; Two checks #16 asked for:
;;   A. project in a topic file -> mark a task DONE from the agenda -> cookie?
;;   B. re-clarify a Task that already lives in a topic file -> where does it land?

(load "/tmp/org-gtd-proto/emacs/init.el")

;; The default `org-gtd-organize-hooks' is (org-set-tags-command), i.e. every
;; organize stops to ask for tags.  Off here so the batch run answers only the
;; prompts we care about -- but that default is itself a finding for #21.
(setq org-gtd-organize-hooks nil)

(defun proto-say (fmt &rest args) (princ (concat (apply #'format fmt args) "\n")))
(defun proto-contents (path)
  (if (file-exists-p path)
      (with-temp-buffer (insert-file-contents path) (buffer-string))
    (format "<<missing: %s>>" path)))
(defun proto-subtree (path re)
  "Return the subtree in PATH whose heading matches RE."
  (with-temp-buffer
    (insert-file-contents path)
    (org-mode)
    (goto-char (point-min))
    (if (re-search-forward re nil t)
        (progn (org-back-to-heading t)
               (buffer-substring-no-properties
                (point) (progn (org-end-of-subtree t) (point))))
      (format "<<%s not found in %s>>" re (file-name-nondirectory path)))))

;; Stand in for the human, keyed off the prompt so each question gets its own answer.
(defvar proto-refile-file "shopping.org")
(defun proto-answer (prompt &rest _)
  (cond
   ((string-prefix-p "Finish organizing task under" prompt)
    (let ((hit (seq-find (lambda (tgt)
                           (string-match-p proto-refile-file (or (nth 1 tgt) "")))
                         (org-refile-get-targets))))
      (proto-say "   [prompt] %s -> %S" (string-trim prompt) (car hit))
      (car hit)))
   (t (proto-say "   [prompt] UNEXPECTED: %s" (string-trim prompt)) "")))
(advice-add 'completing-read :override #'proto-answer)

(defun proto-capture (text)
  (let ((org-capture-templates org-gtd-capture-templates))
    (org-capture nil "i") (insert text) (org-capture-finalize))
  (org-save-all-org-buffers))

(defun proto-inbox-marker ()
  (let ((buf (find-file-noselect (org-gtd--path "inbox"))))
    (with-current-buffer buf
      (goto-char (point-min))
      (org-next-visible-heading 1)
      (point-marker))))

(proto-say "\n========== A. project into a topic file ==========")
(proto-capture "Plan the kitchen refit")
(let ((marker (proto-inbox-marker)))
  (org-gtd-clarify-item marker)
  ;; A project is the heading plus its child tasks, written during clarify.
  (goto-char (point-max))
  (insert "\n** TODO Measure the wall\n** TODO Choose the cabinets\n** TODO Book the fitter\n")
  (org-gtd-project-new))
(org-save-all-org-buffers)
(proto-say "--- project as written to shopping.org ---\n%s"
           (proto-subtree (concat proto-org "shopping.org") "kitchen refit"))

(proto-say "\n--- org-id-locations: what does it hold? ---")
(proto-say "%d ids registered; entries pointing at a non-file: %S"
           (hash-table-count org-id-locations)
           (let (bogus)
             (maphash (lambda (k v) (unless (file-exists-p v) (push (cons k v) bogus)))
                      org-id-locations)
             (seq-take bogus 4)))

(proto-say "\n--- mark 'Measure the wall' DONE from the agenda ---")
(org-gtd-engage)
(with-current-buffer org-agenda-buffer-name
  (goto-char (point-min))
  (if (re-search-forward "Measure the wall" nil t)
      (condition-case err (org-agenda-todo "DONE")
        (error (proto-say "!! org-agenda-todo failed: %S" err)))
    (proto-say "!! 'Measure the wall' is not in the engage view")))
(org-save-all-org-buffers)
(proto-say "--- project after one task DONE (cookie?) ---\n%s"
           (proto-subtree (concat proto-org "shopping.org") "kitchen refit"))

(proto-say "\n========== B. re-clarify a Task that lives in a topic file ==========")
(proto-capture "Buy a new coffee grinder")
(let ((marker (proto-inbox-marker)))
  (org-gtd-clarify-item marker)
  (org-gtd-single-action))
(org-save-all-org-buffers)
(proto-say "B0 first pass -> lives in shopping.org: %s"
           (if (string-match-p "coffee grinder"
                               (proto-contents (concat proto-org "shopping.org")))
               "yes" "NO"))

(defun proto-reclarify (label)
  "Re-clarify the coffee grinder Task wherever it is, then report where it lands."
  (let* ((files (list (concat proto-org "shopping.org")
                      (org-gtd--path org-gtd-default-file-name)))
         (home (seq-find (lambda (f) (string-match-p "coffee grinder" (proto-contents f)))
                         files)))
    (if (not home)
        (proto-say "%s: task lost!" label)
      (let ((marker (with-current-buffer (find-file-noselect home)
                      (goto-char (point-min))
                      (re-search-forward "coffee grinder" nil t)
                      (org-back-to-heading t)
                      (point-marker))))
        (org-gtd-clarify-item marker)
        (org-gtd-single-action))
      (org-save-all-org-buffers)
      (proto-say "%s: started in %s, now in %s"
                 label (file-name-nondirectory home)
                 (mapconcat #'file-name-nondirectory
                            (seq-filter (lambda (f)
                                          (string-match-p "coffee grinder" (proto-contents f)))
                                        (list (concat proto-org "shopping.org")
                                              (org-gtd--path org-gtd-default-file-name)))
                            " + ")))))

(proto-say "\nB1 prompting ON for single-action (the map's config):")
(proto-reclarify "B1")

(proto-say "\nB2 prompting OFF for single-action:")
(let ((org-gtd-refile-prompt-for-types '()))
  (proto-reclarify "B2"))

(proto-say "\nB3 prompting OFF, but the organize transient's -n toggle set:")
(let ((org-gtd-refile-prompt-for-types '()))
  ;; org-gtd-clarify--skip-refile is buffer-local in the WIP buffer; set the default
  (setq-default org-gtd-clarify--skip-refile t)
  (proto-reclarify "B3")
  (setq-default org-gtd-clarify--skip-refile nil))

(advice-remove 'completing-read #'proto-answer)
(proto-say "\n========== DONE ==========")
