;;; init-local-hel.el --- Hel modal editing settings -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defconst my/hel-minimum-emacs-version "29.1"
  "Minimum Emacs version supported by Hel.")

(defvar my/hel--installing nil
  "Non-nil while async-installer is cloning a Hel package.")

;; Hel defaults to a bar in Normal state and a box in Insert state.
(setq hel-normal-state-cursor-type 'box
      hel-insert-state-cursor-type 'bar)

(defun my/save-all-buffers ()
  "Save every modified file-visiting buffer without prompting."
  (interactive)
  (save-some-buffers t))

(defun my/hel-setup-leader ()
  "Configure native leader bindings in Hel Normal and Emacs states."
  ;; Keep lowercase g available for the Git group; use SPC G for C-M-.
  (setq hel-leader-ctrl-meta-prefix "G")
  (hel-keymap-global-set :state '(normal emacs)
    ;; Numeric arguments and help.
    "C-c 1" #'digit-argument
    "C-c 2" #'digit-argument
    "C-c 3" #'digit-argument
    "C-c 4" #'digit-argument
    "C-c 5" #'digit-argument
    "C-c 6" #'digit-argument
    "C-c 7" #'digit-argument
    "C-c 8" #'digit-argument
    "C-c 9" #'digit-argument
    "C-c 0" #'digit-argument
    "C-c /" #'describe-key
    "C-c ?" #'describe-bindings

    ;; High frequency.
    "C-c :" #'execute-extended-command
    "C-c ." #'find-file
    "C-c ," #'switch-to-buffer
    "C-c ;" #'insert-timestamp
    "C-c k" #'kill-this-buffer
    "C-c f" #'find-file
    "C-c i" #'imenu
    "C-c F" #'toggle-frame-maximized
    "C-c r" #'consult-recent-file

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

    ;; Claude / comment / clock.
    "C-c a c" #'claude-code-ide
    "C-c a m" #'claude-code-ide-menu
    "C-c a /" #'comment-dwim
    "C-c a t" #'org-clock-update-time-maybe
    "C-c a i" #'org-clock-in
    "C-c a o" #'org-clock-out
    "C-c a p i" #'bh/punch-in
    "C-c a p o" #'bh/punch-out
    "C-c a g" #'org-clock-goto
    "C-c a l t" #'bh/clock-in-last-task
    "C-c a s" #'kk/org-clock-in-switch-task

    ;; Eval / eshell / ediff.
    "C-c e e" #'eval-last-sexp
    "C-c e s" #'eshell
    "C-c e c" #'eshell-current-directory
    "C-c e d" #'ediff
    "C-c e b" #'ediff-buffers
    "C-c e w" #'ml-init-ediff-current-with-other-window

    ;; Edit / Denote / Dired.
    "C-c d d" #'kill-whole-line
    "C-c d w" #'delete-trailing-whitespace
    "C-c d D" #'move-dup-duplicate-down
    "C-c d n" #'denote
    "C-c d r" #'denote-rename-file
    "C-c d c" #'ai/cd-to-current-buffer
    "C-c d i" #'dired
    "C-c d p" #'pwd

    ;; Git / translate / Ghostel.
    "C-c g s" #'magit-status
    "C-c g b" #'emacs-solo/switch-git-status-buffer
    "C-c g i" #'magit
    "C-c g d" #'magit-diff-working-tree
    "C-c g t" #'gt-translate
    "C-c g p" #'my/git-push
    "C-c g l" #'magit-log-current
    "C-c g f" #'my/git-pull-ff-only
    "C-c g P" #'ml-gt-polish-using-llm
    "C-c g h" #'ghostel

    ;; Highlight.
    "C-c h l" #'pulsar-highlight-permanently-dwim

    ;; Project.
    "C-c p p" #'project-find-file

    ;; Denote journal.
    "C-c j n" #'my/denote-journal-new-or-existing-entry
    "C-c j t" #'my/denote-journal-new-entry-with-open-todos
    "C-c j o" #'denote-journal-new-or-existing-entry

    ;; Blinko.
    "C-c n b" #'blinko-post-buffer
    "C-c n r" #'blinko-post-region
    "C-c n p" #'blinko-post-content

    ;; Org.
    "C-c o a" #'org-agenda
    "C-c o l" #'org-todo-list
    "C-c o m" #'org-tags-view
    "C-c o v" #'org-search-view
    "C-c o t" #'org-todo
    "C-c o c" #'org-capture
    "C-c o d" #'org-deadline
    "C-c o s" #'org-schedule
    "C-c o r" #'org-refile
    "C-c o p" #'org-priority
    "C-c o g" #'org-goto
    "C-c o o" #'org-open-at-point
    "C-c o i l" #'org-insert-link
    "C-c o i h" #'org-insert-heading
    "C-c o i s" #'org-insert-subheading
    "C-c o n l" #'org-now-link
    "C-c o n t" #'org-now

    ;; Session.
    "C-c q q" #'save-buffers-kill-terminal
    "C-c q r" #'restart-emacs

    ;; Search / supertag.
    "C-c s g r" #'rgrep
    "C-c s c g" #'consult-ripgrep
    "C-c s c f" #'consult-fd
    "C-c s c h" #'consult-org-heading
    "C-c s g h n" #'rg-search-everything
    "C-c s c d" #'consult-dir
    "C-c s s" #'supertag-search
    "C-c s t" #'supertag-add-tag
    "C-c s T" #'supertag-remove-tag-from-node
    "C-c s v" #'supertag-view-table
    "C-c s n" #'supertag-view-node
    "C-c s k" #'supertag-view-kanban
    "C-c s m" #'supertag-view-schema
    "C-c s i" #'supertag-capture
    "C-c s r" #'supertag-add-reference
    "C-c s u" #'supertag-sync-full-rescan

    ;; Tab.
    "C-c t n" #'tab-new
    "C-c t c" #'tab-close

    ;; Window.
    "C-c w w" #'other-window
    "C-c w o" #'sanityinc/delete-other-windows
    "C-c w q" #'sanityinc/delete-window
    "C-c w v" #'split-window-right
    "C-c w h" #'split-window-below

    ;; Zoxide.
    "C-c z f" #'zoxide-find-file
    "C-c z t" #'zoxide-travel
    "C-c z d" #'zoxide-cd))

(defun my/hel--activate ()
  "Load Hel and hel-leader, configure them, and enable Hel globally."
  (when (and (require 'hel nil t)
             (require 'hel-leader nil t))
    (hel-set-initial-state 'dired-mode 'normal)
    (my/hel-setup-leader)
    (hel-mode 1)
    t))

(defun my/hel--missing-package ()
  "Return the first unavailable Hel package name."
  (seq-find (lambda (name)
              (not (locate-library name)))
            '("hel" "hel-leader")))

(defun my/hel--install ()
  "Install missing Hel packages asynchronously through async-installer."
  (when (boundp 'async-installer-git-list)
    (let* ((name (my/hel--missing-package))
           (suffix (and name (concat "/" name ".git")))
           (package
            (and suffix
                 (seq-find
                  (lambda (entry)
                    (string-suffix-p suffix (plist-get entry :repo)))
                  async-installer-git-list))))
      (when (and package (not my/hel--installing))
        (setq my/hel--installing t)
        (async-installer-git--install-one
         package
         (lambda (dir)
           (setq my/hel--installing nil)
           (if dir
               (progn
                 (add-to-list 'load-path dir)
                 (let ((next (my/hel--missing-package)))
                   (cond
                    ((equal next name)
                     (message "%s installed but its library is unavailable" name))
                    (next
                     (my/hel--install))
                    ((not (my/hel--activate))
                     (message "Hel packages installed but activation failed")))))
             (message "%s installation failed" name))))))))

(if (version< emacs-version my/hel-minimum-emacs-version)
    (message "Hel requires Emacs %s or newer; running without Hel"
             my/hel-minimum-emacs-version)
  (dolist (package '(dash s avy pcre2el ultra-scroll))
    (require-package package))
  (dolist (name '("hel" "hel-leader"))
    (let ((dir (expand-file-name (concat "external-packages/" name)
                                 user-emacs-directory)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir))))
  (unless (or (my/hel--activate) noninteractive)
    (my/hel--install)))

(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "C-c :"   "M-x"
    "C-c ."   "Find file"
    "C-c ,"   "Switch buffer"
    "C-c ;"   "Insert timestamp"
    "C-c b"   "buffer"
    "C-c b n" "Next buffer"
    "C-c b p" "Prev buffer"
    "C-c b s" "Save buffer"
    "C-c b a" "Save all buffers"
    "C-c b k" "Kill current buffer"
    "C-c b o" "Read only mode"
    "C-c b m" "View message buffer"
    "C-c b e" "Eval buffer"
    "C-c b r" "Revert buffer"
    "C-c a"     "claude / comment / clock"
    "C-c a c"   "Claude Code IDE"
    "C-c a m"   "Claude Code menu"
    "C-c a /"   "Comment dwim"
    "C-c a t"   "Update time"
    "C-c a i"   "Start clock"
    "C-c a o"   "Stop clock"
    "C-c a p"   "punch"
    "C-c a p i" "Punch in clock"
    "C-c a p o" "Punch out clock"
    "C-c a g"   "Go to clock"
    "C-c a l"   "last task"
    "C-c a l t" "Clock in last task"
    "C-c a s"   "Switch task"
    "C-c e"   "eval / eshell / ediff"
    "C-c e e" "Eval last sexp"
    "C-c e s" "Start eshell"
    "C-c e c" "Eshell current directory"
    "C-c e d" "Ediff"
    "C-c e b" "Ediff buffers"
    "C-c e w" "Ediff current vs other window"
    "C-c d"   "edit / denote / dired"
    "C-c d d" "Kill whole line"
    "C-c d w" "Delete trailing whitespace"
    "C-c d D" "Duplicate line down"
    "C-c d n" "Create a denote"
    "C-c d r" "Rename denote file"
    "C-c d c" "Cd to current buffer dir"
    "C-c d i" "Dired"
    "C-c d p" "Show current directory"
    "C-c g"   "git / translate / ghostel"
    "C-c g s" "Magit status"
    "C-c g b" "Switch git status buffer"
    "C-c g i" "Magit"
    "C-c g d" "Git diff working tree"
    "C-c g t" "Translate"
    "C-c g p" "Git push"
    "C-c g l" "Git log"
    "C-c g f" "Git pull (ff-only)"
    "C-c g P" "Polish sentence"
    "C-c g h" "Ghostel terminal"
    "C-c h"   "highlight"
    "C-c h l" "Permanently highlight line"
    "C-c p"   "project"
    "C-c p p" "Project find file"
    "C-c j"   "denote journal"
    "C-c j n" "Create an entry"
    "C-c j t" "Entry with todos"
    "C-c j o" "Open current journal"
    "C-c n"   "blinko"
    "C-c n b" "Post buffer"
    "C-c n r" "Post region"
    "C-c n p" "Post content"
    "C-c o"     "org"
    "C-c o a"   "Agenda"
    "C-c o l"   "Todo list"
    "C-c o m"   "Tags search"
    "C-c o v"   "View search"
    "C-c o t"   "Todo change"
    "C-c o c"   "Capture"
    "C-c o d"   "Insert deadline"
    "C-c o s"   "Insert schedule"
    "C-c o r"   "Refile"
    "C-c o p"   "Change priority"
    "C-c o g"   "Lookup location"
    "C-c o o"   "Open at point"
    "C-c o i"   "insert"
    "C-c o i l" "Insert link"
    "C-c o i h" "Insert heading"
    "C-c o i s" "Insert subheading"
    "C-c o n"   "now"
    "C-c o n l" "Add link to org-now"
    "C-c o n t" "Toggle org-now side window"
    "C-c q"   "session"
    "C-c q q" "Quit Emacs"
    "C-c q r" "Restart Emacs"
    "C-c s"       "search / supertag"
    "C-c s g"     "rg"
    "C-c s g r"   "Search with rg"
    "C-c s g h"   "rg hidden"
    "C-c s g h n" "Search with rg everything"
    "C-c s c"     "consult"
    "C-c s c g"   "Consult ripgrep"
    "C-c s c f"   "Consult fd"
    "C-c s c h"   "Consult org heading"
    "C-c s c d"   "Consult dir"
    "C-c s s"     "Supertag search"
    "C-c s t"     "Add tag"
    "C-c s T"     "Remove tag"
    "C-c s v"     "Table view"
    "C-c s n"     "Node view"
    "C-c s k"     "Kanban view"
    "C-c s m"     "Schema view"
    "C-c s i"     "Supertag capture"
    "C-c s r"     "Add reference"
    "C-c s u"     "Full rescan"
    "C-c t"   "tab"
    "C-c t n" "New tab"
    "C-c t c" "Close tab"
    "C-c w"   "window"
    "C-c w w" "Other window"
    "C-c w o" "Only current window"
    "C-c w q" "Close current window"
    "C-c w v" "Split window right"
    "C-c w h" "Split window below"
    "C-c z"   "zoxide"
    "C-c z f" "Find file under zoxide path"
    "C-c z t" "Travel to zoxide path"
    "C-c z d" "Cd to zoxide path"))

(provide 'init-local-hel)
;;; init-local-hel.el ends here
