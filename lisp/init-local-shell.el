;;; Package --- shell settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'cl-lib)

(defun ml/eshell--script-for-os (base)
  "Return the eshell script path for BASE, preferring OS-specific files."
  (let* ((dir (expand-file-name "eshell" user-emacs-directory))
         (suffix (cond (IS-MAC "mac")
                       (IS-WINDOWS "windows")
                       (IS-LINUX "linux")))
         (os-file (and suffix (expand-file-name (format "%s-%s" base suffix) dir)))
         (fallback (expand-file-name base dir)))
    (cond
     ((and os-file (file-readable-p os-file)) os-file)
     ((file-readable-p fallback) fallback)
     (t nil))))

(let ((rc (ml/eshell--script-for-os "profile"))
      (login (ml/eshell--script-for-os "login")))
  (when rc
    (setq eshell-rc-script rc))
  (when login
    (setq eshell-login-script login)))

(when IS-MAC
  (use-package eat
    :ensure t
    :config
    (eat-compile-terminfo)       ;; optional but advised
    (setq eat-kill-buffer-on-exit t))

  ;; For `eat-eshell-visual-command-mode'.
  ;; (add-hook 'eshell-first-time-mode-hook
  ;;           #'eat-eshell-visual-command-mode)

  ;; For `eat-eshell-mode'.
  (add-hook 'eshell-first-time-mode-hook #'eat-eshell-mode))


;; Vim-style navigation + selection for ghostel copy mode (tmux copy-mode-vi
;; feel).  meow is disabled in copy mode (see `ml/ghostel-sync-meow') so these
;; keys are free.  A minor-mode map outranks ghostel's read-only/fast-exit local
;; map, so h/j/k/l move point instead of tripping fast-exit.  Reuses ghostel's
;; own commands: `ghostel-readonly-copy' both copies the region and exits
;; (fast-exit defaults on), and plain movement after SPC grows the region.
(declare-function ghostel-readonly-end-of-line "ghostel")
(declare-function ghostel-readonly-end-of-buffer "ghostel")
(declare-function ghostel-readonly-copy "ghostel")
(declare-function ghostel-readonly-exit "ghostel")

;; Built with `make-sparse-keymap'/`define-key' (not `defvar-keymap', Emacs
;; 29.1+) so this file still loads on the 27.1 floor declared in `init.el'.
(defvar ml/ghostel-copy-vi-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "h")        #'backward-char)
    (define-key map (kbd "j")        #'next-line)
    (define-key map (kbd "k")        #'previous-line)
    (define-key map (kbd "l")        #'forward-char)
    (define-key map (kbd "w")        #'forward-word)
    (define-key map (kbd "b")        #'backward-word)
    (define-key map (kbd "0")        #'beginning-of-line)
    (define-key map (kbd "$")        #'ghostel-readonly-end-of-line)
    (define-key map (kbd "g")        #'beginning-of-buffer)
    (define-key map (kbd "G")        #'ghostel-readonly-end-of-buffer)
    (define-key map (kbd "SPC")      #'set-mark-command)
    (define-key map (kbd "RET")      #'ghostel-readonly-copy)
    (define-key map (kbd "<return>") #'ghostel-readonly-copy)
    (define-key map (kbd "q")        #'ghostel-readonly-exit)
    (define-key map (kbd "C-g")      #'ghostel-readonly-exit)
    map)
  "Keymap for `ml/ghostel-copy-vi-mode'.")

(define-minor-mode ml/ghostel-copy-vi-mode
  "Tmux-style vi navigation and selection for ghostel copy mode.
Move with h/j/k/l (w/b words, 0/$ line, g/G buffer), press SPC to
start selecting, keep moving to extend, RET to copy and exit, q or
C-g to cancel."
  :keymap ml/ghostel-copy-vi-mode-map)

;; meow conflicts with ghostel's terminal-input modes; this helper is shared by
;; both the Windows (kiennq fork) and Mac/Linux (MELPA) ghostel setups below.
(defun ml/ghostel-sync-meow (&rest _)
  "Sync editing modes to ghostel's input mode.
In semi-char/char modes meow swallows ESC and the leader key, so the
terminal misses keys -- disable it.  In emacs mode the buffer is
read-only, so meow's space leader is what we want.  In copy mode use
`ml/ghostel-copy-vi-mode' (tmux-style hjkl select) instead of meow."
  (when (derived-mode-p 'ghostel-mode)
    (pcase ghostel--input-mode
      ('emacs (ml/ghostel-copy-vi-mode -1) (meow-mode 1))
      ('copy  (meow-mode -1) (ml/ghostel-copy-vi-mode 1))
      (_      (ml/ghostel-copy-vi-mode -1) (meow-mode -1)))))

(if IS-WINDOWS
    ;; Windows: use the kiennq fork (https://github.com/kiennq/ghostel) rather
    ;; than the MELPA package -- only the fork ships a working Windows native
    ;; runtime (dyn-loader-module + conpty-module).  Cloned + pinned via
    ;; async-installer:
    ;;   (async-installer-git-add "https://github.com/kiennq/ghostel.git"
    ;;     :tag "v0.31.0.79.a7b0c9" :subdir "lisp" :main "ghostel.el")
    ;;   M-x async-installer-git-install-all-interactive  ; clones to external-packages/
    (use-package ghostel
      :ensure nil
      :load-path "external-packages/ghostel/lisp"
      :hook (ghostel-mode . ml/ghostel-sync-meow)
      :bind (:map ghostel-semi-char-mode-map
                  ("M-v" . ghostel-copy-mode)
                  ("M-e" . ghostel-emacs-mode)
                  :map ghostel-mode-map
                  ("M-v" . ghostel-copy-mode)
                  ("M-e" . ghostel-emacs-mode))
      :init
      ;; ghostel--module-platform-tag returns nil on Windows, so the built-in
      ;; download path builds a nil URL and can't fetch the published binary.
      ;; Pin the module dir to a stable path outside the elpa tree and keep a
      ;; working DLL there.  After a version bump that raises the required
      ;; version, re-extract the matching ghostel-module-x86_64-windows.tar.xz
      ;; into ~/.emacs.d/ghostel-module/.
      (setq ghostel-module-directory
            (expand-file-name "ghostel-module/" user-emacs-directory))
      ;; Default ghostel-shell is $SHELL/cmdproxy (cmd.exe).  Prefer PowerShell
      ;; 7: it is a native Windows program, so it reports native C:\ paths (no
      ;; MSYS /c/... translation) -- which is what Claude Code and the native
      ;; git/rg it spawns expect.  No OSC-133 shell integration (pwsh is not
      ;; bash/zsh/fish), an acceptable trade for path correctness.
      (when (file-exists-p "C:/Program Files/PowerShell/7/pwsh.exe")
        (setq ghostel-shell
              '("C:/Program Files/PowerShell/7/pwsh.exe" "-NoLogo")))
      ;; Escape hatch: launch a Git Bash terminal on demand for unix-y
      ;; interactive work.  ghostel--detect-shell recognizes "bash", so shell
      ;; integration (OSC-133 prompt markers, directory tracking) applies.
      ;; Resolves bash.exe from $PATH -- make sure Git Bash's usr/bin (the real
      ;; bash.exe, NOT git-bash.exe, a mintty GUI launcher) is on $PATH.
      ;; -l login, -i interactive.
      (defun ml/ghostel-bash ()
        "Open a Ghostel terminal running Git Bash (bash.exe from `$PATH')."
        (interactive)
        (if-let* ((bash (executable-find "bash")))
            (let ((ghostel-shell (list bash "-l" "-i")))
              (ghostel))
          (user-error "bash not found on $PATH -- add Git Bash's usr/bin to $PATH")))
      :config
      (dolist (fn '(ghostel-semi-char-mode
                    ghostel-char-mode
                    ghostel-emacs-mode
                    ghostel-copy-mode
                    ghostel-readonly-exit))
        (advice-add fn :after #'ml/ghostel-sync-meow)))
  ;; Mac/Linux: MELPA ghostel (dakra).  Unchanged.
  (use-package ghostel
    :ensure t
    :hook (ghostel-mode . ml/ghostel-sync-meow)
    :bind (:map ghostel-semi-char-mode-map
                ("M-v" . ghostel-copy-mode)
                ("M-e" . ghostel-emacs-mode)
                :map ghostel-mode-map
                ("M-v" . ghostel-copy-mode)
                ("M-e" . ghostel-emacs-mode))
    :config
    (dolist (fn '(ghostel-semi-char-mode
                  ghostel-char-mode
                  ghostel-emacs-mode
                  ghostel-copy-mode
                  ghostel-readonly-exit))
      (advice-add fn :after #'ml/ghostel-sync-meow))
    (when-let* ((lib (locate-library "ghostel"))
                (script (expand-file-name "etc/shell/ghostel.zsh"
                                          (file-name-directory lib))))
      (when (file-readable-p script)
        (setenv "GHOSTEL_SH_INTEGRATION" script)))))

;; claude-code-ide spawns `claude' from Emacs, whose env never ran scm_breeze.
;; Claude Code's Bash tool then sources a shell snapshot that replays
;; scm_breeze's `git' wrapper (which execs "$_git_cmd") without the var, so
;; every git call dies with "permission denied" on an empty command.  Seed the
;; var here so the claude subprocess and its tool shells inherit a real path.
(setenv "_git_cmd" (or (executable-find "git") "/usr/bin/git"))

;; Claude Code's TUI hides the terminal cursor (CSI ?25l) and paints its own
;; dark block, which on a light theme reads as black.  In claude-code-ide
;; ghostel buffers, ignore that hide request so Emacs keeps drawing its own
;; (red) box cursor; and suppress the global blink while a ghostel window is
;; selected so the steady box covers Claude's block instead of flickering
;; red/black against it.  Blink is restored when focus leaves ghostel (the
;; user prefers it on elsewhere); Emacs has no per-buffer blink, hence the
;; focus-driven toggle.  Run on both selection changes AND buffer changes:
;; `window-selection-change-functions' misses a buffer being replaced in the
;; already-selected window (same-window `switch-to-buffer'/`display-buffer'),
;; which `window-buffer-change-functions' catches.
(defun ml/ghostel-claude-cursor-sync (&rest _)
  "Steady box cursor in claude ghostel buffers; sync cursor blink to focus."
  (with-current-buffer (window-buffer (selected-window))
    (when (and (derived-mode-p 'ghostel-mode)
               (string-prefix-p "*claude-code" (buffer-name)))
      (setq-local ghostel-ignore-cursor-change t)
      (setq cursor-type 'box))
    (if (derived-mode-p 'ghostel-mode)
        (when blink-cursor-mode (blink-cursor-mode -1))
      (unless blink-cursor-mode (blink-cursor-mode 1)))))
(add-hook 'window-selection-change-functions #'ml/ghostel-claude-cursor-sync)
(add-hook 'window-buffer-change-functions #'ml/ghostel-claude-cursor-sync)

(use-package eshell
  :ensure nil
  :defer t
  :hook ((eshell-directory-change . gopar/sync-dir-in-buffer-name)
         (eshell-mode . gopar/eshell-specific-outline-regexp)
         (eshell-mode . gopar/eshell-setup-keybinding)
         (eshell-first-time-mode . gopar/eshell-ensure-pager)
         (eshell-mode . (lambda ()
                          (setq-local completion-styles '(basic)) ; maybe emacs21?
                          (setq-local corfu-count 10)
                          (setq-local corfu-auto nil)
                          (setq-local corfu-preview-current nil)
                          (setq-local completion-at-point-functions '(pcomplete-completions-at-point cape-file)))))
  :custom
  (eshell-scroll-to-bottom-on-input t)
  (eshell-highlight-prompt t)
  (eshell-history-size 1024)
  (eshell-hist-ignoredups t)
  (eshell-input-filter 'gopar/eshell-input-filter)
  (eshell-cd-on-directory t)
  (eshell-list-files-after-cd nil)
  (eshell-pushd-dunique t)
  (eshell-last-dir-unique t)
  (eshell-last-dir-ring-size 32)
  :config
  (advice-add #'eshell-add-input-to-history
              :around
              #'gopar/adviced-eshell-add-input-to-history)

  :init
  (defun gopar/eshell-ensure-pager ()
    (let ((pager (getenv "PAGER")))
      (when (or (null pager) (string= "" pager))
        ;; Eshell uses a dumb terminal; avoid less' "terminal is not fully functional".
        (setenv "PAGER" "cat"))))

  (defun gopar/eshell-setup-keybinding ()
    ;; Workaround since bind doesn't work w/ eshell??
    (define-key eshell-mode-map (kbd "C-c >") 'gopar/eshell-redirect-to-buffer)
    (define-key eshell-hist-mode-map (kbd "M-r") 'consult-history)
    ;; Align with zsh habit: M-l accepts current completion (company popup).
    (when (fboundp 'company-complete-selection)
      (define-key eshell-mode-map (kbd "M-l") 'company-complete-selection)))

  (defun gopar/adviced-eshell-add-input-to-history (orig-fun &rest r)
    "Cd to relative paths aren't that useful in history. Change to absolute paths."
    (require 'seq)
    (let* ((input (nth 0 r))
           (args (progn
                   (set-text-properties 0 (length input) nil input)
                   (split-string input))))
      (if (and (equal "cd" (nth 0 args))
               (not (seq-find (lambda (item)
                                ;; Don't rewrite "cd /ssh:" in history.
                                (string-prefix-p "/ssh:" item))
                              args))
               (not (seq-find (lambda (item)
                                ;; Don't rewrite "cd -" in history.
                                (string-equal "-" item))
                              args)))
          (apply orig-fun (list (format "cd %s"
                                        (expand-file-name (concat default-directory
                                                                  (nth 1 args))))))
        (apply orig-fun r))))

  (defun gopar/eshell-input-filter (input)
    "Do not save on the following:
       - empty lines
       - commands that start with a space, `ls`/`l`/`lsd`"
    (and
     (eshell-input-filter-default input)
     (eshell-input-filter-initial-space input)
     (not (string-prefix-p "ls " input))
     (not (string-prefix-p "lsd " input))
     (not (string-prefix-p "l " input))))

  (defun eshell/cat-with-syntax-highlighting (filename)
    "Like cat(1) but with syntax highlighting.
Stole from aweshell"
    (let ((existing-buffer (get-file-buffer filename))
          (buffer (find-file-noselect filename)))
      (eshell-print
       (with-current-buffer buffer
         (if (fboundp 'font-lock-ensure)
             (font-lock-ensure)
           (with-no-warnings
             (font-lock-fontify-buffer)))
         (let ((contents (buffer-string)))
           (remove-text-properties 0 (length contents) '(read-only nil) contents)
           contents)))
      (unless existing-buffer
        (kill-buffer buffer))
      nil))
  (advice-add 'eshell/cat :override #'eshell/cat-with-syntax-highlighting)

  (defun gopar/sync-dir-in-buffer-name ()
    "Update eshell buffer to show directory path.
Stolen from aweshell."
    (let* ((root (projectile-project-root))
           (root-name (projectile-project-name root)))
      (if root-name
          (rename-buffer (format "*eshell %s* %s" root-name (s-chop-prefix root default-directory)) t)
        (rename-buffer (format "*eshell %s*" default-directory) t))))

  (defun gopar/eshell-redirect-to-buffer (buffer)
    "Auto create command for redirecting to buffer."
    (interactive (list (read-buffer "Redirect to buffer: ")))
    (insert (format " >>> #<%s>" buffer)))

  (defun gopar/eshell-specific-outline-regexp ()
    (setq-local outline-regexp eshell-prompt-regexp)))

(use-package eshell-syntax-highlighting
  :ensure t
  :after eshell
  :hook (eshell-first-time-mode . eshell-syntax-highlighting-global-mode)
  :init
  (defface eshell-syntax-highlighting-invalid-face
    '((t :inherit diff-error))
    "Face used for invalid Eshell commands."
    :group 'eshell-syntax-highlighting))

(require 'eshell)
(require 'em-dirs)

(defun eshell/pure-git-branch ()
  "Returns the current git branch."
  (let ((branch (car (cl-loop for match in (split-string (shell-command-to-string "git branch") "\n")
                              when (string-match "^\*" match)
                              collect match))))
    (if (not (eq branch nil))
        (concat " " (substring branch 2))
      "")))

(defun eshell/pure-git-dirty ()
  "Returns * if the git status is dirty."
  (let ((status (shell-command-to-string "git status --porcelain")))
    (if (string-match-p "." status)
        " *"
      "")))

(use-package eshell-git-prompt
  :after eshell
  :ensure t)

;; (use-package eshell-prompt-extras
;;   :ensure t
;;   :after esh-opt
;;   :config
;;   (setq eshell-highlight-prompt nil
;;         eshell-prompt-function 'epe-theme-dakrone))

(use-package eshell-z
  :after eshell
  :ensure t)

(add-hook 'eshell-mode-hook
          (defun my-eshell-mode-hook ()
            (require 'eshell-z)))

(defun eshell-current-directory (&optional directory)
  "Open eshell current `default-directory' or DIRECTORY."
  (interactive)
  (let ((current-dir (or directory default-directory))
        (eshell-buffer (or (get-buffer "*eshell*")
                           (eshell))))
    (switch-to-buffer eshell-buffer)
    (eshell/cd current-dir)
    (eshell-next-prompt)
    ;; Regenerate prompt to show current directory.
    ;; Avoid sending any half written input commands
    (if (eobp)
        (eshell-send-input nil nil nil)
      (move-end-of-line nil)
      (eshell-kill-input)
      (eshell-send-input nil nil nil)
      (yank))))

(use-package esh-autosuggest
  :hook (eshell-mode . esh-autosuggest-mode)
  ;; If you have use-package-hook-name-suffix set to nil, uncomment and use the
  ;; line below instead:
  ;; :hook (eshell-mode-hook . esh-autosuggest-mode)
  :ensure t)

(defun eshell/gs ()
  (magit-status default-directory))

(defun eshell/update-claude-plugins ()
  "Refresh marketplaces and update every installed Claude Code plugin.
Cross-platform: runs anywhere eshell runs.  Afterward run
`/reload-plugins' or restart Claude Code to apply the updates."
  (let ((claude (executable-find "claude")))
    (unless claude
      (error "Cannot find `claude' on PATH"))
    ;; claude.cmd -> Node spawns git; Node's post-CVE-2024-27980 check rejects
    ;; git if it isn't clearly on PATH.  Make the git dir explicit for the child.
    (let* ((git (executable-find "git"))
           (git-dir (and git (file-name-directory git)))
           (process-environment
            (if git-dir
                (cons (concat "PATH=" (convert-standard-filename git-dir)
                              path-separator (getenv "PATH"))
                      process-environment)
              process-environment)))
      (cl-flet ((run (&rest args)
                  ;; Run from HOME so any cwd-based safety checks don't trip.
                  (let ((default-directory (expand-file-name "~/")))
                    (with-temp-buffer
                      ;; call-process destination t captures stdout+stderr.
                      (let ((status (apply #'call-process claude nil t nil args)))
                        (unless (eq status 0)
                          (error "claude %s failed (exit %s):\n%s"
                                 (string-join args " ") status
                                 (string-trim (buffer-string))))
                        (buffer-string))))))
      (eshell-print "Refreshing marketplaces...\n")
      (eshell-print (run "plugin" "marketplace" "update"))
      (dolist (id (mapcar (lambda (p) (alist-get 'id p))
                          (json-parse-string
                           (run "plugin" "list" "--json")
                           :array-type 'list :object-type 'alist)))
        (eshell-print (format "\nUpdating %s...\n" id))
        (eshell-print (run "plugin" "update" id)))
      (eshell-print "\nDone. Run /reload-plugins (or restart) to apply.\n"))))
  nil)

(provide 'init-local-shell)
;;; init-local-shell.el ends here
