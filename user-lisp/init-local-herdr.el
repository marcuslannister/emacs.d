;;; init-local-herdr.el --- Herdr agent multiplexer in Ghostel -*- lexical-binding: t -*-
;;; Commentary:
;; Herdr runs coding agents in panes.  Its TUI runs in a Ghostel buffer, and
;; herdr.el (a Git pin, see init-local-package-list.el) sends text to agents.  This
;; module cuts copies and the region highlight to one pane, because the TUI draws a
;; sidebar and pane borders with │, and adds `my/herdr-send-raw'.
;;
;; macOS only.  When the herdr program is missing, the module warns and does nothing.
;; `herdr-mode' stays off: it polls `herdr api snapshot' every 2 seconds.
;; herdr.el requires Ghostel when it loads, so it loads on first use.
;;; Code:

(require 'seq)
(require 'subr-x)

(defvar herdr-executable)
(defvar redisplay-unhighlight-region-function)
(defvar redisplay-highlight-region-function)
(declare-function herdr--snapshot-sync "herdr")
(declare-function herdr--extract-agents "herdr")
(declare-function herdr--pick-agent "herdr")
(declare-function herdr--show-agent "herdr")
(declare-function my/hel-leader-bind "init-local-hel")

;;;; Text of one pane

(defun my/herdr--column-pos (col)
  "Return the position of a │ within 2 columns of COL on this line, or nil.
Emacs and the terminal can differ by a column on wide characters."
  (save-excursion
    (seq-some (lambda (c)
                (and (>= c 0)
                     (= (move-to-column c) c)
                     (eq (char-after) ?│)
                     (point)))
              (mapcar (lambda (d) (+ col d)) '(0 -1 1 -2 2)))))

(defun my/herdr--tui-buffer-p ()
  "Return non-nil in the *herdr* Ghostel buffer, which draws the sidebar and borders."
  (and (derived-mode-p 'ghostel-mode)
       (string-match-p "\\`\\*herdr\\*" (buffer-name))))

(defun my/herdr--pane-segments (beg end anchor)
  "Return a (FROM . TO) pair for each line of BEG..END, cut to the pane at ANCHOR.
Herdr draws its sidebar and its pane splits with │.  Copying and the region
highlight both use these segments, so what is shown is what is copied."
  ;; shortcut: a │ in pane text left of ANCHOR (a table, for example) counts as the
  ;; border; read the pane rows with `herdr pane read' if this bites.
  (let ((lcol (save-excursion
                (goto-char anchor)
                (and (search-backward "│" (line-beginning-position) t)
                     (current-column))))
        (rcol (save-excursion
                (goto-char anchor)
                (and (search-forward "│" (line-end-position) t)
                     (1- (current-column)))))
        segs)
    (save-excursion
      (goto-char beg)
      (while (let* ((l (and lcol (my/herdr--column-pos lcol)))
                    (r (and rcol (my/herdr--column-pos rcol)))
                    (from (max beg (cond (l (1+ l))
                                         (lcol (save-excursion
                                                 (move-to-column (1+ lcol))
                                                 (point)))
                                         (t (line-beginning-position)))))
                    (to (min end (cond (r)
                                       (rcol (save-excursion
                                               (move-to-column rcol)
                                               (point)))
                                       (t (line-end-position))))))
               (push (cons from (max from to)) segs)
               (and (zerop (forward-line 1)) (< (point) end)))))
    (nreverse segs)))

(defun my/herdr--pane-text (beg end &optional anchor)
  "Return the text of BEG..END; in the *herdr* TUI, keep only the pane column.
Each line also loses the scrollbar (▕ or ▐) and the trailing blanks.  The pane is
the one at ANCHOR, else at the region start, else at point."
  (if (not (my/herdr--tui-buffer-p))
      (buffer-substring-no-properties beg end)
    (mapconcat
     (lambda (seg)
       (replace-regexp-in-string "\\`│\\|[ \t\u00a0]*[▕▐]?[ \t\u00a0│]*\\'" ""
                                 (buffer-substring-no-properties (car seg) (cdr seg))))
     (my/herdr--pane-segments beg end (or anchor (if (use-region-p) beg (point))))
     "\n")))

(defun my/herdr--text-at-point ()
  "Return the pane text of the region, or of the line without a leading ❯ or ⏺.
Claude Code marks prompts with ❯ and replies with ⏺.  A line sent whole as
\"❯ ! cmd\" must start with \"!\" to run as a bash command."
  (string-trim
   (if (use-region-p)
       (my/herdr--pane-text (region-beginning) (region-end))
     (replace-regexp-in-string
      "\\`[ \t\u00a0]*[❯⏺][ \t\u00a0]*" ""
      (my/herdr--pane-text (line-beginning-position) (line-end-position))))))

(defun my/herdr-copy-pane-text ()
  "Copy the region, or the line at point, without the sidebar of Herdr."
  (interactive)
  (let ((text (my/herdr--text-at-point)))
    (kill-new text)
    (deactivate-mark)
    (message "Copied: %s" (truncate-string-to-width text 60 nil nil "…"))))

(defun my/herdr--copy-line-without-region (&rest _)
  "In the copy mode of *herdr*, copy the line when no region is active.
The copy of Ghostel (M-w, RET) copies only a region, so M-c M-w did nothing."
  (when (and (my/herdr--tui-buffer-p) (not (use-region-p)))
    (my/herdr-copy-pane-text)))

(defun my/herdr--filter-buffer-substring (orig beg end delete)
  "Return BEG..END as pane text; call ORIG with the same arguments to delete.
Every copy path (`kill-ring-save', RET and M-w in copy mode, a mouse drag with
`mouse-drag-copy-region') reads the text through this filter."
  (if delete
      (funcall orig beg end delete)
    (my/herdr--pane-text beg end beg)))

(defun my/herdr--highlight-region (start end window rol)
  "Highlight START..END in WINDOW line by line, cut to the pane at START.
Delete the old highlight ROL first.  Return (my/herdr . OVERLAYS), tagged like
`rectangle-mark-mode' does, for `redisplay-highlight-region-function'."
  (funcall redisplay-unhighlight-region-function rol)
  (cons 'my/herdr
        (mapcar (lambda (seg)
                  (let ((ov (make-overlay (car seg) (cdr seg))))
                    (overlay-put ov 'window window)
                    (overlay-put ov 'face 'region)
                    (overlay-put ov 'priority '(nil . 100))
                    ov))
                (my/herdr--pane-segments start end start))))

(defun my/herdr--unhighlight-region (orig rol)
  "Delete a ROL that `my/herdr--highlight-region' tagged, else call ORIG.
This is global, because redisplay may drop the highlight from another buffer."
  (if (eq (car-safe rol) 'my/herdr)
      (mapc #'delete-overlay (cdr rol))
    (funcall orig rol)))

(defun my/herdr--setup-tui-buffer ()
  "In *herdr*, cut the copies and the region highlight to the pane.
Other Ghostel buffers keep the copy of Ghostel, which joins soft-wrapped lines."
  (when (my/herdr--tui-buffer-p)
    (add-function :around (local 'filter-buffer-substring-function)
                  #'my/herdr--filter-buffer-substring)
    (setq-local redisplay-highlight-region-function #'my/herdr--highlight-region)))

;;;; Sending text to an agent

(defun my/herdr--target-pane (snap)
  "Return the pane id to send to without asking, or nil to let the user pick.
SNAP is the `snapshot' object of `herdr api snapshot'.  A focused agent pane is
its own target.  From a focused terminal pane, the target is the only agent in its
tab; with none or several, return nil."
  (let ((here (seq-find (lambda (p) (eq (alist-get 'focused p) t))
                        (alist-get 'panes snap))))
    (cond ((null here) nil)
          ((alist-get 'agent here) (alist-get 'pane_id here))
          (t (let ((mates (seq-filter
                           (lambda (a) (equal (alist-get 'tab_id a) (alist-get 'tab_id here)))
                           (alist-get 'agents snap))))
               (and (= (length mates) 1) (alist-get 'pane_id (car mates))))))))

(defun my/herdr-send-raw (&optional submit)
  "Send the region, or the line at point, to an agent as typed text.
Unlike `herdr-send-region', add no code fence, so \"! cmd\" stays a bash command of
Claude Code.  With a prefix argument SUBMIT, also press Enter.  The agent is the
focused pane when it is an agent, else the only agent in the tab of the focused
pane; otherwise ask.  Then focus that agent."
  (interactive "P")
  ;; shortcut: this uses private helpers of herdr.el; check them when the pin moves.
  (require 'herdr)
  (let ((text (my/herdr--text-at-point)))
    (when (string-empty-p text)
      (user-error "Nothing to send"))
    (let* ((json (herdr--snapshot-sync))
           (target (my/herdr--target-pane (alist-get 'snapshot (alist-get 'result json))))
           (agent (or (and target
                           (seq-find (lambda (a) (equal (alist-get 'pane-id a) target))
                                     (herdr--extract-agents json)))
                      (herdr--pick-agent "Send raw to agent: "))))
      (unless (zerop (call-process herdr-executable nil nil nil "pane"
                                   (if submit "run" "send-text")
                                   (alist-get 'pane-id agent) text))
        (user-error "Herdr refused the text (agent gone?)"))
      (herdr--show-agent agent))))

;;;; Setup

(defun my/herdr-setup ()
  "Set Herdr up on macOS when the herdr program exists.  Never signals."
  (cond
   ((not (eq system-type 'darwin)))
   ((not (executable-find "herdr"))
    (display-warning 'init-local-herdr "The herdr program is not on the PATH; Herdr is off"))
   (t
    ;; The pin has no autoload file, and herdr.el requires Ghostel at load.
    (autoload 'herdr "herdr" nil t)
    (autoload 'herdr-menu "herdr" nil t)
    (advice-add 'ghostel-readonly-copy :before #'my/herdr--copy-line-without-region)
    (add-function :around (default-value 'redisplay-unhighlight-region-function)
                  #'my/herdr--unhighlight-region)
    ;; `herdr--create-buffer' names the buffer before it calls `ghostel-mode'.
    (add-hook 'ghostel-mode-hook #'my/herdr--setup-tui-buffer)
    (global-set-key (kbd "C-c W") #'my/herdr-copy-pane-text)
    (global-set-key (kbd "C-c m") #'my/herdr-send-raw)
    (global-set-key (kbd "C-c M") #'herdr-menu)
    (my/hel-leader-bind "C-c h e" #'herdr))))

(provide 'init-local-herdr)
;;; init-local-herdr.el ends here
