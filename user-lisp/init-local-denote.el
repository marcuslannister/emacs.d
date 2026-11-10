;;; init-local-denote.el --- Denote notes and the Denote journal -*- lexical-binding: t -*-
;;; Commentary:
;; Denote keeps notes in plain files with the identifier in the file name.  The notes
;; folder is ~/Obsidian/Note/.  Denote settings apply when Denote loads, and a machine
;; without the folder is fine: Denote makes it on first use.
;;
;; The journal commands add two things to Denote Journal: a timestamp heading at the
;; end of each entry, and an entry that carries the open checkbox lines of the
;; latest earlier journal file forward.  The checkbox lines are Markdown, because the
;; notes use `markdown-yaml'.
;;; Code:

(require 'seq)
(require 'subr-x)

(defvar denote-directory)
(defvar denote-journal-directory)
(declare-function denote-date-prompt "denote")
(declare-function denote-journal-file-is-journal-p "denote-journal")
(declare-function denote-journal-new-or-existing-entry "denote-journal")
(declare-function denote-retrieve-filename-identifier "denote")
(declare-function my/hel-leader-bind "init-local-hel")

(use-package denote
  :ensure t
  ;; Show Denote links in Markdown and plain text files; Org shows them as buttons.
  :hook ((text-mode . denote-fontify-links-mode-maybe)
         (dired-mode . denote-dired-mode))
  :custom
  (denote-directory (expand-file-name "~/Obsidian/Note/"))
  (denote-save-buffers nil)
  (denote-known-keywords '("emacs" "git" "software" "network" "ai" "economics"))
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-file-type 'markdown-yaml)
  (denote-prompts '(title keywords))
  (denote-excluded-directories-regexp nil)
  (denote-excluded-keywords-regexp nil)
  (denote-rename-confirmations '(rewrite-front-matter modify-file-name))
  (denote-date-format nil)
  (denote-backlinks-show-context t)
  (denote-dired-directories
   (list denote-directory
         (expand-file-name "attachments" denote-directory)
         (expand-file-name "~/Documents/books")))
  :config
  ;; Name Denote buffers by `denote-rename-buffer-format'.
  (denote-rename-buffer-mode 1))

(use-package denote-journal
  :ensure t
  :hook (calendar-mode . denote-journal-calendar-mode)
  :custom
  ;; The journal subfolder of `denote-directory'.
  (denote-journal-directory (expand-file-name "journal" denote-directory))
  (denote-journal-keyword "journal")
  (denote-journal-title-format ""))

(defconst my/denote-journal-carry-forward-heading "## Carried Forward"
  "Heading of the section with the carried-forward journal todos.")

(defun my/denote-journal--file-identifier (file)
  "Return the Denote identifier of FILE, or one found in its name."
  (or (and (fboundp 'denote-retrieve-filename-identifier)
           (denote-retrieve-filename-identifier file))
      (when (string-match "\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)"
                          (file-name-nondirectory file))
        (match-string 1 (file-name-nondirectory file)))))

(defun my/denote-journal--target-day (target-date)
  "Return TARGET-DATE as a YYYYMMDD string.
TARGET-DATE is nil (today), a time value, or a date string."
  (format-time-string
   "%Y%m%d"
   (cond
    ((null target-date) (current-time))
    ((stringp target-date)
     (or (ignore-errors (date-to-time target-date))
         (date-to-time (concat target-date " 00:00:00"))))
    (t target-date))))

(defun my/denote-journal-list-files ()
  "Return the readable journal files in `denote-journal-directory'."
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
  "Return the latest file of FILES whose journal day is before TARGET-DATE."
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
  "Return the unfinished Markdown checkbox lines of FILE."
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
  "Return non-nil when the current buffer has the carry-forward heading."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward
     (format "^%s$" (regexp-quote my/denote-journal-carry-forward-heading))
     nil t)))

(defun my/denote-journal--ensure-blank-line-before-point-max ()
  "Move to the end of the buffer, and leave a blank line before appended text."
  (goto-char (point-max))
  (unless (bobp)
    (unless (looking-back "\n\n" nil)
      (unless (looking-back "\n" nil)
        (insert "\n"))
      (insert "\n"))))

(defun my/denote-journal-insert-carry-forward-section (items)
  "Insert the carry-forward section with ITEMS, unless the buffer has one."
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

(defun my/denote-journal--journal-buffer-p ()
  "Return non-nil when the current buffer visits a journal file."
  (and buffer-file-name
       (fboundp 'denote-journal-file-is-journal-p)
       (denote-journal-file-is-journal-p buffer-file-name)))

(defun my/denote-journal-new-or-existing-entry (&optional date)
  "Open or create the journal entry for DATE, and append a timestamp heading.
With a prefix argument, ask for the date."
  (interactive (list (when current-prefix-arg (denote-date-prompt))))
  (denote-journal-new-or-existing-entry date)
  (when (my/denote-journal--journal-buffer-p)
    (my/denote-journal-insert-timestamp)))

(defun my/denote-journal-new-entry-with-open-todos (&optional date)
  "Open or create the journal entry for DATE, and carry open todos into it.
The todos come from the latest journal file before that day.  With a prefix
argument, ask for the date."
  (interactive (list (when current-prefix-arg (denote-date-prompt))))
  (denote-journal-new-or-existing-entry date)
  (when (my/denote-journal--journal-buffer-p)
    (when-let* ((source-file
                 (my/denote-journal-latest-prior-file
                  (or (and-let* ((identifier (my/denote-journal--file-identifier
                                              buffer-file-name)))
                        (substring identifier 0 8))
                      date)
                  (my/denote-journal-list-files)))
                (items (my/denote-journal-open-checkbox-lines source-file)))
      (my/denote-journal-insert-carry-forward-section items))
    (my/denote-journal-insert-timestamp)))

(my/hel-leader-bind
 "C-c d n" #'denote
 "C-c d r" #'denote-rename-file
 "C-c j n" #'my/denote-journal-new-or-existing-entry
 "C-c j t" #'my/denote-journal-new-entry-with-open-todos
 "C-c j o" #'denote-journal-new-or-existing-entry)

(provide 'init-local-denote)
;;; init-local-denote.el ends here
