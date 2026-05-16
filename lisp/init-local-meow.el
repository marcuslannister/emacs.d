;;; Package --- meow settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'meow)

(defun my/save-all-buffers ()
  "Save every modified file-visiting buffer without prompting."
  (interactive)
  (save-some-buffers t))

(defun meow-setup ()
  "Configure meow leader, motion, and normal-state keybindings."
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
  (meow-motion-overwrite-define-key
   '("j" . meow-next)
   '("k" . meow-prev)
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
   '("e" . "C-x C-e")
   '("<SPC>" . "C-x C-s")
   '(":" . execute-extended-command)
   '("." . find-file)
   '("," . switch-to-buffer)
   '(";" . insert-timestamp)
   '("k" . kill-this-buffer)
   '("p" . project-find-file)
   '("f" . find-file)
   '("i" . imenu)
   '("F" . toggle-frame-maximized)
   '("r" . recentf-open)
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
   ;; comment / clock
   '("c c" . comment-dwim)
   '("c t" . org-clock-update-time-maybe)
   '("c i" . org-clock-in)
   '("c o" . org-clock-out)
   '("c p i" . bh/punch-in)
   '("c p o" . bh/punch-out)
   '("c g" . org-clock-goto)
   '("c l t" . bh/clock-in-last-task)
   '("c s" . kk/org-clock-in-switch-task)
   ;; delete
   '("d d" . kill-line)
   '("d w" . delete-trailing-whitespace)
   '("d D" . move-dup-duplicate-down)
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
   ;; window
   '("w o" . delete-other-windows)
   '("w q" . delete-window)
   '("w v" . split-window-right)
   '("w h" . split-window-below)
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
   '(";" . meow-reverse)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("a" . meow-append)
   '("A" . meow-open-below)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   '("d" . meow-delete)
   '("D" . meow-backward-delete)
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
   '("o" . meow-block)
   '("O" . meow-to-block)
   '("p" . meow-yank)
   '("P" . meow-yank-pop)
   '("q" . meow-quit)
   '("Q" . meow-goto-line)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("s" . meow-kill)
   '("t" . meow-till)
   '("T" . meow-till-expand)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("v" . meow-visit)
   '("V" . meow-kmacro-matches)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("x" . meow-line)
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
   '("<escape>" . ignore)))

(setq
 meow-esc-delay 0.001
 meow-select-on-change t
 meow-use-clipboard t
 meow-cursor-type-normal 'box
 meow-cursor-type-insert '(bar . 4)
 meow-keypad-describe-delay 0.5
 meow-keypad-leader-dispatch "C-c"
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
    "SPC c"     "comment / clock"
    "SPC c c"   "Comment dwim"
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
    "SPC d"   "delete"
    "SPC d d" "Kill line"
    "SPC d w" "Delete trailing whitespace"
    "SPC d D" "Duplicate line down"
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
    "SPC w"   "window"
    "SPC w o" "Only current window"
    "SPC w q" "Close current window"
    "SPC w v" "Split window right"
    "SPC w h" "Split window below"))


(provide 'init-local-meow)
;;; init-local-meow.el ends here
