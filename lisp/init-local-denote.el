;;; init-local-denot.el --- denote settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;; denote
;; Remember that the website version of this manual shows the latest
;; developments, which may not be available in the package you are
;; using.  Instead of copying from the web site, refer to the version
;; of the documentation that comes with your package.  Evaluate:
;;
;;     (info "(denote) Sample configuration")
(use-package denote
  :ensure t)

;; Remember to check the doc strings of those variables.
(setq denote-directory (expand-file-name "~/Obsidian/Note/"))
(setq denote-save-buffers nil)
(setq denote-known-keywords '("emacs" "git" "software" "network" "ai" "economics"))
(setq denote-infer-keywords t)
(setq denote-sort-keywords t)
(setq denote-file-type 'markdown-yaml) ; Org is the default, set others here
(setq denote-prompts '(title keywords))
(setq denote-excluded-directories-regexp nil)
(setq denote-excluded-keywords-regexp nil)
(setq denote-rename-confirmations '(rewrite-front-matter modify-file-name))

;; Read this manual for how to specify `denote-templates'.  We do not
;; include an example here to avoid potential confusion.

(setq denote-date-format nil) ; read doc string

;; By default, we do not show the context of links.  We just display
;; file names.  This provides a more informative view.
(setq denote-backlinks-show-context t)

;; Also see `denote-backlinks-display-buffer-action' which is a bit
;; advanced.

;; If you use Markdown or plain text files (Org renders links as buttons
;; right away)
(add-hook 'text-mode-hook #'denote-fontify-links-mode-maybe)

;; We use different ways to specify a path for demo purposes.
(setq denote-dired-directories
      (list denote-directory
            (thread-last denote-directory (expand-file-name "attachments"))
            (expand-file-name "~/Documents/books")))

;; Generic (great if you rename files Denote-style in lots of places):
(add-hook 'dired-mode-hook #'denote-dired-mode)
;;
;; OR if only want it in `denote-dired-directories':
;; (add-hook 'dired-mode-hook #'denote-dired-mode-in-directories)

;; Automatically rename Denote buffers using the `denote-rename-buffer-format'.
(denote-rename-buffer-mode 1)

(defconst my/denote-journal-carry-forward-heading "## Carried Forward"
  "Heading used for carried-forward journal todos.")

(defun my/denote-journal--file-identifier (file)
  "Return Denote identifier for FILE, falling back to a filename regex."
  (or (and (fboundp 'denote-retrieve-filename-identifier)
           (denote-retrieve-filename-identifier file))
      (when (string-match "\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)"
                          (file-name-nondirectory file))
        (match-string 1 (file-name-nondirectory file)))))

(defun my/denote-journal--target-day (target-date)
  "Return TARGET-DATE as a YYYYMMDD string."
  (format-time-string
   "%Y%m%d"
   (cond
    ((null target-date) (current-time))
    ((stringp target-date)
     (or (ignore-errors (date-to-time target-date))
         (date-to-time (concat target-date " 00:00:00"))))
    (t target-date))))

(defun my/denote-journal-list-files ()
  "Return readable journal files from `denote-journal-directory'."
  (let ((journal-directory (if (fboundp 'denote-journal-directory)
                               (denote-journal-directory)
                             denote-journal-directory)))
    (seq-filter
     (lambda (file)
       (and (file-regular-p file)
            (file-readable-p file)
            (denote-journal-file-is-journal-p file)))
     (directory-files journal-directory t directory-files-no-dot-files-regexp t))))

(defun my/denote-journal-latest-prior-file (target-date files)
  "Return latest file from FILES with a journal day older than TARGET-DATE."
  (let ((target-day (my/denote-journal--target-day target-date))
        best-file
        best-identifier)
    (dolist (file files best-file)
      (let ((identifier (my/denote-journal--file-identifier file)))
        (when (and identifier
                   (string< (substring identifier 0 8) target-day)
                   (or (null best-identifier)
                       (string< best-identifier identifier)))
          (setq best-file file
                best-identifier identifier))))))

(defun my/denote-journal-open-checkbox-lines (file)
  "Return unfinished Markdown checkbox lines from FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let (items)
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*[-*+] \\[ \\] .*$" nil t)
        (push (string-trim-right
               (buffer-substring-no-properties (line-beginning-position)
                                               (line-end-position)))
              items))
      (nreverse items))))

(defun my/denote-journal--buffer-has-carry-forward-section-p ()
  "Return non-nil when current buffer already has carry-forward heading."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward
     (format "^%s$" (regexp-quote my/denote-journal-carry-forward-heading))
     nil t)))

(defun my/denote-journal--ensure-blank-line-before-point-max ()
  "Ensure a blank line separates the current tail from appended content."
  (goto-char (point-max))
  (unless (bobp)
    (unless (looking-back "\n\n" nil)
      (unless (looking-back "\n" nil)
        (insert "\n"))
      (insert "\n"))))

(defun my/denote-journal-insert-carry-forward-section (items)
  "Insert carry-forward section with ITEMS unless already present."
  (when (and items
             (not (my/denote-journal--buffer-has-carry-forward-section-p)))
    (my/denote-journal--ensure-blank-line-before-point-max)
    (insert my/denote-journal-carry-forward-heading "\n\n")
    (dolist (item items)
      (insert item "\n"))
    (insert "\n")))

(defun my/denote-journal-insert-timestamp ()
  "Append a timestamp heading at the end of the current journal buffer."
  (my/denote-journal--ensure-blank-line-before-point-max)
  (insert (format-time-string "# %H:%M #\n\n")))

(defun my/denote-journal--finalize-entry ()
  "Append timestamp to current journal and enter Evil insert state."
  (let ((file buffer-file-name))
    (when (and file
               (fboundp 'denote-journal-file-is-journal-p)
               (denote-journal-file-is-journal-p file))
      (my/denote-journal-insert-timestamp)
      (when (fboundp 'evil-insert-state)
        (evil-insert-state)))))

(defun my/denote-journal-new-or-existing-entry (&optional date)
  "Open/create journal entry, append timestamp, then enter Evil insert state."
  (interactive
   (list
    (when current-prefix-arg
      (denote-date-prompt))))
  (denote-journal-new-or-existing-entry date)
  (my/denote-journal--finalize-entry))

(defun my/denote-journal-new-entry-with-open-todos (&optional date)
  "Open/create journal entry and carry open todos from latest earlier journal."
  (interactive
   (list
    (when current-prefix-arg
      (denote-date-prompt))))
  (denote-journal-new-or-existing-entry date)
  (let ((file buffer-file-name))
    (when (and file
               (fboundp 'denote-journal-file-is-journal-p)
               (denote-journal-file-is-journal-p file))
      (when-let* ((source-file
                   (my/denote-journal-latest-prior-file
                    (or (and-let* ((identifier (my/denote-journal--file-identifier file)))
                          (substring identifier 0 8))
                        date)
                    (my/denote-journal-list-files)))
                  (items (my/denote-journal-open-checkbox-lines source-file)))
        (my/denote-journal-insert-carry-forward-section items))
      (my/denote-journal--finalize-entry))))

(use-package denote-journal
  :ensure t
  ;; Bind those to some key for your convenience.
  ;; :commands ( denote-journal-new-entry
  ;;             denote-journal-new-or-existing-entry
  ;;             denote-journal-link-or-create-entry )
  :hook (calendar-mode . denote-journal-calendar-mode)
  :config
  ;; Use the "journal" subdirectory of the `denote-directory'.  Set this
  ;; to nil to use the `denote-directory' instead.
  (setq denote-journal-directory
        (expand-file-name "journal" denote-directory))
  ;; Default keyword for new journal entries. It can also be a list of
  ;; strings.
  (setq denote-journal-keyword "journal")
  ;; Read the doc string of `denote-journal-title-format'.
  (setq denote-journal-title-format ""))

(provide 'init-local-denote)
;;; init-local-denote.el ends here
