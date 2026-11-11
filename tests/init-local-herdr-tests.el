;;; init-local-herdr-tests.el --- Herdr module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-herdr-tests.el -f ert-run-tests-batch-and-exit
;; Herdr and Ghostel are not loaded: the tests use a stand-in mode and stub the helpers.
;;; Code:

(require 'cl-lib)
(require 'ert)

(defvar init-local-herdr-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")

(define-derived-mode ghostel-mode fundamental-mode "Ghostel"
  "Stand-in for the mode of Ghostel.")

(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-herdr-tests--keys)))

(load (expand-file-name "../user-lisp/init-local-herdr.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(defmacro init-local-herdr-tests--with-tui (text &rest body)
  "Run BODY in a *herdr* Ghostel buffer that holds TEXT, point at the start."
  (declare (indent 1))
  `(let ((buf (generate-new-buffer "*herdr*")))
     (unwind-protect
         (with-current-buffer buf
           (ghostel-mode)
           (insert ,text)
           (goto-char (point-min))
           ,@body)
       (kill-buffer buf))))

;; Sidebar | pane | scrollbar.  The border is │ at columns 7 and 19.
(defconst init-local-herdr-tests--screen
  "agents │ hello pane      ▕│\nclaude │ second line     ▕│\n")

;;;; Buffers

(ert-deftest init-local-herdr-tui-buffer-is-the-herdr-ghostel-buffer ()
  (init-local-herdr-tests--with-tui ""
    (should (my/herdr--tui-buffer-p)))
  (with-temp-buffer
    (ghostel-mode)
    (should-not (my/herdr--tui-buffer-p)))
  (let ((buf (generate-new-buffer "*herdr*")))
    (unwind-protect
        (with-current-buffer buf (should-not (my/herdr--tui-buffer-p)))
      (kill-buffer buf))))

;;;; Pane text

(ert-deftest init-local-herdr-pane-text-is-plain-outside-the-tui ()
  (with-temp-buffer
    (insert "a │ b │ c")
    (should (equal "a │ b │ c" (my/herdr--pane-text (point-min) (point-max))))))

(ert-deftest init-local-herdr-pane-text-keeps-only-the-pane-column ()
  (init-local-herdr-tests--with-tui init-local-herdr-tests--screen
    (goto-char (+ (point-min) 12))
    ;; The space after the border stays; the sidebar and the scrollbar go.
    (should (equal " hello pane\n second line"
                   (my/herdr--pane-text (point-min) (point-max) (point))))))

(ert-deftest init-local-herdr-segments-are-cut-to-the-border ()
  (init-local-herdr-tests--with-tui init-local-herdr-tests--screen
    (let ((segs (my/herdr--pane-segments (point-min) (point-max) (+ (point-min) 12))))
      (should (= 2 (length segs)))
      (dolist (seg segs)
        (should (<= (car seg) (cdr seg)))
        (should-not (string-match-p "agents\\|claude"
                                    (buffer-substring (car seg) (cdr seg))))))))

(ert-deftest init-local-herdr-text-at-point-drops-the-prompt-mark ()
  (with-temp-buffer
    (insert "❯ ! ls -la\n")
    (goto-char (point-min))
    (should (equal "! ls -la" (my/herdr--text-at-point))))
  (with-temp-buffer
    (insert "⏺ done\n")
    (goto-char (point-min))
    (should (equal "done" (my/herdr--text-at-point)))))

(ert-deftest init-local-herdr-text-at-point-uses-the-region ()
  (with-temp-buffer
    (insert "one two three")
    (set-mark 5)
    (goto-char 8)
    (activate-mark)
    (let ((transient-mark-mode t))
      (should (equal "two" (my/herdr--text-at-point))))))

(ert-deftest init-local-herdr-copy-puts-the-text-in-the-kill-ring ()
  (let ((kill-ring nil))
    (with-temp-buffer
      (insert "❯ hello\n")
      (goto-char (point-min))
      (cl-letf (((symbol-function 'message) #'ignore))
        (my/herdr-copy-pane-text)))
    (should (equal '("hello") kill-ring))))

(ert-deftest init-local-herdr-copy-mode-copies-the-line-without-a-region ()
  (let (copied)
    (cl-letf (((symbol-function 'my/herdr-copy-pane-text) (lambda () (setq copied t))))
      (with-temp-buffer
        (my/herdr--copy-line-without-region)
        (should-not copied))
      (init-local-herdr-tests--with-tui "x"
        (my/herdr--copy-line-without-region)
        (should copied)))))

(ert-deftest init-local-herdr-filter-cuts-a-copy-and-leaves-a-delete ()
  (init-local-herdr-tests--with-tui init-local-herdr-tests--screen
    (let ((beg (point-min)) (end (+ (point-min) 14)))
      (should (equal (my/herdr--pane-text beg end beg)
                     (my/herdr--filter-buffer-substring #'ignore beg end nil)))
      (should (eq 'orig (my/herdr--filter-buffer-substring
                         (lambda (&rest _) 'orig) beg end t))))))

(ert-deftest init-local-herdr-highlight-tags-its-overlays-and-unhighlight-removes-them ()
  (init-local-herdr-tests--with-tui init-local-herdr-tests--screen
    (let ((redisplay-unhighlight-region-function #'ignore)
          rol)
      (setq rol (my/herdr--highlight-region (point-min) (point-max) (selected-window) nil))
      (should (eq 'my/herdr (car rol)))
      (should (= 2 (length (cdr rol))))
      (should (cl-every #'overlay-buffer (cdr rol)))
      (my/herdr--unhighlight-region (lambda (_) (error "Not for a tagged value")) rol)
      (should-not (cl-some #'overlay-buffer (cdr rol)))
      (let (called)
        (my/herdr--unhighlight-region (lambda (r) (setq called r)) 'other)
        (should (eq 'other called))))))

(ert-deftest init-local-herdr-setup-of-the-tui-buffer-is-local-to-it ()
  (init-local-herdr-tests--with-tui ""
    (my/herdr--setup-tui-buffer)
    (should (eq #'my/herdr--highlight-region redisplay-highlight-region-function)))
  (with-temp-buffer
    (ghostel-mode)
    (my/herdr--setup-tui-buffer)
    (should-not (eq #'my/herdr--highlight-region redisplay-highlight-region-function))))

;;;; Target agent

(defconst init-local-herdr-tests--snap
  '((panes . (((pane_id . "p1") (focused . t) (tab_id . "t1"))
              ((pane_id . "p2") (focused . nil) (tab_id . "t1"))))
    (agents . (((pane_id . "p2") (tab_id . "t1"))))))

(ert-deftest init-local-herdr-target-is-the-only-agent-of-the-tab ()
  (should (equal "p2" (my/herdr--target-pane init-local-herdr-tests--snap))))

(ert-deftest init-local-herdr-target-is-a-focused-agent-pane ()
  (should (equal "p1" (my/herdr--target-pane
                       '((panes . (((pane_id . "p1") (focused . t) (agent . t))))
                         (agents . (((pane_id . "p9") (tab_id . "t9")))))))))

(ert-deftest init-local-herdr-target-is-nil-without-or-with-many-agents ()
  (should-not (my/herdr--target-pane '((panes . (((pane_id . "p1") (focused . t) (tab_id . "t1"))))
                                       (agents . nil))))
  (should-not (my/herdr--target-pane
               '((panes . (((pane_id . "p1") (focused . t) (tab_id . "t1"))))
                 (agents . (((pane_id . "a") (tab_id . "t1")) ((pane_id . "b") (tab_id . "t1")))))))
  (should-not (my/herdr--target-pane '((panes . (((pane_id . "p1") (focused . nil))))))))

;;;; Sending

(ert-deftest init-local-herdr-send-raw-refuses-empty-text ()
  (cl-letf (((symbol-function 'require) (lambda (&rest _) t)))
    (with-temp-buffer
      (should-error (my/herdr-send-raw) :type 'user-error))))

(ert-deftest init-local-herdr-send-raw-types-the-text-and-shows-the-agent ()
  (let (call shown)
    (cl-letf (((symbol-function 'require) (lambda (&rest _) t))
              ((symbol-function 'herdr--snapshot-sync) (lambda () `((result . ((snapshot . ,init-local-herdr-tests--snap))))))
              ((symbol-function 'herdr--extract-agents) (lambda (_) '(((pane-id . "p2")))))
              ((symbol-function 'herdr--show-agent) (lambda (a) (setq shown a)))
              ((symbol-function 'call-process)
               (lambda (&rest args) (setq call args) 0)))
      (defvar herdr-executable)
      (let ((herdr-executable "herdr-test"))
        (with-temp-buffer
          (insert "❯ ! ls\n")
          (goto-char (point-min))
          (my/herdr-send-raw)
          ;; Enter is pressed only with a prefix argument.
          (my/herdr-send-raw t))))
    (should (equal '((pane-id . "p2")) shown))
    (should (equal '("herdr-test" nil nil nil "pane" "run" "p2" "! ls") call))))

(ert-deftest init-local-herdr-send-raw-reports-a-refused-text ()
  (cl-letf (((symbol-function 'require) (lambda (&rest _) t))
            ((symbol-function 'herdr--snapshot-sync) (lambda () `((result . ((snapshot . ,init-local-herdr-tests--snap))))))
            ((symbol-function 'herdr--extract-agents) (lambda (_) '(((pane-id . "p2")))))
            ((symbol-function 'herdr--show-agent) #'ignore)
            ((symbol-function 'call-process) (lambda (&rest _) 1)))
    (defvar herdr-executable)
    (let ((herdr-executable "herdr-test"))
      (with-temp-buffer
        (insert "hi")
        (should-error (my/herdr-send-raw) :type 'user-error)))))

;;;; Setup

(ert-deftest init-local-herdr-setup-does-nothing-outside-macos ()
  (let ((system-type 'windows-nt) warned)
    (cl-letf (((symbol-function 'display-warning) (lambda (&rest _) (setq warned t))))
      (my/herdr-setup))
    (should-not warned)
    (should-not init-local-herdr-tests--keys)))

(ert-deftest init-local-herdr-setup-warns-when-the-program-is-missing ()
  (let ((system-type 'darwin) warnings)
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
              ((symbol-function 'display-warning)
               (lambda (type msg &rest _) (push (cons type msg) warnings))))
      (my/herdr-setup))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-herdr (car (car warnings))))
    (should-not init-local-herdr-tests--keys)))

(ert-deftest init-local-herdr-setup-registers-autoloads-and-the-leader-key ()
  (let ((system-type 'darwin)
        (init-local-herdr-tests--keys nil)
        (saved-map (copy-keymap global-map))
        (saved-hook ghostel-mode-hook)
        (saved-fn (default-value 'redisplay-unhighlight-region-function)))
    (unwind-protect
        (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "/x/herdr")))
          (my/herdr-setup)
          (should (autoloadp (symbol-function 'herdr)))
          (should (autoloadp (symbol-function 'herdr-menu)))
          (should (eq 'my/herdr-send-raw (keymap-lookup global-map "C-c m")))
          (should (eq 'herdr-menu (keymap-lookup global-map "C-c M")))
          (should (eq 'my/herdr-copy-pane-text (keymap-lookup global-map "C-c W")))
          (should (equal '(("C-c h e" . herdr)) init-local-herdr-tests--keys))
          (should (memq #'my/herdr--setup-tui-buffer ghostel-mode-hook))
          (should (advice-member-p #'my/herdr--copy-line-without-region 'ghostel-readonly-copy)))
      (advice-remove 'ghostel-readonly-copy #'my/herdr--copy-line-without-region)
      (remove-function (default-value 'redisplay-unhighlight-region-function)
                       #'my/herdr--unhighlight-region)
      (setq-default redisplay-unhighlight-region-function saved-fn)
      (setq ghostel-mode-hook saved-hook)
      (use-global-map saved-map))))

(provide 'init-local-herdr-tests)
;;; init-local-herdr-tests.el ends here
