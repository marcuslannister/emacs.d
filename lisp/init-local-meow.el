;;; Package --- meow settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'meow)

(defun my/save-all-buffers ()
  "Save every modified file-visiting buffer without prompting."
  (interactive)
  (save-some-buffers t))

(defun my/meow-yank-linewise (orig-fn &rest args)
  "Paste above current line when the most recent kill is a whole line.
A kill is treated as linewise when it ends with a newline (e.g. from
`d y' selecting a full line via `meow-line')."
  (if (and kill-ring
           (let ((top (current-kill 0 t)))
             (and top (string-suffix-p "\n" top))))
      (progn
        (beginning-of-line)
        (apply orig-fn args))
    (apply orig-fn args)))

(advice-add 'meow-yank :around #'my/meow-yank-linewise)

(defun meow-setup ()
  "Configure meow leader, motion, and normal-state keybindings."
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
  (meow-motion-overwrite-define-key
   '("j" . meow-next)
   '("k" . meow-prev)
   '("i" . meow-normal-mode)
   '("<escape>" . ignore))
  (meow-leader-define-key
   ;; Use SPC (0-9) for digit arguments.
   '("1" . meow-digit-argument)
   '("2" . meow-digit-argument)
   '("3" . meow-digit-argument)
   '("4" . meow-digit-argument)
   '("5" . meow-digit-argument)
   '("6" . meow-digit-argument)
   '("7" . meow-digit-argument)
   '("8" . meow-digit-argument)
   '("9" . meow-digit-argument)
   '("0" . meow-digit-argument)
   '("/" . meow-keypad-describe-key)
   '("?" . meow-cheatsheet)
   ;; high frequency
   '("<SPC>" . "C-x C-s")
   '(":" . execute-extended-command)
   '("." . find-file)
   '("," . switch-to-buffer)
   '(";" . insert-timestamp)
   '("k" . kill-this-buffer)
   '("f" . find-file)
   '("i" . imenu)
   '("F" . toggle-frame-maximized)
   '("r" . consult-recent-file)
   ;; buffer
   '("b n" . next-buffer)
   '("b p" . previous-buffer)
   '("b s" . basic-save-buffer)
   '("b a" . my/save-all-buffers)
   '("b k" . kill-current-buffer)
   '("b o" . read-only-mode)
   '("b m" . view-echo-area-messages)
   '("b e" . eval-buffer)
   '("b r" . revert-buffer)
   ;; claude / comment / clock
   '("c c" . claude-code-ide)
   '("c m" . claude-code-ide-menu)
   '("c /" . comment-dwim)
   '("c t" . org-clock-update-time-maybe)
   '("c i" . org-clock-in)
   '("c o" . org-clock-out)
   '("c p i" . bh/punch-in)
   '("c p o" . bh/punch-out)
   '("c g" . org-clock-goto)
   '("c l t" . bh/clock-in-last-task)
   '("c s" . kk/org-clock-in-switch-task)
   ;; e: eval / eshell / ediff
   '("e e" . "C-x C-e")
   '("e s" . eshell)
   '("e c" . eshell-current-directory)
   '("e d" . ediff)
   '("e b" . ediff-buffers)
   '("e w" . ml-init-ediff-current-with-other-window)
   ;; d: edit / denote / dired
   '("d d" . kill-whole-line)
   '("d w" . delete-trailing-whitespace)
   '("d D" . move-dup-duplicate-down)
   '("d n" . denote)
   '("d r" . denote-rename-file)
   '("d c" . ai/cd-to-current-buffer)
   '("d i" . dired)
   '("d p" . pwd)
   ;; git / gt-translate / ghostel
   '("g s" . magit-status)
   '("g b" . emacs-solo/switch-git-status-buffer)
   '("g i" . magit)
   '("g d" . magit-diff-working-tree)
   '("g t" . gt-translate)
   '("g p" . my/git-push)
   '("g l" . magit-log-current)
   '("g f" . my/git-pull-ff-only)
   '("g P" . ml-gt-polish-using-llm)
   '("g h" . ghostel)
   ;; highlight
   '("h l" . pulsar-highlight-permanently-dwim)
   ;; project
   '("p p" . project-find-file)
   ;; denote journal
   '("j n" . my/denote-journal-new-or-existing-entry)
   '("j t" . my/denote-journal-new-entry-with-open-todos)
   '("j o" . denote-journal-new-or-existing-entry)
   ;; blinko (note)
   '("n b" . blinko-post-buffer)
   '("n r" . blinko-post-region)
   '("n p" . blinko-post-content)
   ;; org
   '("o a" . org-agenda)
   '("o l" . org-todo-list)
   '("o m" . org-tags-view)
   '("o v" . org-search-view)
   '("o t" . org-todo)
   '("o c" . org-capture)
   '("o d" . org-deadline)
   '("o s" . org-schedule)
   '("o r" . org-refile)
   '("o p" . org-priority)
   '("o g" . org-goto)
   '("o o" . org-open-at-point)
   '("o i l" . org-insert-link)
   '("o i h" . org-insert-heading)
   '("o i s" . org-insert-subheading)
   '("o n l" . org-now-link)
   '("o n t" . org-now)
   ;; session
   '("q q" . save-buffers-kill-terminal)
   '("q r" . restart-emacs)
   ;; search
   '("s g r" . rgrep)
   '("s c g" . consult-ripgrep)
   '("s c f" . consult-fd)
   '("s c h" . consult-org-heading)
   '("s g h n" . rg-search-everything)
   '("s c d" . consult-dir)
   ;; tab
   '("t n" . tab-new)
   '("t c" . tab-close)
   ;; window
   '("w w" . other-window)
   '("w o" . sanityinc/delete-other-windows)
   '("w q" . sanityinc/delete-window)
   '("w v" . split-window-right)
   '("w h" . split-window-below)
   ;; zoxide
   '("z f" . zoxide-find-file)
   '("z t" . zoxide-travel)
   '("z d" . zoxide-cd)
   )
  (meow-normal-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . move-beginning-of-line)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("a" . meow-append)
   '("A" . meow-open-below)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   '("d" . meow-line)
   '("D" . kill-line)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("g" . meow-cancel-selection)
   '("G" . meow-grab)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("I" . meow-open-above)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   '("m" . meow-join)
   '("n" . meow-search)
   '("N" . meow-pop-search)
   '("o" . meow-open-below)
   '("O" . meow-block)
   '("p" . meow-yank)
   '("P" . meow-yank-pop)
   '("q" . meow-quit)
   '("Q" . meow-goto-line)
   '("r" . meow-replace)
   '("R" . meow-reverse)
   '("s" . meow-kill)
   '("t" . meow-till)
   '("T" . meow-till-expand)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("v" . meow-visit)
   '("V" . meow-kmacro-matches)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("x" . meow-delete)
   '("X" . meow-kmacro-lines)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("Z" . meow-pop-all-selection)
   '("&" . meow-query-replace)
   '("%" . meow-query-replace-regexp)
   '("'" . repeat)
   '("\\" . quoted-insert)
   '("<" . beginning-of-buffer)
   '(">" . end-of-buffer)
   '("$" . move-end-of-line)
   '("/" . meow-visit)
   '("<escape>" . ignore)))

(setq
 meow-esc-delay 0.001
 meow-select-on-change t
 meow-use-clipboard t
 meow-cursor-type-normal 'box
 meow-cursor-type-insert '(bar . 4)
 meow-keypad-describe-delay 0.5
 meow-keypad-leader-dispatch nil
 ;; Free c/h/x so SPC c, SPC h, SPC x reach our leader bindings instead of
 ;; being translated into C-c/C-h/C-x dispatches.
 meow-keypad-start-keys nil
 ;; Free `g' so SPC g ... reaches our git leader instead of becoming C-M-.
 meow-keypad-ctrl-meta-prefix nil
 meow-expand-hint-remove-delay 2.0)
(meow-setup)
(meow-setup-indicator)
(unless (bound-and-true-p meow-global-mode)
  (meow-global-mode 1))
(meow-esc-mode 1)

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
    "SPC s"       "search"
    "SPC s g"     "rg"
    "SPC s g r"   "Search with rg"
    "SPC s g h"   "rg hidden"
    "SPC s g h n" "Search with rg everything"
    "SPC s c"     "consult"
    "SPC s c g"   "Consult ripgrep"
    "SPC s c f"   "Consult fd"
    "SPC s c h"   "Consult org heading"
    "SPC s c d"   "Consult dir"
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


(provide 'init-local-meow)
;;; init-local-meow.el ends here
