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

(defun ml/herdr--pane-text (beg end)
  "Return text BEG..END; in the *herdr* TUI, keep only the pane column.
Herdr draws its sidebar and pane splits with │, and a scrollbar (▕ or ▐)
before the right edge.  The pane is the one at the region start, or at
point when no region is active."
  (if (not (ml/herdr--tui-buffer-p))
      (buffer-substring-no-properties beg end)
    ;; shortcut: a │ in pane text left of point (e.g. a table) is taken as the
    ;; border; read pane rows with `herdr pane read' if this bites.
    (let* ((anchor (if (use-region-p) beg (point)))
           (lcol (save-excursion
                   (goto-char anchor)
                   (and (search-backward "│" (line-beginning-position) t)
                        (current-column))))
           (rcol (save-excursion
                   (goto-char anchor)
                   (and (search-forward "│" (line-end-position) t)
                        (1- (current-column)))))
           lines)
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
                                         (t (line-end-position)))))
                      (s (if (< from to) (buffer-substring-no-properties from to) "")))
                 (push (replace-regexp-in-string "\\`│\\|[ \t ]*[▕▐]?[ \t │]*\\'" "" s)
                       lines)
                 (and (zerop (forward-line 1)) (< (point) end)))))
      (string-join (nreverse lines) "\n"))))

(defun ml/herdr--text-at-point ()
  "Return the region's pane text, or the line's without a leading ❯ or ⏺.
Claude Code marks prompts with ❯ and replies with ⏺; a whole-line send of
\"❯ ! cmd\" must start with \"!\" to run as a bash command."
  (string-trim
   (if (use-region-p)
       (ml/herdr--pane-text (region-beginning) (region-end))
     (replace-regexp-in-string
      "\\`[ \t ]*[❯⏺][ \t ]*" ""
      (ml/herdr--pane-text (line-beginning-position) (line-end-position))))))

(defun ml/herdr-copy-pane-text ()
  "Copy the region, or the line at point, without the herdr sidebar."
  (interactive)
  (let ((text (ml/herdr--text-at-point)))
    (kill-new text)
    (deactivate-mark)
    (message "Copied: %s" (truncate-string-to-width text 60 nil nil "…"))))
(global-set-key (kbd "C-c W") #'ml/herdr-copy-pane-text)

(defun ml/herdr--copy-pane-region (orig &rest args)
  "Run ORIG with ARGS, then replace the copied region with its pane text.
So copy mode (SPC to start, RET to copy) in *herdr* drops the sidebar.
Other buffers keep Ghostel's own copy, which joins soft-wrapped lines."
  (let ((text (and (use-region-p)
                   (ml/herdr--tui-buffer-p)
                   (ml/herdr--pane-text (region-beginning) (region-end)))))
    (apply orig args)
    (when text
      (kill-new text t))))
(with-eval-after-load 'ghostel
  (advice-add 'ghostel-readonly-copy :around #'ml/herdr--copy-pane-region))

(when (executable-find "herdr")
  (use-package herdr
    :ensure t
    :vc (:url "https://github.com/baongoc124/emacs-herdr" :rev :newest)
    ;; :bind, not `herdr-menu-key': that option binds only after herdr.el loads.
    :bind (("C-c m" . herdr-menu)
           ("C-c M" . ml/herdr-send-raw))
    :config
    (defun ml/herdr-send-raw (&optional submit)
      "Send the region, or the line at point, to an agent as typed text.
Unlike `herdr-send-region', add no code fence, so \"! cmd\" stays a Claude
Code bash command.  With prefix arg SUBMIT, also press Enter."
      (interactive "P")
      ;; shortcut: uses herdr.el private helpers; re-check after package upgrades.
      (let ((text (ml/herdr--text-at-point)))
        (when (string-empty-p text)
          (user-error "Nothing to send"))
        (let ((pane (alist-get 'pane-id (herdr--pick-agent "Send raw to agent: "))))
          (unless (zerop (call-process herdr-executable nil nil nil "pane"
                                       (if submit "run" "send-text") pane text))
            (user-error "herdr refused the text (agent gone?)"))
          (herdr))))))

(provide 'init-local-herdr)
;;; init-local-herdr.el ends here
