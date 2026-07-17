;;; init-local-hel.el --- Hel modal editing settings -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defconst my/hel-minimum-emacs-version "29.1"
  "Minimum Emacs version supported by Hel.")

(defvar my/hel--installing nil
  "Non-nil while async-installer is cloning Hel.")

(defun my/save-all-buffers ()
  "Save every modified file-visiting buffer without prompting."
  (interactive)
  (save-some-buffers t))

(defun my/hel-setup-leader ()
  "Configure Hel leader bindings in Normal and Emacs states."
  (hel-keymap-global-set :state '(normal emacs)
    ;; Numeric arguments and help.
    "SPC 1" #'digit-argument
    "SPC 2" #'digit-argument
    "SPC 3" #'digit-argument
    "SPC 4" #'digit-argument
    "SPC 5" #'digit-argument
    "SPC 6" #'digit-argument
    "SPC 7" #'digit-argument
    "SPC 8" #'digit-argument
    "SPC 9" #'digit-argument
    "SPC 0" #'digit-argument
    "SPC /" #'describe-key
    "SPC ?" #'describe-bindings

    ;; High frequency.
    "SPC SPC" #'save-buffer
    "SPC :" #'execute-extended-command
    "SPC ." #'find-file
    "SPC ," #'switch-to-buffer
    "SPC ;" #'insert-timestamp
    "SPC k" #'kill-this-buffer
    "SPC f" #'find-file
    "SPC i" #'imenu
    "SPC F" #'toggle-frame-maximized
    "SPC r" #'consult-recent-file

    ;; Buffer.
    "SPC b n" #'next-buffer
    "SPC b p" #'previous-buffer
    "SPC b s" #'basic-save-buffer
    "SPC b a" #'my/save-all-buffers
    "SPC b k" #'kill-current-buffer
    "SPC b o" #'read-only-mode
    "SPC b m" #'view-echo-area-messages
    "SPC b e" #'eval-buffer
    "SPC b r" #'revert-buffer

    ;; Claude / comment / clock.
    "SPC c c" #'claude-code-ide
    "SPC c m" #'claude-code-ide-menu
    "SPC c /" #'comment-dwim
    "SPC c t" #'org-clock-update-time-maybe
    "SPC c i" #'org-clock-in
    "SPC c o" #'org-clock-out
    "SPC c p i" #'bh/punch-in
    "SPC c p o" #'bh/punch-out
    "SPC c g" #'org-clock-goto
    "SPC c l t" #'bh/clock-in-last-task
    "SPC c s" #'kk/org-clock-in-switch-task

    ;; Eval / eshell / ediff.
    "SPC e e" #'eval-last-sexp
    "SPC e s" #'eshell
    "SPC e c" #'eshell-current-directory
    "SPC e d" #'ediff
    "SPC e b" #'ediff-buffers
    "SPC e w" #'ml-init-ediff-current-with-other-window

    ;; Edit / Denote / Dired.
    "SPC d d" #'kill-whole-line
    "SPC d w" #'delete-trailing-whitespace
    "SPC d D" #'move-dup-duplicate-down
    "SPC d n" #'denote
    "SPC d r" #'denote-rename-file
    "SPC d c" #'ai/cd-to-current-buffer
    "SPC d i" #'dired
    "SPC d p" #'pwd

    ;; Git / translate / Ghostel.
    "SPC g s" #'magit-status
    "SPC g b" #'emacs-solo/switch-git-status-buffer
    "SPC g i" #'magit
    "SPC g d" #'magit-diff-working-tree
    "SPC g t" #'gt-translate
    "SPC g p" #'my/git-push
    "SPC g l" #'magit-log-current
    "SPC g f" #'my/git-pull-ff-only
    "SPC g P" #'ml-gt-polish-using-llm
    "SPC g h" #'ghostel

    ;; Highlight.
    "SPC h l" #'pulsar-highlight-permanently-dwim

    ;; Project.
    "SPC p p" #'project-find-file

    ;; Denote journal.
    "SPC j n" #'my/denote-journal-new-or-existing-entry
    "SPC j t" #'my/denote-journal-new-entry-with-open-todos
    "SPC j o" #'denote-journal-new-or-existing-entry

    ;; Blinko.
    "SPC n b" #'blinko-post-buffer
    "SPC n r" #'blinko-post-region
    "SPC n p" #'blinko-post-content

    ;; Org.
    "SPC o a" #'org-agenda
    "SPC o l" #'org-todo-list
    "SPC o m" #'org-tags-view
    "SPC o v" #'org-search-view
    "SPC o t" #'org-todo
    "SPC o c" #'org-capture
    "SPC o d" #'org-deadline
    "SPC o s" #'org-schedule
    "SPC o r" #'org-refile
    "SPC o p" #'org-priority
    "SPC o g" #'org-goto
    "SPC o o" #'org-open-at-point
    "SPC o i l" #'org-insert-link
    "SPC o i h" #'org-insert-heading
    "SPC o i s" #'org-insert-subheading
    "SPC o n l" #'org-now-link
    "SPC o n t" #'org-now

    ;; Session.
    "SPC q q" #'save-buffers-kill-terminal
    "SPC q r" #'restart-emacs

    ;; Search / supertag.
    "SPC s g r" #'rgrep
    "SPC s c g" #'consult-ripgrep
    "SPC s c f" #'consult-fd
    "SPC s c h" #'consult-org-heading
    "SPC s g h n" #'rg-search-everything
    "SPC s c d" #'consult-dir
    "SPC s s" #'supertag-search
    "SPC s t" #'supertag-add-tag
    "SPC s T" #'supertag-remove-tag-from-node
    "SPC s v" #'supertag-view-table
    "SPC s n" #'supertag-view-node
    "SPC s k" #'supertag-view-kanban
    "SPC s m" #'supertag-view-schema
    "SPC s i" #'supertag-capture
    "SPC s r" #'supertag-add-reference
    "SPC s u" #'supertag-sync-full-rescan

    ;; Tab.
    "SPC t n" #'tab-new
    "SPC t c" #'tab-close

    ;; Window.
    "SPC w w" #'other-window
    "SPC w o" #'sanityinc/delete-other-windows
    "SPC w q" #'sanityinc/delete-window
    "SPC w v" #'split-window-right
    "SPC w h" #'split-window-below

    ;; Zoxide.
    "SPC z f" #'zoxide-find-file
    "SPC z t" #'zoxide-travel
    "SPC z d" #'zoxide-cd))

(defun my/hel--activate ()
  "Load Hel, configure personal bindings, and enable it globally."
  (when (require 'hel nil t)
    (hel-set-initial-state 'dired-mode 'normal)
    (my/hel-setup-leader)
    (hel-mode 1)
    t))

(defun my/hel--install ()
  "Install Hel asynchronously through async-installer."
  (when (boundp 'async-installer-git-list)
    (let ((package
           (seq-find
            (lambda (entry)
              (string-match-p "anuvyklack/hel" (plist-get entry :repo)))
            async-installer-git-list)))
      (when (and package (not my/hel--installing))
        (setq my/hel--installing t)
        (async-installer-git--install-one
         package
         (lambda (dir)
           (setq my/hel--installing nil)
           (if dir
               (progn
                 (add-to-list 'load-path dir)
                 (my/hel--activate))
             (message "Hel installation failed"))))))))

(if (version< emacs-version my/hel-minimum-emacs-version)
    (message "Hel requires Emacs %s or newer; running without Hel"
             my/hel-minimum-emacs-version)
  (dolist (package '(dash avy pcre2el ultra-scroll))
    (require-package package))
  (let ((dir (expand-file-name "external-packages/hel" user-emacs-directory)))
    (when (file-directory-p dir)
      (add-to-list 'load-path dir)))
  (unless (or (my/hel--activate) noninteractive)
    (my/hel--install)))

(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "SPC :"   "M-x"
    "SPC ."   "Find file"
    "SPC ,"   "Switch buffer"
    "SPC ;"   "Insert timestamp"
    "SPC b"   "buffer"
    "SPC b n" "Next buffer"
    "SPC b p" "Prev buffer"
    "SPC b s" "Save buffer"
    "SPC b a" "Save all buffers"
    "SPC b k" "Kill current buffer"
    "SPC b o" "Read only mode"
    "SPC b m" "View message buffer"
    "SPC b e" "Eval buffer"
    "SPC b r" "Revert buffer"
    "SPC c"     "claude / comment / clock"
    "SPC c c"   "Claude Code IDE"
    "SPC c m"   "Claude Code menu"
    "SPC c /"   "Comment dwim"
    "SPC c t"   "Update time"
    "SPC c i"   "Start clock"
    "SPC c o"   "Stop clock"
    "SPC c p"   "punch"
    "SPC c p i" "Punch in clock"
    "SPC c p o" "Punch out clock"
    "SPC c g"   "Go to clock"
    "SPC c l"   "last task"
    "SPC c l t" "Clock in last task"
    "SPC c s"   "Switch task"
    "SPC e"   "eval / eshell / ediff"
    "SPC e e" "Eval last sexp"
    "SPC e s" "Start eshell"
    "SPC e c" "Eshell current directory"
    "SPC e d" "Ediff"
    "SPC e b" "Ediff buffers"
    "SPC e w" "Ediff current vs other window"
    "SPC d"   "edit / denote / dired"
    "SPC d d" "Kill whole line"
    "SPC d w" "Delete trailing whitespace"
    "SPC d D" "Duplicate line down"
    "SPC d n" "Create a denote"
    "SPC d r" "Rename denote file"
    "SPC d c" "Cd to current buffer dir"
    "SPC d i" "Dired"
    "SPC d p" "Show current directory"
    "SPC g"   "git / translate / ghostel"
    "SPC g s" "Magit status"
    "SPC g b" "Switch git status buffer"
    "SPC g i" "Magit"
    "SPC g d" "Git diff working tree"
    "SPC g t" "Translate"
    "SPC g p" "Git push"
    "SPC g l" "Git log"
    "SPC g f" "Git pull (ff-only)"
    "SPC g P" "Polish sentence"
    "SPC g h" "Ghostel terminal"
    "SPC h"   "highlight"
    "SPC h l" "Permanently highlight line"
    "SPC p"   "project"
    "SPC p p" "Project find file"
    "SPC j"   "denote journal"
    "SPC j n" "Create an entry"
    "SPC j t" "Entry with todos"
    "SPC j o" "Open current journal"
    "SPC n"   "blinko"
    "SPC n b" "Post buffer"
    "SPC n r" "Post region"
    "SPC n p" "Post content"
    "SPC o"     "org"
    "SPC o a"   "Agenda"
    "SPC o l"   "Todo list"
    "SPC o m"   "Tags search"
    "SPC o v"   "View search"
    "SPC o t"   "Todo change"
    "SPC o c"   "Capture"
    "SPC o d"   "Insert deadline"
    "SPC o s"   "Insert schedule"
    "SPC o r"   "Refile"
    "SPC o p"   "Change priority"
    "SPC o g"   "Lookup location"
    "SPC o o"   "Open at point"
    "SPC o i"   "insert"
    "SPC o i l" "Insert link"
    "SPC o i h" "Insert heading"
    "SPC o i s" "Insert subheading"
    "SPC o n"   "now"
    "SPC o n l" "Add link to org-now"
    "SPC o n t" "Toggle org-now side window"
    "SPC q"   "session"
    "SPC q q" "Quit Emacs"
    "SPC q r" "Restart Emacs"
    "SPC s"       "search / supertag"
    "SPC s g"     "rg"
    "SPC s g r"   "Search with rg"
    "SPC s g h"   "rg hidden"
    "SPC s g h n" "Search with rg everything"
    "SPC s c"     "consult"
    "SPC s c g"   "Consult ripgrep"
    "SPC s c f"   "Consult fd"
    "SPC s c h"   "Consult org heading"
    "SPC s c d"   "Consult dir"
    "SPC s s"     "Supertag search"
    "SPC s t"     "Add tag"
    "SPC s T"     "Remove tag"
    "SPC s v"     "Table view"
    "SPC s n"     "Node view"
    "SPC s k"     "Kanban view"
    "SPC s m"     "Schema view"
    "SPC s i"     "Supertag capture"
    "SPC s r"     "Add reference"
    "SPC s u"     "Full rescan"
    "SPC t"   "tab"
    "SPC t n" "New tab"
    "SPC t c" "Close tab"
    "SPC w"   "window"
    "SPC w w" "Other window"
    "SPC w o" "Only current window"
    "SPC w q" "Close current window"
    "SPC w v" "Split window right"
    "SPC w h" "Split window below"
    "SPC z"   "zoxide"
    "SPC z f" "Find file under zoxide path"
    "SPC z t" "Travel to zoxide path"
    "SPC z d" "Cd to zoxide path"))

(provide 'init-local-hel)
;;; init-local-hel.el ends here
