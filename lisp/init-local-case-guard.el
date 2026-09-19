;;; init-local-case-guard.el --- Stop silent case rewrites of ~/org -*- lexical-binding: t -*-
;;; Commentary:
;; Three times now something has upcased half of a file in ~/org: ai.org
;; (2026-09-12), hardware.org (2026-09-14) and software.org twice (2026-09-12,
;; 2026-09-17).  The damage is quiet and expensive.  org-gtd matches its
;; metadata by letter case, so `:ORG_GTD: Projects' turned into `PROJECTS' drops
;; the project out of every agenda query, and the upcased `:ID:' references break
;; the Edna links between tasks.  ~/org has no Git history and Syncthing's
;; .stversions copies ran two months stale on both recovery attempts, so the only
;; history is the live buffer's undo list.
;;
;; Earlier fixes closed key bindings: `C-x C-u' is unbound in `init-local', and
;; `init-local-hel' unbinds Hel's five case keys.  Those guards held on
;; 2026-09-17 and the damage still happened, so the entry path is still unknown.
;; Key bindings are therefore the wrong layer to defend, and this module adds
;; three layers that do not care how the caller arrived:
;;
;; 1. Advice on the case commands.  It asks before a large rewrite of a guarded
;;    file.  Both the region commands and the word commands are covered:
;;    `upcase-word' is a separate C subr, and `upcase-dwim' calls it whenever no
;;    region is active, so guarding only `upcase-region' leaves plain `M-u' free
;;    to upcase thousands of characters.
;; 2. An `after-change-functions' watcher that logs a backtrace at the moment a
;;    large equal-length rewrite happens.  A casify replaces a span with exactly
;;    as many characters as it removed, which is a precise and cheap signature.
;;    This is the layer that can name an unknown caller, because layers 1 and 3
;;    only see callers that use the case commands, or the damage after the fact.
;; 3. A save canary.  It refuses to write a guarded file that carries the damage
;;    signature, whatever produced it.
;;
;; Layer 3 advises `basic-save-buffer' and not `before-save-hook'.  A hook there
;; cannot stop a save: `basic-save-buffer' runs that hook inside
;; `with-demoted-errors', so Emacs reports the error and then writes the file
;; anyway.  Every save path reaches `basic-save-buffer', including the
;; `org-gtd-save-buffers' call that put the damage on disk on 2026-09-17.
;;
;; Every prompt uses `yes-or-no-p'.  `y-or-n-p' and the `disabled' property
;; prompt are no good here: their prompts accept SPC, which is the Hel leader
;; key, so the reflex answer runs the command.  `yes-or-no-p' needs a typed word.
;;
;; To switch the whole guard off:
;;   (dolist (f ml-case-guard-guarded-functions) (advice-remove f 'ml-case-guard))
;;; Code:

(require 'seq)

(defvar ml-case-guard-directories (list (expand-file-name "org/" "~"))
  "Directories whose files must not be case-rewritten without confirmation.")

(defvar ml-case-guard-region-threshold 200
  "Size, in characters, that makes a case command ask before it runs.
Counted over the region, or over the words a word command would reach.")

(defvar ml-case-guard-log-file (locate-user-emacs-file "case-guard.log")
  "File that records every guarded case command and every canary hit.
`*.log' is in .gitignore, so this stays out of the repository.")

(defvar ml-case-guard-canary-threshold 5
  "Number of damage-signature matches that blocks a save.
One stray line must not block a save, and a real event produces hundreds:
the 2026-09-17 software.org damage matched 211 times.")

(defvar ml-case-guard-canary-patterns
  '("^[ \t]*- STATE +\""
    "^[ \t]*:ORG_GTD: *[A-Z][A-Z]+"
    "^[ \t]*:TRIGGER: *[A-Z]")
  "Case-sensitive patterns that only appear after an accidental upcase.
Org writes `- State \"DONE\" from \"TODO\"', org-gtd writes `Projects' and
`Actions', and Edna triggers start with a lowercase `self', so the uppercase
forms are damage.  A scan of every file in ~/org after the 2026-09-17 repair
matched none of these.  Org keywords such as `#+FILETAGS:' and `#+AUTHOR:' are
left out because they are legitimately uppercase, and `:ID:' is left out
because org-gtd stores uppercase UUIDs there, so an uppercase ID is normal.

Every pattern must read a property with a closed vocabulary.  `:ORG_GTD:' holds
only `Actions' or `Projects', so an uppercase value there is damage.
`:ORG_GTD_PROJECT:' and `:ORG_GTD_PROJECT_IDS:' hold the project title and a
slug made from it, which are free text, so a project named `ER-X' or `PVE on
i5-8600K' is normal.  A pattern over those two matched 22 healthy lines and
blocked a save on 2026-09-18.  A real upcase hits `:ORG_GTD:' on the same
heading, so nothing is lost by reading only the closed vocabulary.")

(defvar ml-case-guard-guarded-functions
  '(upcase-region downcase-region capitalize-region upcase-initials-region
    upcase-word downcase-word capitalize-word
    basic-save-buffer)
  "Every function this module advises, so the guard can be removed in one step.")

(defun ml-case-guard--file ()
  "Return the visited file name when this buffer is under a guarded directory.
Follow indirect buffers to their base, because org-gtd clarifies a task in an
indirect buffer and that buffer carries no file name of its own."
  (let ((file (buffer-file-name (or (buffer-base-buffer) (current-buffer)))))
    (when (and file
               (seq-some (lambda (dir)
                           (and (file-directory-p dir)
                                (file-in-directory-p file dir)))
                         ml-case-guard-directories))
      file)))

(defun ml-case-guard--backtrace ()
  "Return the current backtrace as a string."
  (require 'backtrace)
  (backtrace-to-string (backtrace-get-frames 'ml-case-guard--backtrace)))

(defun ml-case-guard--log (event file detail)
  "Append EVENT about FILE, with DETAIL and a backtrace, to the log file."
  (ignore-errors
    (let ((coding-system-for-write 'utf-8))
      (write-region
       (concat (format "\n=== %s  %s ===\n" (format-time-string "%F %T") event)
               (format "file:     %s\n" (abbreviate-file-name file))
               (format "detail:   %s\n" detail)
               (format "command:  this=%S real=%S last=%S\n"
                       this-command real-this-command last-command)
               (ml-case-guard--backtrace))
       nil ml-case-guard-log-file t 'quiet))))

(defun ml-case-guard--confirm (file detail prompt message)
  "Ask PROMPT before touching FILE, and log DETAIL either way.
Signal a `user-error' carrying MESSAGE when the answer is no, or when Emacs
runs in batch and cannot ask."
  (if (and (not noninteractive) (yes-or-no-p prompt))
      (ml-case-guard--log "allowed" file detail)
    (ml-case-guard--log "refused" file detail)
    (user-error "%s" message)))

(defun ml-case-guard--ask (file original size detail)
  "Confirm that ORIGINAL may rewrite SIZE characters of FILE, logging DETAIL."
  (ml-case-guard--confirm
   file detail
   (format "Really %s %d characters of %s? "
           original size (abbreviate-file-name file))
   (format "%s refused: %s is guarded (see %s)"
           original (abbreviate-file-name file)
           (abbreviate-file-name ml-case-guard-log-file))))

(defun ml-case-guard--region (original beg end &rest args)
  "Guard ORIGINAL, a case command, over BEG to END with ARGS."
  (let ((file (ml-case-guard--file))
        (size (abs (- end beg))))
    (when (and file (>= size ml-case-guard-region-threshold))
      (ml-case-guard--ask file original size
                          (format "%s over %s..%s (%d chars)"
                                  original beg end size))))
  (apply original beg end args))

(defun ml-case-guard--word (original &optional arg &rest args)
  "Guard ORIGINAL, a case command that acts on ARG words from point, with ARGS.
`upcase-word' is a C subr of its own, and `upcase-dwim' calls it whenever no
region is active, so this is the route plain \\[upcase-word] takes."
  (let ((file (ml-case-guard--file))
        (size (abs (- (save-excursion (forward-word (or arg 1)) (point))
                      (point)))))
    (when (and file (>= size ml-case-guard-region-threshold))
      (ml-case-guard--ask file original size
                          (format "%s over %s words (%d chars)" original arg size))))
  (apply original arg args))

(defun ml-case-guard--after-change (beg end len)
  "Log a large equal-length rewrite of BEG to END, replacing LEN characters.
A casify puts back exactly as many characters as it took out, so this is the
signature of the damage.  It only records: the point is the backtrace, which
names the caller at the moment of the change rather than at the later save."
  (when (and (= len (- end beg))
             (>= len ml-case-guard-region-threshold))
    (let ((file (ml-case-guard--file)))
      (when file
        (ml-case-guard--log "equal-length-rewrite" file
                            (format "%d chars at %d..%d" len beg end))))))

(defun ml-case-guard--watch-buffer ()
  "Watch this buffer for equal-length rewrites when it visits a guarded file."
  (when (ml-case-guard--file)
    (add-hook 'after-change-functions #'ml-case-guard--after-change nil t)))

(defun ml-case-guard-canary-count ()
  "Return how many damage-signature lines the current buffer holds."
  (save-excursion
    (save-restriction
      (widen)
      (let ((case-fold-search nil)
            (count 0))
        (dolist (pattern ml-case-guard-canary-patterns count)
          (goto-char (point-min))
          (while (re-search-forward pattern nil t)
            (setq count (1+ count))))))))

(defun ml-case-guard--check-save (&rest _)
  "Block a save that would write upcased org metadata to a guarded file.
This is the layer that does not care how the damage arrived.  Used as
`:before' advice on `basic-save-buffer', so a `user-error' raised here aborts
the save instead of being demoted to a message."
  (let ((file (ml-case-guard--file)))
    (when file
      (let ((hits (ml-case-guard-canary-count)))
        (when (>= hits ml-case-guard-canary-threshold)
          (ml-case-guard--confirm
           file (format "%d upcased metadata lines" hits)
           (format "%s looks upcased (%d lines).  Save anyway? "
                   (abbreviate-file-name file) hits)
           (format (concat "Save blocked: %s holds %d upcased metadata lines;"
                           " undo first.  Any later buffer in this save is"
                           " still unsaved (see %s)")
                   (abbreviate-file-name file) hits
                   (abbreviate-file-name ml-case-guard-log-file))))))))

(dolist (command '(upcase-region downcase-region
                   capitalize-region upcase-initials-region))
  (advice-add command :around #'ml-case-guard--region '((name . ml-case-guard))))

(dolist (command '(upcase-word downcase-word capitalize-word))
  (advice-add command :around #'ml-case-guard--word '((name . ml-case-guard))))

(advice-add 'basic-save-buffer :before #'ml-case-guard--check-save
            '((name . ml-case-guard)))

(add-hook 'find-file-hook #'ml-case-guard--watch-buffer)

;; Buffers opened before this module loaded need the watcher too.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer (ml-case-guard--watch-buffer)))

(provide 'init-local-case-guard)
;;; init-local-case-guard.el ends here
