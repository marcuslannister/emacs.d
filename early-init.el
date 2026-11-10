;;; -*- lexical-binding: t -*-

;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=81506
;; (setq w32-ime-preedit t)
(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)
(set-default-toplevel-value 'lexical-binding nil)
(run-with-idle-timer 5 t #'garbage-collect)
(load (expand-file-name "nn.el" user-emacs-directory))
(load (setq custom-file (expand-file-name "custom.el" user-lisp-directory)) 'noerror)
(nn-initialize)

(use-package emacs
  :ensure nil
  :hook (window-setup . (lambda () (setq inhibit-redisplay nil inhibit-message nil)))
  :init
  (setq-default tab-width 2
                tab-always-indent 'complete
                fill-column 80
                truncate-lines t
                truncate-partial-width-windows nil)

  (setq native-comp-jit-compilation nil
        native-comp-deferred-compilation nil
        native-comp-async-on-battery-power nil
        process-connection-type nil
        process-adaptive-read-buffering t
        read-process-output-max (* 4 1024 1024)
        redisplay-skip-fontification-on-input t
        ;; emacs.d-nn: set the filter only when the functions it calls are
        ;; loaded.  It calls `regexp-opt' and `seq-filter'.  If one of them is
        ;; still an autoload, `load' runs the filter again, and the call
        ;; repeats until "Lisp nesting exceeds `max-lisp-eval-depth'".  The
        ;; Emacs 31.1 build that Nix makes (our Ubuntu CI) fails this way.
        load-path-filter-function (and (featurep 'regexp-opt)
                                       (featurep 'seq)
                                       #'load-path-filter-cache-directory-files)
        long-line-threshold 1000
        large-hscroll-threshold 1000
        bidi-inhibit-bpa t
        bidi-display-reordering nil
        default-process-coding-system
        (if _WIN32
            `(utf-8-dos . ,locale-coding-system)
          '(utf-8-unix . utf-8-unix))
        inhibit-message t
        inhibit-redisplay t
        menu-bar-mode -1
        tool-bar-mode -1
        scroll-bar-mode -1
        underline-line-scaling-flag t
        overline-line-scaling-flag t
        strike-through-line-scaling-flag t
        frame-title-format
        '(:eval (concat
                 (if (and buffer-file-name (buffer-modified-p)) "● " "")
                 (buffer-name))))

  (let ((default-file-name-handler-alist file-name-handler-alist)
        (default-load-file-rep-suffixes load-file-rep-suffixes))
    (setq file-name-handler-alist nil
          load-suffixes '(".elc" ".el")
          load-file-rep-suffixes '(""))
    (add-hook 'emacs-startup-hook
              (lambda ()
                (setq file-name-handler-alist default-file-name-handler-alist
                      load-file-rep-suffixes default-load-file-rep-suffixes))
              101))

  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil
          w32-pipe-read-delay 0
          w32-pipe-buffer-size read-process-output-max))

  (remove-hook 'find-file-hook #'vc-refresh-state)
  (remove-hook 'find-file-hook #'epa-file-find-file-hook)
  :custom
  ;; emacs.d-nn: removed the upstream author's name and mail address.  Set your
  ;; own `user-full-name' and `user-mail-address' in user-lisp/custom.el.
  (user-lisp-auto-scrape nil)
  (gc-cons-percentage (if noninteractive #x8000000 most-positive-fixnum))
  (gc-cons-threshold (if noninteractive #x8000000 most-positive-fixnum))
  (load-prefer-newer t)
  (idle-update-delay 1.0)
  (window-combination-resize t)
  (inhibit-startup-screen t)
  (inhibit-startup-echo-area-message user-login-name)
  (inhibit-compacting-font-caches t)
  (frame-resize-pixelwise t)
  (frame-inhibit-implied-resize t)
  (default-frame-alist
    '((menu-bar-lines . 0)
      (tool-bar-lines . 0)
      (horizontal-scroll-bars)
      (vertical-scroll-bars)
      (fullscreen . maximized)))
  (select-active-regions 'only)
  (fast-but-imprecise-scrolling t)
  (ring-bell-function #'ignore)
  (x-underline-at-descent-line t)
  (use-short-answers t)
  (use-dialog-box nil)
  (use-file-dialog nil)
  (cursor-type 'box)
  (visible-bell nil)
  (visible-cursor nil)
  (resize-mini-windows t)
  (delete-by-moving-to-trash t)
  (delete-pair-blink-delay 0)
  (delete-pair-push-mark t)
  (undo-limit (* 13 160000))
  (undo-strong-limit (* 13 240000))
  (undo-outer-limit (* 13 24000000))
  (word-wrap-by-category t)
  (sgml-validate-command nil)
  (browse-url-firefox-program nil)
  (browse-url-chrome-program nil)
  (browse-url-chromium-program nil)
  (browse-url-text-browser nil)
  (browse-url-browser-function 'eww-browse-url))

(use-package env
  :ensure nil
  :init
  (setenv "TERM" "xterm-256color")

  (when _WIN32
    (setenv "GIT_ASKPASS" "git-gui--askpass")

    (setq exec-suffixes '("" ".exe" ".bat"))

    (defvar my-executable-find-cache (make-hash-table :test #'equal))
    (define-advice executable-find
        (:around (orig-fun command &optional remote) my-advice)
      (if remote
          (funcall orig-fun command remote)
        (or (gethash command my-executable-find-cache)
            (puthash command (funcall orig-fun command) my-executable-find-cache))))

    (unless (getenv "HOME")
      (when-let* ((home (getenv "USERPROFILE")))
        (setenv "HOME" home)
        (setq abbreviated-home-dir nil)))

    (when-let* ((bash (executable-find "bash")))
      (setq shell-file-name bash)
      (setenv "SHELL" bash)
      (setenv "MSYSTEM" "UCRT64")
      (setenv "PATH" (concat (file-name-directory bash) ";" (getenv "PATH"))))))

(use-package package
  :ensure nil
  :custom
  (package-quickstart t)
  (package-quickstart-file (expand-file-name "package-quickstart.el" package-user-dir))
  (package-enable-at-startup t)
  (package-install-upgrade-built-in nil)
  ;; emacs.d-nn: the Base sets this to nil on every system.  Now only Windows
  ;; keeps nil.  Inside Git bash, Emacs finds an MSYS gpg that cannot use
  ;; Emacs's Windows-style gnupg home, and every install then fails with
  ;; bad-signature.  Other systems get the Emacs default, `allow-unsigned'.
  (package-check-signature (if _WIN32 nil 'allow-unsigned))
  ;; emacs.d-nn: replaced the Tsinghua mirrors with the official archives, and
  ;; added NonGNU ELPA.  The Tsinghua mirror answers HTTP 403 on one of our
  ;; Windows machines; the official archives answer on all our machines.
  (package-archives
   '(("gnu"    . "https://elpa.gnu.org/packages/")
     ("nongnu" . "https://elpa.nongnu.org/nongnu/")
     ("melpa"  . "https://melpa.org/packages/"))))

(use-package use-package
  :ensure nil
  :custom
  (use-package-always-ensure t)
  (use-package-always-defer t)
  (use-package-expand-minimally t))
