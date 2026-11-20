;;; init-local-hel.el --- Hel modal editing and its leader keys -*- lexical-binding: t -*-
;;; Commentary:
;; Hel is a Helix-style modal editing package, and hel-leader turns SPC into the
;; C-c prefix.  Both come from Git (init-local-package-list.el).  Hel starts at
;; startup when the clones exist, and otherwise right after the first install.
;;
;; The leader keys live in one table, `my/hel-leader-bindings'.  A module that
;; owns a command adds its own keys with `my/hel-leader-bind', so a key never
;; points at a command this config does not have.  test-startup.sh checks every
;; entry, in Normal and Emacs state.  Built-in Which-Key shows the available
;; keys and labels after a prefix, including the Hel leader.
;;
;; B binds C-a, C-v, C-z, M-w, and C-w globally.  Hel binds none of C-a, C-v,
;; C-z, M-w in any state, so those four keep B's meaning, and B's C-v (yank)
;; needs no copy in a Hel state map.  C-w differs.  Normal and Emacs state take
;; it for the Hel window map.  Insert state in the minibuffer and in text, prog,
;; and conf buffers takes it for `hel-delete-backward-word' (Hel's integration
;; file does this), which is what the earlier configuration did.  The Local layer
;; wins here: a word delete is what C-w means while typing text in a modal
;; editor.  B's `my-cut' stays on C-w in other modes, and Hel's own d and C cut
;; in Normal state.  test-startup.sh checks the five keys in the three states.
;;
;; The leader exists only in Normal and Emacs state.  In Insert state, B's own
;; C-c keys apply (for example C-c r is B's replace command).
;;; Code:

(defvar hel-mode)
(defvar hel-state)
(defvar hel-leader-ctrl-meta-prefix)
(defvar hel--cursors-table)
(declare-function nn-mode-line-set "init-display")
(declare-function hel-keymap-global-set "hel-core")
(declare-function hel-keymap-set "hel-core")
(declare-function hel-set-initial-state "hel-core")
(declare-function hel-set-single-cursor-command "hel-core")
(declare-function hel-mode "hel")
(declare-function hel-end-of-line "hel-commands")
(declare-function hel-mark-inner-word "hel-commands")
(declare-function hel-construct-search-pattern "hel-search")
(declare-function hel-search-next "hel-search")

;; Hel defaults to a bar in Normal state and a box in Insert state.
(setq hel-normal-state-cursor-type 'box
      hel-insert-state-cursor-type 'bar)

;;;; Key previews

(use-package which-key
  :ensure nil
  :demand t
  :custom
  (which-key-idle-delay 1.5)
  :config
  (which-key-mode 1)
  ;; Match the Earlier configuration, but describe the commands this fork uses.
  (which-key-add-key-based-replacements
    "C-c :" "M-x"                     "C-c ." "Find file"
    "C-c ," "Switch buffer"           "C-c ;" "Insert timestamp"
    "C-c b" "buffer"
    "C-c b n" "Next buffer"           "C-c b p" "Previous buffer"
    "C-c b s" "Save buffer"           "C-c b a" "Save all buffers"
    "C-c b k" "Kill current buffer"   "C-c b o" "Read-only mode"
    "C-c b m" "View messages"         "C-c b e" "Evaluate buffer"
    "C-c b r" "Revert buffer"         "C-c b y" "Copy buffer file name"
    "C-c a" "comment / clock"
    "C-c a /" "Comment"               "C-c a t" "Update time"
    "C-c a i" "Start clock"           "C-c a o" "Stop clock"
    "C-c a p" "punch"
    "C-c a p i" "Punch in clock"      "C-c a p o" "Punch out clock"
    "C-c a g" "Go to clock"           "C-c a s" "Switch task"
    "C-c e" "eval / eshell / ediff / grammar"
    "C-c e e" "Evaluate last sexp"    "C-c e s" "Start Eshell"
    "C-c e d" "Ediff"                 "C-c e b" "Ediff buffers"
    "C-c e w" "Ediff current and other window"
    "C-c e g" "grammar"
    "C-c e g g" "Harper on / off"     "C-c e g a" "Grammar fixes"
    "C-c d" "edit / denote / dired"
    "C-c d d" "Kill whole line"       "C-c d w" "Delete trailing whitespace"
    "C-c d D" "Duplicate line"        "C-c d n" "Create a Denote note"
    "C-c d r" "Rename Denote file"    "C-c d i" "Dired"
    "C-c d p" "Show current directory"
    "C-c g" "git / translate / proofread / ghostel"
    "C-c g s" "VC status"             "C-c g i" "VC next action"
    "C-c g d" "Git diff working tree" "C-c g u" "Git push"
    "C-c g l" "Git log"               "C-c g f" "Git pull"
    "C-c g t" "Translate"             "C-c g p" "Polish region"
    "C-c g h" "Ghostel terminal"
    "C-c g n" "New Ghostel buffer"    "C-c g o" "Ghostel project terminal"
    "C-c h" "Herdr"                   "C-c h e" "Open Herdr"
    "C-c p" "project"                 "C-c p p" "Project find file"
    "C-c j" "Denote journal"
    "C-c j n" "Create an entry"       "C-c j t" "Entry with open tasks"
    "C-c j o" "Open current journal"
    "C-c n" "notes"                   "C-c n r" "refile note"
    "C-c n r t" "Refile to Today"     "C-c n r i" "Refile to Inbox"
    "C-c n d" "Note to bottom"        "C-c n n" "Append note"
    "C-c n o" "Open notes"            "C-c n u" "Note to top"
    "C-c n t" "Add tag"               "C-c n s" "Show tag"
    "C-c c" "GTD"                     "C-c o" "Org"
    "C-c o a" "Agenda"                "C-c o l" "Task list"
    "C-c o m" "Tags search"           "C-c o v" "View search"
    "C-c o t" "Change task state"     "C-c o c" "Capture"
    "C-c o d" "Insert deadline"       "C-c o s" "Insert schedule"
    "C-c o r" "Refile"                "C-c o p" "Change priority"
    "C-c o G" "Go to heading"         "C-c o o" "Open at point"
    "C-c o e" "Engage"                "C-c o k" "Clarify at point"
    "C-c o g" "Org GTD"
    "C-c o g c" "Capture to inbox"    "C-c o g e" "Engage"
    "C-c o g i" "Process inbox"       "C-c o g k" "Clarify at point"
    "C-c o g m" "Command center"      "C-c o g n" "All next actions"
    "C-c o g p" "All projects"        "C-c o g s" "Stuck projects"
    "C-c o g o" "Organize task"       "C-c o g a" "Agenda task menu"
    "C-c o i" "insert"
    "C-c o i c" "Create ID"           "C-c o i l" "Insert link"
    "C-c o i h" "Insert heading"      "C-c o i s" "Insert subheading"
    "C-c q" "session"
    "C-c q q" "Quit Emacs"            "C-c q r" "Restart Emacs"
    "C-c s" "search"                  "C-c s g" "rg"
    "C-c s g r" "Search with rg"       "C-c s c" "file / text / heading"
    "C-c s c g" "Search current directory" "C-c s c f" "Project find file"
    "C-c s c h" "Find heading"        "C-c s b" "Scratch buffer"
    "C-c t" "tab"
    "C-c t n" "New tab"               "C-c t c" "Close tab"
    "C-c t g" "New tab with terminal"
    "C-c v" "Vulpea"
    "C-c v f" "Find note"             "C-c v i" "Insert link"
    "C-c v a" "Add tag"               "C-c v A" "Remove tag"
    "C-c v u" "Full rescan"           "C-c v b" "Backlinks"
    "C-c w" "window"
    "C-c w w" "Other window"          "C-c w o" "Only current window"
    "C-c w q" "Close current window" "C-c w v" "Split window right"
    "C-c w h" "Split window below"
    "C-c z" "zoxide"                  "C-c z t" "Travel to zoxide path"))

;;;; The leader table

(defvar my/hel-leader-bindings nil
  "Alist of (KEY . COMMAND) for the leader keys, as C-c sequences.
Add entries with `my/hel-leader-bind'.")

(defun my/hel--bind (bindings)
  "Bind the (KEY . COMMAND) pairs of BINDINGS in Hel Normal and Emacs state."
  (when bindings
    (apply #'hel-keymap-global-set :state '(normal emacs)
           (mapcan (lambda (binding) (list (car binding) (cdr binding))) bindings))))

(defun my/hel-leader-bind (&rest args)
  "Add the KEY COMMAND pairs in ARGS to the leader table.
KEY is a C-c sequence such as \"C-c b n\".  When Hel is already active, bind them
at once."
  (let (added)
    (while args
      (let ((key (pop args))
            (command (pop args)))
        (setf (alist-get key my/hel-leader-bindings nil nil #'equal) command)
        (push (cons key command) added)))
    (when (bound-and-true-p hel-mode)
      (my/hel--bind added))))

;; The commands of init-local-commands.el load on first use.
(dolist (command '(my/save-all-buffers my/copy-buffer-file-name my/insert-timestamp
                   my/ediff-current-with-other-window my/delete-other-windows
                   my/delete-window))
  (autoload command "init-local-commands" nil t))

;; / in Dired runs this command.  A terminal-only session does not load its module.
(autoload 'my/dired-goto-file-or-folder "init-local-dired" nil t)

(my/hel-leader-bind
 ;; Numeric arguments and help.
 "C-c 1" #'digit-argument "C-c 2" #'digit-argument "C-c 3" #'digit-argument
 "C-c 4" #'digit-argument "C-c 5" #'digit-argument "C-c 6" #'digit-argument
 "C-c 7" #'digit-argument "C-c 8" #'digit-argument "C-c 9" #'digit-argument
 "C-c 0" #'digit-argument
 "C-c /" #'describe-key
 "C-c ?" #'describe-bindings

 ;; High frequency.
 "C-c :" #'execute-extended-command
 "C-c ." #'find-file
 "C-c ," #'switch-to-buffer
 "C-c ;" #'my/insert-timestamp
 "C-c k" #'kill-current-buffer
 "C-c f" #'find-file
 "C-c i" #'imenu
 "C-c F" #'toggle-frame-maximized
 "C-c r" #'recentf-open

 ;; Buffer.
 "C-c b n" #'next-buffer
 "C-c b p" #'previous-buffer
 "C-c b s" #'basic-save-buffer
 "C-c b a" #'my/save-all-buffers
 "C-c b k" #'kill-current-buffer
 "C-c b o" #'read-only-mode
 "C-c b m" #'view-echo-area-messages
 "C-c b e" #'eval-buffer
 "C-c b r" #'revert-buffer
 "C-c b y" #'my/copy-buffer-file-name

 ;; Comment.
 "C-c a /" #'comment-dwim

 ;; Eval, eshell, ediff.
 "C-c e e" #'eval-last-sexp
 "C-c e s" #'eshell
 "C-c e d" #'ediff
 "C-c e b" #'ediff-buffers
 "C-c e w" #'my/ediff-current-with-other-window

 ;; Edit and Dired.
 "C-c d d" #'kill-whole-line
 "C-c d w" #'delete-trailing-whitespace
 "C-c d D" #'duplicate-dwim
 "C-c d i" #'dired
 "C-c d p" #'pwd

 ;; Git.
 "C-c g s" #'vc-dir-root
 "C-c g i" #'vc-next-action
 "C-c g d" #'vc-root-diff
 "C-c g u" #'vc-push
 "C-c g l" #'vc-print-root-log
 "C-c g f" #'vc-pull

 ;; Project.
 "C-c p p" #'project-find-file

 ;; Session.
 "C-c q q" #'save-buffers-kill-terminal
 "C-c q r" #'restart-emacs

 ;; Search.  Fido replaces the consult commands of the earlier configuration.
 "C-c s g r" #'rgrep
 "C-c s c g" #'my-rg-current-dir-all
 "C-c s c f" #'project-find-file
 "C-c s c h" #'imenu
 "C-c s b" #'scratch-buffer

 ;; Tab.
 "C-c t n" #'tab-new
 "C-c t c" #'tab-close

 ;; Window.
 "C-c w w" #'other-window
 "C-c w o" #'my/delete-other-windows
 "C-c w q" #'my/delete-window
 "C-c w v" #'split-window-right
 "C-c w h" #'split-window-below)

;;;; Commands that Hel needs

(defun my/hel-delete-to-end-of-line ()
  "Delete from point to end of line, without touching the `kill-ring'."
  (interactive "*")
  (delete-region (point) (hel-end-of-line)))

(defun my/hel--all-fake-cursors-safe (orig &rest args)
  "Call ORIG with ARGS only when the buffer has a Hel cursors table.
Hel's global `current-kill' advice lists fake cursors in every buffer,
but buffers without `hel-local-mode' (for example a minibuffer) have no table."
  (and hel--cursors-table (apply orig args)))

;;;; The Hel state in the mode line

(defconst my/hel--mode-line-segment '(:eval (my/hel-mode-line-state))
  "The mode line element that shows the Hel state.")

(defun my/hel-mode-line-state ()
  "Return the name of the Hel state of the current buffer, or nil."
  (when-let* ((state (bound-and-true-p hel-state)))
    (pcase state
      ('normal "NORMAL")
      ('insert "INSERT")
      ('emacs "EMACS")
      (_ (upcase (symbol-name state))))))

(defun my/hel--add-mode-line-segment (&rest _)
  "Put the Hel state first in the mode line that the Base installed here.
The Base builds the mode line in `nn-mode-line-set' from a constant list whose
Viper element is commented out.  This adds the Hel element after the first
element (\"%e\") of the buffer-local format, and only once."
  (when (and (local-variable-p 'mode-line-format)
             (consp mode-line-format)
             (equal (car mode-line-format) "%e")
             (not (member my/hel--mode-line-segment mode-line-format)))
    (setq-local mode-line-format
                (append (list "%e" "  " my/hel--mode-line-segment)
                        (cdr mode-line-format)))))

;;;; Activation

(defun my/hel--dired-cursor (original state property)
  "Use a block cursor in Dired's Hel Emacs state, keeping its color."
  (let ((value (funcall original state property)))
    (if (and (eq state 'emacs) (eq property :cursor) (derived-mode-p 'dired-mode))
        (cons 'box (cdr value))
      value)))

(defun my/hel--configure ()
  "Configure Hel and hel-leader once both are loaded."
  (hel-define-command my/hel-search-word-at-point (count)
    "Search for the word under point, like Vim's `*'.
Selects the word first when nothing is already selected, so an existing
manual selection is searched as-is instead of being replaced."
    :multiple-cursors nil
    (interactive "p")
    (hel-with-each-cursor
      (unless (use-region-p)
        (hel-mark-inner-word 1)))
    (hel-construct-search-pattern)
    (hel-search-next count))
  (hel-set-initial-state 'dired-mode 'emacs)
  (advice-add 'hel-state-property :around #'my/hel--dired-cursor)
  (hel-set-initial-state 'magit-mode 'emacs)
  (with-eval-after-load 'magit
    (hel-keymap-set magit-mode-map :state 'emacs
      "h" #'hel-backward-char
      "j" #'hel-next-line
      "k" #'hel-previous-line
      "l" #'hel-forward-char))
  (with-eval-after-load 'org-agenda
    (hel-keymap-set org-agenda-mode-map :state 'emacs
      "h" #'hel-backward-char
      "j" #'hel-next-line
      "k" #'hel-previous-line
      "l" #'hel-forward-char))
  ;; Dired starts in Emacs state, so its own m, u, d, C, and R keys work, and the
  ;; leader SPC still works.  Dired's own j opens "Goto file:" and k kills lines, so
  ;; h j k l move here instead.  In both states, / goes to a file in place of the
  ;; buffer search, and K kills lines.
  (with-eval-after-load 'dired
    (hel-keymap-set dired-mode-map :state 'emacs
      "h" #'hel-backward-char
      "j" #'hel-next-line
      "k" #'hel-previous-line
      "l" #'hel-forward-char)
    (hel-keymap-set dired-mode-map :state '(normal emacs)
      "/" #'my/dired-goto-file-or-folder
      "'" #'dired-up-directory
      "K" #'dired-do-kill-lines))
  (hel-keymap-global-set :state 'normal
    "d" #'hel-delete
    "D" #'my/hel-delete-to-end-of-line
    "C" #'hel-cut
    "p" #'hel-paste-before
    "P" #'hel-paste-after
    "*" #'my/hel-search-word-at-point)
  ;; Keep lowercase g available for the Git group; use SPC G for C-M-.
  (setq hel-leader-ctrl-meta-prefix "G")
  (my/hel--bind my/hel-leader-bindings)
  ;; Drop Hel's one-key case commands.  They rewrite the whole live selection,
  ;; and `hel-upcase' calls `upcase-region' as a plain function, so no `disabled'
  ;; property can stop it: that flag is checked for interactive calls only.
  ;; Unbinding is the only layer that works here.  "`" sits under Escape and "~"
  ;; is Shift-"`", so a mis-hit is cheap to make and expensive to find.  The case
  ;; guard covers the region commands as well; this is a second layer.
  (hel-keymap-global-set :state 'normal
    "`" nil "M-`" nil "~" nil "g u" nil "g U" nil)
  (advice-add 'hel-all-fake-cursors :around #'my/hel--all-fake-cursors-safe)
  (hel-mode 1)
  ;; Mouse selection must not open a recursive prompt during a drag.  Apply
  ;; after Hel loads the saved cursor-command choices.
  (hel-set-single-cursor-command 'mouse-set-region)
  ;; Buffers that exist now got their mode line before Hel was active.
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (my/hel--add-mode-line-segment))))

(defun my/hel--activate ()
  "Load Hel and hel-leader, configure them, and enable Hel globally.
Return non-nil when Hel is active.  A second call does nothing."
  (cond
   ((bound-and-true-p hel-mode) t)
   ((and (require 'hel nil t) (require 'hel-leader nil t))
    (my/hel--configure)
    t)))

(defun my/hel--activate-safely ()
  "Activate Hel, and warn instead of signalling when it cannot start.
A package that is present but fails to load (a dependency that is missing after
an offline first start) must not stop the startup of the Local layer."
  (condition-case err
      (my/hel--activate)
    (error (display-warning 'init-local-hel
                            (format "Hel could not start: %s" (error-message-string err)))
           nil)))

(defun my/hel--ensure-dependencies ()
  "Install the packages that Hel and hel-leader need, from the archives."
  ;; pcre2el puts a disabled `defadvice' on etags' `find-tag-regexp', so
  ;; loading etags later warned "got redefined".  This is global and hides the
  ;; redefinition warning of every `defadvice', as in the earlier configuration.
  (setq ad-redefinition-action 'accept)
  (use-package dash)
  (use-package s)
  (use-package avy)
  (use-package pcre2el)
  (use-package ultra-scroll))

(defun my/hel-setup ()
  "Start Hel now when its packages exist, and otherwise after the install.
Never signals: a failure warns and Hel stays off."
  (advice-add 'nn-mode-line-set :after #'my/hel--add-mode-line-segment)
  (my/hel--ensure-dependencies)
  (unless (my/hel--activate-safely)
    (add-hook 'my/async-installer-after-install-hook #'my/hel--activate-safely)))

(provide 'init-local-hel)
;;; init-local-hel.el ends here
