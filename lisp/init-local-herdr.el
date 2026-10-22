;;; init-local-herdr.el --- Herdr agent multiplexer in Ghostel -*- lexical-binding: t -*-
;;; Commentary:
;; Herdr TUI and agent commands; see docs/research/emacs-herdr.md.
;; `herdr-mode' stays off: it polls `herdr api snapshot' every 2 seconds.
;;; Code:

(defun ml/herdr--column-pos (col)
  "Return the position of a │ within 2 columns of COL on this line, else nil.
Emacs and the terminal can disagree by a column on wide characters."
  (save-excursion
    (seq-some (lambda (c)
                (and (>= c 0)
                     (= (move-to-column c) c)
                     (eq (char-after) ?│)
                     (point)))
              (mapcar (lambda (d) (+ col d)) '(0 -1 1 -2 2)))))

(defun ml/herdr--tui-buffer-p ()
  "Non-nil in the *herdr* Ghostel buffer, which draws the sidebar and borders."
  (and (derived-mode-p 'ghostel-mode)
       (string-match-p "\\`\\*herdr\\*" (buffer-name))))

(defun ml/herdr--pane-segments (beg end anchor)
  "Return (FROM . TO) for each line of BEG..END, cut to the pane at ANCHOR.
Herdr draws its sidebar and pane splits with │.  Copy and the region
highlight both use these segments, so what is shown is what is copied."
  ;; shortcut: a │ in pane text left of ANCHOR (e.g. a table) is taken as the
  ;; border; read pane rows with `herdr pane read' if this bites.
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
      (while (let* ((l (and lcol (ml/herdr--column-pos lcol)))
                    (r (and rcol (ml/herdr--column-pos rcol)))
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

(defun ml/herdr--pane-text (beg end &optional anchor)
  "Return text BEG..END; in the *herdr* TUI, keep only the pane column.
Each line also loses the scrollbar (▕ or ▐) and trailing blanks.  The pane
is the one at ANCHOR, else at the region start, else at point."
  (if (not (ml/herdr--tui-buffer-p))
      (buffer-substring-no-properties beg end)
    (mapconcat
     (lambda (seg)
       (replace-regexp-in-string "\\`│\\|[ \t\u00a0]*[▕▐]?[ \t\u00a0│]*\\'" ""
                                 (buffer-substring-no-properties (car seg) (cdr seg))))
     (ml/herdr--pane-segments beg end (or anchor (if (use-region-p) beg (point))))
     "\n")))

(defun ml/herdr--text-at-point ()
  "Return the region's pane text, or the line's without a leading ❯ or ⏺.
Claude Code marks prompts with ❯ and replies with ⏺; a whole-line send of
\"❯ ! cmd\" must start with \"!\" to run as a bash command."
  (string-trim
   (if (use-region-p)
       (ml/herdr--pane-text (region-beginning) (region-end))
     (replace-regexp-in-string
      "\\`[ \t\u00a0]*[❯⏺][ \t\u00a0]*" ""
      (ml/herdr--pane-text (line-beginning-position) (line-end-position))))))

(defun ml/herdr--target-pane (snap)
  "Return the pane id to send to without asking, or nil to let the user pick.
SNAP is the `snapshot' object of `herdr api snapshot'.  A focused agent pane
is its own target.  From a focused terminal pane, the target is the only
agent in its tab; with none or several, return nil."
  (let ((here (seq-find (lambda (p) (eq (alist-get 'focused p) t))
                        (alist-get 'panes snap))))
    (cond ((null here) nil)
          ((alist-get 'agent here) (alist-get 'pane_id here))
          (t (let ((mates (seq-filter
                           (lambda (a) (equal (alist-get 'tab_id a) (alist-get 'tab_id here)))
                           (alist-get 'agents snap))))
               (and (= (length mates) 1) (alist-get 'pane_id (car mates))))))))

(defun ml/herdr-copy-pane-text ()
  "Copy the region, or the line at point, without the herdr sidebar."
  (interactive)
  (let ((text (ml/herdr--text-at-point)))
    (kill-new text)
    (deactivate-mark)
    (message "Copied: %s" (truncate-string-to-width text 60 nil nil "…"))))
(global-set-key (kbd "C-c W") #'ml/herdr-copy-pane-text)

(defun ml/herdr--filter-buffer-substring (orig beg end delete)
  "Return BEG..END as pane text; call ORIG with the same args to delete.
Every copy path (`kill-ring-save', copy mode RET and M-w, a mouse drag
with `mouse-drag-copy-region') reads text through this filter."
  (if delete
      (funcall orig beg end delete)
    (ml/herdr--pane-text beg end beg)))

(defun ml/herdr--highlight-region (start end window rol)
  "Highlight START..END in WINDOW line by line, cut to the pane at START.
Delete the old highlight ROL first.  Return (ml/herdr . OVERLAYS), tagged
like `rectangle-mark-mode' does, for `redisplay-highlight-region-function'."
  (funcall redisplay-unhighlight-region-function rol)
  (cons 'ml/herdr
        (mapcar (lambda (seg)
                  (let ((ov (make-overlay (car seg) (cdr seg))))
                    (overlay-put ov 'window window)
                    (overlay-put ov 'face 'region)
                    (overlay-put ov 'priority '(nil . 100))
                    ov))
                (ml/herdr--pane-segments start end start))))

(defun ml/herdr--unhighlight-region (orig rol)
  "Delete a tagged ROL from `ml/herdr--highlight-region', else call ORIG.
Global, because redisplay may drop the highlight from another buffer."
  (if (eq (car-safe rol) 'ml/herdr)
      (mapc #'delete-overlay (cdr rol))
    (funcall orig rol)))
(add-function :around (default-value 'redisplay-unhighlight-region-function)
              #'ml/herdr--unhighlight-region)

(defun ml/herdr--setup-tui-buffer ()
  "In *herdr*, cut copies and the region highlight to the pane.
Other Ghostel buffers keep Ghostel's own copy, which joins soft-wrapped lines."
  (when (ml/herdr--tui-buffer-p)
    (add-function :around (local 'filter-buffer-substring-function)
                  #'ml/herdr--filter-buffer-substring)
    (setq-local redisplay-highlight-region-function #'ml/herdr--highlight-region)))
;; `herdr--create-buffer' names the buffer before it calls `ghostel-mode'.
(add-hook 'ghostel-mode-hook #'ml/herdr--setup-tui-buffer)

(when (executable-find "herdr")
  (use-package herdr
    :ensure t
    :vc (:url "https://github.com/baongoc124/emacs-herdr" :rev :newest)
    ;; :bind, not `herdr-menu-key': that option binds only after herdr.el loads.
    :bind (("C-c m" . ml/herdr-send-raw)
           ("C-c M" . herdr-menu))
    :config
    (defun ml/herdr-send-raw (&optional submit)
      "Send the region, or the line at point, to an agent as typed text.
Unlike `herdr-send-region', add no code fence, so \"! cmd\" stays a Claude
Code bash command.  With prefix arg SUBMIT, also press Enter.
The agent is the focused pane when it is an agent, else the only agent in
the focused pane's tab; otherwise pick it.  Then focus that agent."
      (interactive "P")
      ;; shortcut: uses herdr.el private helpers; re-check after package upgrades.
      (let ((text (ml/herdr--text-at-point)))
        (when (string-empty-p text)
          (user-error "Nothing to send"))
        (let* ((json (herdr--snapshot-sync))
               (target (ml/herdr--target-pane
                        (alist-get 'snapshot (alist-get 'result json))))
               (agent (or (and target
                               (seq-find (lambda (a) (equal (alist-get 'pane-id a) target))
                                         (herdr--extract-agents json)))
                          (herdr--pick-agent "Send raw to agent: "))))
          (unless (zerop (call-process herdr-executable nil nil nil "pane"
                                       (if submit "run" "send-text")
                                       (alist-get 'pane-id agent) text))
            (user-error "herdr refused the text (agent gone?)"))
          (herdr--show-agent agent))))))

(provide 'init-local-herdr)
;;; init-local-herdr.el ends here
