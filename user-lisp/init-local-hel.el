;;; init-local-hel.el --- Hel modal editing and its leader keys -*- lexical-binding: t -*-
;;; Commentary:
;; Hel is a Helix-style modal editing package, and hel-leader turns SPC into the
;; C-c prefix.  Both come from Git (init-local-package-list.el).  Hel starts at
;; startup when the clones exist, and otherwise right after the first install.
;;
;; The leader keys live in one table, `my/hel-leader-bindings'.  A module that
;; owns a command adds its own keys with `my/hel-leader-bind', so a key never
;; points at a command this config does not have.  test-startup.sh checks every
;; entry, in Normal and Emacs state.  The Base has no which-key, so the keys
;; carry no labels.
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
(defvar nn-mode-line-set)
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
  (hel-set-initial-state 'dired-mode 'normal)
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

(defun my/hel--activate-after-install ()
  "Activate Hel after a background install, and warn instead of signalling."
  (condition-case err
      (my/hel--activate)
    (error (display-warning 'init-local-hel
                            (format "Hel could not start: %s" (error-message-string err))))))

(defun my/hel--ensure-dependencies ()
  "Install the packages that Hel and hel-leader need, from the archives."
  ;; pcre2el puts a disabled `defadvice' on etags' `find-tag-regexp', so
  ;; loading etags later warned "got redefined".
  (setq ad-redefinition-action 'accept)
  (use-package dash)
  (use-package s)
  (use-package avy)
  (use-package pcre2el)
  (use-package ultra-scroll))

(defun my/hel-setup ()
  "Start Hel now when its packages exist, and otherwise after the install."
  (advice-add 'nn-mode-line-set :after #'my/hel--add-mode-line-segment)
  (my/hel--ensure-dependencies)
  (unless (my/hel--activate)
    (add-hook 'my/async-installer-after-install-hook #'my/hel--activate-after-install)))

(provide 'init-local-hel)
;;; init-local-hel.el ends here
