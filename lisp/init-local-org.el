;; init-local-org.el --- org specific settings  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(setq org-directory "~/org/"
      org-default-notes-file (expand-file-name "inbox.org" org-directory))

(setq org-agenda-files
      (seq-filter (lambda(x) (not (string-match "/.stversions/"(file-name-directory x))))
                  (directory-files-recursively "~/org/" "\\.org$")
                  ))

(setq org-agenda-clockreport-parameter-plist
      (quote (:maxlevel 5 :fileskip0 t :compact t :narrow 80 :formula % )))

(with-eval-after-load 'org
  (setq org-hide-emphasis-markers t
        org-hide-leading-stars t
        org-startup-indented t
        org-adapt-indentation nil
        org-edit-src-content-indentation 0
        org-startup-truncated nil
        org-fontify-done-headline t
        org-fontify-todo-headline t
        org-fontify-whole-heading-line t
        org-fontify-quote-and-verse-blocks t
        org-pretty-entities t
        ;; Require braces for scripts so plain identifiers like Test_1
        ;; do not render as subscripts in headings.
        org-use-sub-superscripts '{}))



;;; config from https://doc.norang.ca/org-mode.html

(setq org-use-fast-todo-selection t)
(setq ido-max-directory-size 100000)

;; 9 Time Clocking
(defun bh/punch-in (arg)
  "Start continuous clocking and set the default task to the selected task.  If no task is selected set the Organization task as the default task."
  (interactive "p")
  (setq bh/keep-clock-running t)
  (if (equal major-mode 'org-agenda-mode)
      ;;
      ;; We're in the agenda
      ;;
      (let* ((marker (org-get-at-bol 'org-hd-marker))
             (tags (org-with-point-at marker (org-get-tags-at))))
        (if (and (eq arg 4) tags)
            (org-agenda-clock-in '(16))
          (bh/clock-in-organization-task-as-default)))
    ;;
    ;; We are not in the agenda
    ;;
    (save-restriction
      (widen)
                                        ; Find the tags on the current task
      (if (and (equal major-mode 'org-mode) (not (org-before-first-heading-p)) (eq arg 4))
          (org-clock-in '(16))
        (bh/clock-in-organization-task-as-default)))))

(defun bh/punch-out ()
  (interactive)
  (setq bh/keep-clock-running nil)
  (when (org-clock-is-active)
    (org-clock-out))
  (org-agenda-remove-restriction-lock))

(defun bh/clock-in-default-task ()
  (save-excursion
    (org-with-point-at org-clock-default-task
      (org-clock-in))))

(defun bh/clock-in-parent-task ()
  "Move point to the parent (project) task if any and clock in."
  (let ((parent-task))
    (save-excursion
      (save-restriction
        (widen)
        (while (and (not parent-task) (org-up-heading-safe))
          (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
            (setq parent-task (point))))
        (if parent-task
            (org-with-point-at parent-task
              (org-clock-in))
          (when bh/keep-clock-running
            (bh/clock-in-default-task)))))))

(defvar bh/organization-task-id "6B6FB404-85A4-4212-B9D0-D4C2C527DD9D")

(defun bh/clock-in-organization-task-as-default ()
  (interactive)
  (org-with-point-at (org-id-find bh/organization-task-id 'marker)
    (org-clock-in '(16))))

;; 17 Reminders
;; Erase all reminders and rebuilt reminders for today from the agenda
(defun bh/org-agenda-to-appt ()
  (interactive)
  (setq appt-time-msg-list nil)
  (org-agenda-to-appt))

;; Rebuild the reminders everytime the agenda is displayed
(add-hook 'org-agenda-finalize-hook 'bh/org-agenda-to-appt 'append)

;; This is at the end of my .emacs - so appointments are set up when Emacs starts
(bh/org-agenda-to-appt)

;; Activate appointments so we get notifications
(appt-activate t)

;; If we leave Emacs running overnight - reset the appointments one minute after midnight
(run-at-time "24:01" nil 'bh/org-agenda-to-appt)

;; 20 custom command by ken
(defun kk/org-clock-in-switch-task ()
  "Clock in and switch task."
  (interactive)
  (let ((current-prefix-arg '(4)))  ;; This sets the C-u prefix argument
    (call-interactively 'org-clock-in)))


;; Show only top-level headlines
(setq org-startup-folded 'content)



(setq org-agenda-block-separator (make-string 100 ?─))

;; 18.3.5 Agenda view tweaks from https://doc.norang.ca/org-mode.html,
;; adapted for the current Org agenda variable names and time-grid shape.
(with-eval-after-load 'org-agenda
  (setq org-agenda-show-future-repeats t
        org-agenda-show-all-dates t
        org-agenda-start-on-weekday 1
        org-agenda-time-grid '((daily today remove-match)
                               (900 1100 1300 1500 1700)
                               "......"
                               "----------------")
        org-agenda-tags-column -102
        org-agenda-cmp-user-defined #'bh/agenda-sort))

(defun bh/agenda-sort (a b)
  "Sort agenda strings A and B using the Norang daily agenda order."
  (or (bh/agenda-sort-test #'bh/is-not-scheduled-or-deadline a b)
      (bh/agenda-sort-test #'bh/is-due-deadline a b)
      (bh/agenda-sort-test-num #'bh/is-late-deadline #'> a b)
      (bh/agenda-sort-test #'bh/is-scheduled-today a b)
      (bh/agenda-sort-test-num #'bh/is-scheduled-late #'> a b)
      (bh/agenda-sort-test-num #'bh/is-pending-deadline #'< a b)))

(defun bh/agenda-sort-test (fn a b)
  "Return an agenda sort result for A and B using predicate FN."
  (let ((match-a (funcall fn a))
        (match-b (funcall fn b)))
    (cond
     ((and match-a match-b) nil)
     (match-a -1)
     (match-b 1))))

(defun bh/agenda-sort-test-num (fn compfn a b)
  "Return an agenda sort result for A and B using numeric FN and COMPFN."
  (let ((num-a (funcall fn a))
        (num-b (funcall fn b)))
    (cond
     ((and num-a num-b)
      (cond
       ((= num-a num-b) nil)
       ((funcall compfn num-a num-b) -1)
       (t 1)))
     (num-a -1)
     (num-b 1))))

(defun bh/is-not-scheduled-or-deadline (date-str)
  "Return non-nil if DATE-STR is neither scheduled nor a deadline."
  (and (not (bh/is-deadline date-str))
       (not (bh/is-scheduled date-str))))

(defun bh/is-due-deadline (date-str)
  "Return non-nil if DATE-STR is a deadline due today."
  (string-match-p "Deadline:" date-str))

(defun bh/is-late-deadline (date-str)
  "Return overdue deadline days from DATE-STR, or nil."
  (bh/agenda-match-number "\\([0-9]+\\) d\\. ago:" date-str))

(defun bh/is-pending-deadline (date-str)
  "Return pending deadline days from DATE-STR, or nil."
  (bh/agenda-match-number "In \\([0-9]+\\)d\\.:" date-str))

(defun bh/is-deadline (date-str)
  "Return non-nil if DATE-STR describes any deadline state."
  (or (bh/is-due-deadline date-str)
      (bh/is-late-deadline date-str)
      (bh/is-pending-deadline date-str)))

(defun bh/is-scheduled (date-str)
  "Return non-nil if DATE-STR describes any scheduled state."
  (or (bh/is-scheduled-today date-str)
      (bh/is-scheduled-late date-str)))

(defun bh/is-scheduled-today (date-str)
  "Return non-nil if DATE-STR is scheduled today."
  (string-match-p "Scheduled:" date-str))

(defun bh/is-scheduled-late (date-str)
  "Return late scheduled days from DATE-STR, or nil."
  (bh/agenda-match-number "Sched\\.\\s-*\\([0-9]+\\)x:" date-str))

(defun bh/agenda-match-number (regexp date-str)
  "Return the first numeric match for REGEXP in DATE-STR, or nil."
  (when (string-match regexp date-str)
    (string-to-number (match-string 1 date-str))))

(with-eval-after-load 'org
  (let ((cmd '("p" "List priority and schedule tasks"
               ((tags-todo "+PRIORITY=\"A\""
                           ((org-agenda-skip-function '(org-agenda-skip-entry-if 'nottodo '("TODO" "NEXT" "PROJECT" "DELEGATED")))
                            (org-agenda-overriding-header "High-priority unfinished tasks:")))
                (tags-todo "+PRIORITY=\"B\""
                           ((org-agenda-skip-function
                             '(let ((skip (org-agenda-skip-entry-if 'nottodo '("TODO" "NEXT" "PROJECT" "DELEGATED"))))
                                (or skip
                                    (unless (string-match-p "\\[#B\\]" (org-get-heading nil nil nil nil))
                                      (or (outline-next-heading) (point-max))))))
                            (org-agenda-overriding-header "Medium-priority unfinished tasks:")))
                (tags-todo "+PRIORITY=\"C\""
                           ((org-agenda-skip-function '(org-agenda-skip-entry-if 'nottodo '("TODO" "NEXT" "PROJECT" "DELEGATED")))
                            (org-agenda-overriding-header "Low-priority unfinished tasks:")))
                (tags "+INBOX"
                      ((org-agenda-overriding-header "Inbox entries:")))
                (agenda ""))
               ((org-agenda-compact-blocks nil)))))  ; Set compact-blocks to nil only for this view
    (unless (assoc "p" org-agenda-custom-commands)
      (add-to-list 'org-agenda-custom-commands cmd t))))



(use-package org-modern
  :ensure t
  :config
  (setq org-modern-star '("◉" "○" "◈" "◇" "*"))
  ;; IMPORTANT: Disable org-modern's TODO styling to let svg-tag-mode handle it
  (setq org-modern-todo nil)
  (setq org-modern-priority nil)
  (setq org-modern-timestamp nil)
  (setq org-modern-tag t))  ; Also let svg-tag handle tags if desired

(with-eval-after-load 'org
  (global-org-modern-mode))



;; (use-package svg-tag-mode
;;   :ensure t)

;; ;; Configure svg-tag-mode for Org mode
;; (with-eval-after-load 'svg-tag-mode
;;   (defun svg-progress-percent (value)
;;     (save-match-data
;;       (svg-image (svg-lib-concat
;;                   (svg-lib-progress-bar (/ (string-to-number value) 100.0)
;;                                         nil :margin 0 :stroke 2 :radius 3 :padding 2 :width 11)
;;                   (svg-lib-tag (concat value "%")
;;                                nil :stroke 0 :margin 0)) :ascent 'center)))

;;   (defun svg-progress-count (value)
;;     (save-match-data
;;       (let* ((seq (split-string value "/"))
;;              (count (if (stringp (car seq))
;;                         (float (string-to-number (car seq)))
;;                       0))
;;              (total (if (stringp (cadr seq))
;;                         (float (string-to-number (cadr seq)))
;;                       1000)))
;;         (svg-image (svg-lib-concat
;;                     (svg-lib-progress-bar (/ count total) nil
;;                                           :margin 0 :stroke 2 :radius 3 :padding 2 :width 11)
;;                     (svg-lib-tag value nil
;;                                  :stroke 0 :margin 0)) :ascent 'center))))

;;   ;; Define svg-tag patterns
;;   (setq svg-tag-tags
;;         `(
;;           ;; Task priority
;;           ("\\[#[A-Z]\\]" . ( (lambda (tag)
;;                                 (svg-tag-make tag :face 'org-priority
;;                                               :beg 2 :end -1 :margin 0))))

;;           ;; TODO keywords (using org-todo-keyword-faces)
;;           ("TODO" . ((lambda (tag)
;;                         (svg-tag-make "TODO" :face (modus-themes-get-color-value 'green-intense) :margin 0))))
;;           ("NEXT" . ((lambda (tag)
;;                         (svg-tag-make "NEXT" :face (modus-themes-get-color-value 'blue) :margin 0))))
;;           ("DONE" . ((lambda (tag)
;;                         (svg-tag-make "DONE" :face (modus-themes-get-color-value 'fg-dim) :margin 0))))
;;           ("WAITING" . ((lambda (tag)
;;                            (svg-tag-make "WAITING" :face (modus-themes-get-color-value 'cyan) :margin 0))))
;;           ("CANCELLED" . ((lambda (tag)
;;                              (svg-tag-make "CANCELLED" :face (modus-themes-get-color-value 'fg-dim) :margin 0))))
;;           ("HOLD" . ((lambda (tag)
;;                         (svg-tag-make "HOLD" :face (modus-themes-get-color-value 'magenta) :margin 0))))
;;           ("PROJECT" . ((lambda (tag)
;;                            (svg-tag-make "PROJECT" :face (modus-themes-get-color-value 'rust) :margin 0))))
;;           ("DELEGATED" . ((lambda (tag)
;;                              (svg-tag-make "DELEGATED" :face (modus-themes-get-color-value 'rust) :margin 0))))


;;           ;; Citation [cite:@Author:year]
;;           ("\\(\\[cite:@[A-Za-z]+:\\)" . ((lambda (tag)
;;                                             (svg-tag-make tag :inverse t
;;                                                           :beg 7 :end -1 :crop-right t))))
;;           ("\\[cite:@[A-Za-z]+:\\([0-9]+\\]\\)" . ((lambda (tag)
;;                                                      (svg-tag-make tag :end -1 :crop-left t))))

;;           ;; Progress bars
;;           ("\\(\\[[0-9]\\{1,3\\}%\\]\\)" . ((lambda (tag)
;;                                               (svg-progress-percent (substring tag 1 -2)))))
;;           ("\\(\\[[0-9]+/[0-9]+\\]\\)" . ((lambda (tag)
;;                                             (svg-progress-count (substring tag 1 -1)))))
;;           ))

;;   ;; Enable svg-tag-mode in org-mode
;;   (add-hook 'org-mode-hook #'svg-tag-mode))

;; To do:         TODO DONE
;; Tags:          :TAG1:TAG2:TAG3:
;; Priorities:    [#A] [#B] [#C]
;; Progress:      [1/3]
;;                [42%]
;; Active date:   <2021-12-24>
;;                <2021-12-24 Fri>
;;                <2021-12-24 14:00>
;;                <2021-12-24 Fri 14:00>
;; Inactive date: [2021-12-24]
;;                [2021-12-24 Fri]
;;                [2021-12-24 14:00]
;;                [2021-12-24 Fri 14:00]
;; Citation:      [cite:@Knuth:1984]


;; Sync data through Syncthing, Dropbox, iCloud, etc.
;; MUST be set BEFORE `(require 'org-supertag)' below: `supertag-db-file'
;; derives its default from `supertag-data-directory' once, at load time.
;; Setting it after the require leaves `supertag-db-file' frozen at the
;; built-in default (~/.emacs.d/org-supertag/...), which then loads the wrong
;; (local, stale) database instead of the synced one.
(setq supertag-data-directory "~/org/org-supertag/")

;; org-supertag is a multi-file package cloned under external-packages/ by
;; async-installer (see package-list.el).  async-installer only adds it to
;; `load-path' during an interactive install/update, not on every startup, so
;; put its directory on `load-path' here before requiring it.  Guarded so a
;; fresh checkout without the package installed still starts cleanly.
(let ((dir (expand-file-name "external-packages/org-supertag" user-emacs-directory)))
  (when (file-directory-p dir)
    (add-to-list 'load-path dir)
    (when (require 'org-supertag nil t)
      (setq org-supertag-sync-directories '("~/org/")))))

;; 每 60 秒自动同步
(setq org-supertag-sync-directories '("~/org/"))
;; Syncthing 的历史版本目录不参与索引，否则旧文件里的重复 :ID:
;; 会把数据库里的节点路径改写到 .stversions 下的过期副本
(setq supertag-sync-exclude-directories '("~/org/.stversions/"))
(setq supertag-auto-sync-interval 60)

;; 每 10 次 tick 才做一次全量校验（节省 CPU）
(setq supertag-sync-maintenance-every-n-ticks 10)

;; 快照保护：如果目录不可用（如网络盘断开），
;; 不会误判为"文件被删除"而破坏数据库
(setq supertag-sync-snapshot-guard t)

;; 行内 #tag 不用 SVG 药丸徽章，改为「纯文本 + 加粗 + 柔和灰」显示，
;; 让标签像元数据一样低调，不抢标题（如 TODO 的红色）的视觉。
;; 不继承 org-modern-tag：org-modern 干净的圆角 box 效果来自它自己的
;; prettify 流程（padding + box），supertag 的 font-lock 不会跑那一套，
;; 只继承 face 只会得到 secondary-selection 的一块高亮底色，很难看。
;; svg-tag-enable 与 supertag-inline-face 都在 require 之后才存在，且 defface
;; 已捕获旧属性，所以直接改 face 更可靠。
(with-eval-after-load 'org-supertag
  (setq supertag-svg-tag-enable nil)
  ;; 标签文字颜色跟 [#A] 优先级一致：继承 org-priority（会随主题变化），
  ;; 只额外加粗、去掉底色/边框；:height 留空，靠下面 prepend 从标题透下来。
  (set-face-attribute 'supertag-inline-face nil
                      :inherit 'org-priority
                      :background 'unspecified
                      :box nil
                      :weight 'bold
                      :foreground 'unspecified)
  ;; 包里给 #tag 应用 face 时 font-lock override = t，会「替换」掉标题上
  ;; #tag 处的 heading face，从而丢掉 org-level-N 的 :height 缩放
  ;; （1.2/1.3），使标签比 TODO 关键字小一号。改用 prepend：我们的灰+粗
  ;; 仍然覆盖在最上层，但 heading 的高度会透下来，于是与 TODO 同高，
  ;; 且对任意标题层级都成立。SVG 已关，实际用的就是这份 keywords。
  (setq supertag-view-helper--font-lock-keywords
        `((,(concat "#[" supertag-view-helper--valid-tag-chars "]+")
           (0 (if (supertag-view-helper--valid-inline-tag-match-p)
                  'supertag-inline-face)
              prepend)))))

(with-eval-after-load 'org-supertag
  (supertag-enable-org-capture-integration))

(add-to-list
 'org-capture-templates
 '("i" "Inbox task" entry
   (file "~/org/inbox.org")
   "* %^{Title} #task\n"
   :supertag t
   :supertag-template
   ((:tag "task" :field "status"   :value "TODO")
    (:tag "task" :field "priority" :value "C"))))

(provide 'init-local-org)
;;; init-local-org.el ends here
