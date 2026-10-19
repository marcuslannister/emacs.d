;;; init-git.el --- Git SCM support -*- lexical-binding: t -*-
;;; Commentary:

;; See also init-github.el.

;;; Code:

;; TODO: link commits from vc-log to magit-show-commit
;; TODO: smerge-mode
(require-package 'git-modes)
(when (maybe-require-package 'git-timemachine)
  (global-set-key (kbd "C-x v t") 'git-timemachine-toggle))

(require-package 'git-link)

(when (maybe-require-package 'magit)
  (setq-default magit-diff-refine-hunk 'all)
  (setq-default magit-diff-visit-prefer-worktree t)

  (sanityinc/fullframe-mode 'magit-status-mode)

  ;; Hint: customize `magit-repository-directories' so that you can use C-u M-F12 to
  ;; quickly open magit on any one of your projects.
  ;; `C-x g' is vc-dir-root now: see init-vc.el.
  (global-set-key [(meta f12)] 'magit-status)
  (global-set-key (kbd "C-x M-g") 'magit-dispatch)

  (defun sanityinc/magit-or-vc-log-file (&optional prompt)
    (interactive "P")
    (if (and (buffer-file-name)
             (eq 'Git (vc-backend (buffer-file-name))))
        (if prompt
            (magit-log-buffer-file-popup)
          (magit-log-buffer-file t))
      (vc-print-log)))

  (with-eval-after-load 'vc
    (define-key vc-prefix-map (kbd "l") 'sanityinc/magit-or-vc-log-file)))


(with-eval-after-load 'magit
  (define-key magit-status-mode-map (kbd "C-M-<up>") 'magit-section-up))

(maybe-require-package 'magit-todos)

;; Fast Magit status: config from the magit-fast README.
(use-package magit
  :init
  (magit-auto-revert-mode -1)
  (setq with-editor-emacsclient-executable (executable-find "emacsclient"))
  :custom
  (magit-log-section-commit-count 5)
  (magit-process-connection-type nil)
  (magit-refresh-verbose nil)
  (magit-refresh-status-buffer nil)
  (magit-revision-insert-related-refs nil)
  (magit-save-repository-buffers nil)
  (magit-uniquify-buffer-names nil)
  (magit-status-sections-hook
   '(magit-insert-error-header
     magit-insert-untracked-files
     magit-insert-unstaged-changes
     magit-insert-staged-changes
     magit-insert-recent-commits)))

;; The native-compile subprocess does not load Magit, so it compiles the
;; `magit-insert-section' macro in magit-fast as a function call and the
;; sections fail with "void-function unstaged".  Load Magit there first.
(setq native-comp-async-env-modifier-form '(require 'magit nil t))

(use-package magit-fast
  :ensure t
  :vc (:url "https://github.com/zHaOdANiuu/magit-fast" :rev :newest)
  :after magit
  :bind
  (:map magit-status-mode-map
   ("<return>" . my-magit-fast-diff))
  :init
  (remove-hook 'server-switch-hook 'magit-commit-diff)
  (remove-hook 'magit-pre-start-git-hook #'magit-maybe-save-repository-buffers)
  (magit-fast-mode)

  (defun my-magit-fast-diff ()
    (interactive)
    (when-let* ((file (magit-file-at-point)))
      (magit-diff-dwim nil `(,file)))))

(add-hook 'git-commit-mode-hook 'goto-address-mode)


;; Convenient binding for vc-git-grep
(with-eval-after-load 'vc
  (define-key vc-prefix-map (kbd "f") 'vc-git-grep))



;;; git-svn support

;; (when (maybe-require-package 'magit-svn)
;;   (require-package 'magit-svn)
;;   (autoload 'magit-svn-enabled "magit-svn")
;;   (defun sanityinc/maybe-enable-magit-svn-mode ()
;;     (when (magit-svn-enabled)
;;       (magit-svn-mode)))
;;   (add-hook 'magit-status-mode-hook #'sanityinc/maybe-enable-magit-svn-mode))

(with-eval-after-load 'compile
  (dolist (defn (list '(git-svn-updated "^\t[A-Z]\t\\(.*\\)$" 1 nil nil 0 1)
                      '(git-svn-needs-update "^\\(.*\\): needs update$" 1 nil nil 2 1)))
    (add-to-list 'compilation-error-regexp-alist-alist defn)
    (add-to-list 'compilation-error-regexp-alist (car defn))))

(defvar git-svn--available-commands nil "Cached list of git svn subcommands")
(defun git-svn--available-commands ()
  (or git-svn--available-commands
      (setq git-svn--available-commands
            (sanityinc/string-all-matches
             "^  \\([a-z\\-]+\\) +"
             (shell-command-to-string "git svn help") 1))))

(autoload 'vc-git-root "vc-git")

(defun git-svn (dir command)
  "Run a git svn subcommand in DIR."
  (interactive (list (read-directory-name "Directory: ")
                     (completing-read "git-svn command: " (git-svn--available-commands) nil t nil nil (git-svn--available-commands))))
  (let* ((default-directory (vc-git-root dir))
         (compilation-buffer-name-function (lambda (major-mode-name) "*git-svn*")))
    (compile (concat "git svn " command))))


(provide 'init-git)
;;; init-git.el ends here
