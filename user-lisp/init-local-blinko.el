;;; init-local-blinko.el --- Post text to a Blinko server -*- lexical-binding: t -*-
;;; Commentary:
;; Blinko is a note server with a REST API.  These commands post text to it as a new note:
;;
;;   SPC n b r  (C-c n b r)  `my/blinko-post-region'   post the region
;;   M-x my/blinko-post-buffer                         post the whole buffer
;;   M-x my/blinko-post-content                        type the text in the minibuffer
;;
;; The server and the token come from `auth-source', for example one line in ~/.authinfo:
;;
;;   machine HOST port PORT login apikey password TOKEN
;;
;; The commands post to https://HOST:PORT/api/v1/note/upsert.  To post to another URL, set
;; `my/blinko-endpoint' (in `custom.el', which Git ignores); the entry for its host gives
;; the token.  With no endpoint, exactly one auth-source entry may have the login `apikey':
;; with two, the commands stop, so a key never goes to the wrong server.
;;
;; The URL library loads on the first post, not at startup.
;;; Code:

(defvar url-request-method)
(defvar url-request-data)
(defvar url-request-extra-headers)
(defvar url-http-response-status)
(defvar url-http-end-of-headers)
(declare-function my/hel-leader-bind "init-local-hel")
(declare-function auth-source-search "auth-source")
(declare-function url-generic-parse-url "url-parse")
(declare-function url-host "url-parse")
(declare-function url-retrieve-synchronously "url")

(defcustom my/blinko-endpoint nil
  "Full URL of the Blinko upsert API, or nil to build it from the auth-source entry."
  :type '(choice (const :tag "From auth-source" nil) string)
  :group 'tools)

(defconst my/blinko-auth-user "apikey" "Login of the Blinko entry in `auth-source'.")
(defconst my/blinko-api-path "/api/v1/note/upsert" "Path of the Blinko upsert API.")

(defun my/blinko--server ()
  "Return (URL . TOKEN) of the Blinko server.  Signal a `user-error' if there is none."
  (require 'auth-source)
  (require 'url)
  (let* ((url (and my/blinko-endpoint (url-generic-parse-url my/blinko-endpoint)))
         (entries (if url
                      (auth-source-search :host (url-host url) :user my/blinko-auth-user :max 1)
                    (auth-source-search :user my/blinko-auth-user :require '(:host :port)
                                        :max 2)))
         (entry (car entries))
         (secret (plist-get entry :secret)))
    (when (cdr entries)
      (user-error (concat "Blinko: several auth-source entries have the login `%s'; "
                          "set `my/blinko-endpoint'")
                  my/blinko-auth-user))
    (unless entry
      (user-error "Blinko: no auth-source entry with the login `%s'" my/blinko-auth-user))
    (cons (or my/blinko-endpoint
              (format "https://%s:%s%s" (plist-get entry :host) (plist-get entry :port)
                      my/blinko-api-path))
          (if (functionp secret) (funcall secret) secret))))

(defun my/blinko--post (content)
  "Post CONTENT to Blinko as a new note.  Signal an error unless the server accepts it."
  (when (string-blank-p content)
    (user-error "Blinko: nothing to post"))
  (let* ((server (my/blinko--server))
         (url-request-method "POST")
         ;; `json-serialize' returns UTF-8 bytes, and url.el needs unibyte strings.
         (url-request-data (json-serialize (list :content content :type 0)))
         (url-request-extra-headers
          `(("Content-Type" . "application/json; charset=utf-8")
            ("Authorization" . ,(encode-coding-string (concat "Bearer " (cdr server)) 'utf-8))))
         (response (url-retrieve-synchronously (car server) t t 5)))
    (unless response
      (user-error "Blinko: no response from the server"))
    (unwind-protect
        (with-current-buffer response
          (let ((status url-http-response-status)
                (body (decode-coding-string
                       (buffer-substring-no-properties (1+ url-http-end-of-headers) (point-max))
                       'utf-8)))
            (if (< status 300)
                (message "Blinko: posted (HTTP %d)" status)
              (error "Blinko: HTTP %d %s" status body))))
      (kill-buffer response))))

(defun my/blinko-post-content (content)
  "Post CONTENT, typed in the minibuffer, to Blinko."
  (interactive "sContent: ")
  (my/blinko--post content))

(defun my/blinko-post-region (start end)
  "Post the region from START to END to Blinko."
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (user-error "Blinko: no region selected")))
  (my/blinko--post (buffer-substring-no-properties start end)))

(defun my/blinko-post-buffer ()
  "Post the whole buffer to Blinko."
  (interactive)
  (my/blinko--post (buffer-substring-no-properties (point-min) (point-max))))

(my/hel-leader-bind "C-c n b r" #'my/blinko-post-region)

(provide 'init-local-blinko)
;;; init-local-blinko.el ends here
