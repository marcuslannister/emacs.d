;;; init-local-blinko-tests.el --- Tests for init-local-blinko -*- lexical-binding: t -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-blinko-tests.el -f ert-run-tests-batch-and-exit
;; No test opens a connection: `auth-source-search' and `url-retrieve-synchronously' are stubs.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'url)
(require 'auth-source)

(defvar init-local-blinko-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")

(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-blinko-tests--keys)))

(load (expand-file-name "../user-lisp/init-local-blinko.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(defun init-local-blinko-tests--entry (host port secret)
  "Return an auth-source entry for HOST and PORT whose secret function gives SECRET."
  (list :host host :port port :user "apikey" :secret (lambda () secret)))

(defun init-local-blinko-tests--response (status body)
  "Return a buffer that looks like the answer of `url-retrieve-synchronously'."
  (with-current-buffer (generate-new-buffer " *blinko-test-response*")
    (insert "HTTP/1.1 " (number-to-string status) " X\r\n\r\n")
    (setq-local url-http-response-status status)
    (setq-local url-http-end-of-headers (1- (point)))
    (insert (encode-coding-string body 'utf-8))
    (current-buffer)))

(ert-deftest init-local-blinko-binds-only-the-region-key ()
  (should (equal '(("C-c n b r" . my/blinko-post-region)) init-local-blinko-tests--keys)))

(ert-deftest init-local-blinko-builds-the-url-from-the-one-auth-source-entry ()
  (let ((my/blinko-endpoint nil) args)
    (cl-letf (((symbol-function 'auth-source-search)
               (lambda (&rest a)
                 (setq args a)
                 (list (init-local-blinko-tests--entry "blinko.test" "8443" "T0K")))))
      (should (equal '("https://blinko.test:8443/api/v1/note/upsert" . "T0K")
                     (my/blinko--server))))
    (should (equal "apikey" (plist-get args :user)))
    (should (equal '(:host :port) (plist-get args :require)))))

(ert-deftest init-local-blinko-refuses-to-guess-between-two-entries ()
  (let ((my/blinko-endpoint nil))
    (cl-letf (((symbol-function 'auth-source-search)
               (lambda (&rest _)
                 (list (init-local-blinko-tests--entry "a.test" "1" "A")
                       (init-local-blinko-tests--entry "b.test" "2" "B")))))
      (should-error (my/blinko--server) :type 'user-error))))

(ert-deftest init-local-blinko-endpoint-takes-the-token-of-its-host-only ()
  (let ((my/blinko-endpoint "http://local.test:9/up") args)
    (cl-letf (((symbol-function 'auth-source-search)
               (lambda (&rest a)
                 (setq args a)
                 (list (init-local-blinko-tests--entry "local.test" "9" "T0K")))))
      (should (equal '("http://local.test:9/up" . "T0K") (my/blinko--server))))
    (should (equal "local.test" (plist-get args :host)))
    ;; With no entry for that host, there is no fall back to another service's key.
    (cl-letf (((symbol-function 'auth-source-search) (lambda (&rest _) nil)))
      (should-error (my/blinko--server) :type 'user-error))))

(ert-deftest init-local-blinko-posts-utf-8-json-with-the-bearer-token ()
  (let (seen)
    (cl-letf (((symbol-function 'my/blinko--server) (lambda () '("https://b.test/up" . "T0K")))
              ((symbol-function 'url-retrieve-synchronously)
               (lambda (url &rest _)
                 (setq seen (list url url-request-method url-request-data
                                  url-request-extra-headers))
                 (init-local-blinko-tests--response 200 "{}"))))
      (my/blinko--post "你好 hi"))
    (pcase-let ((`(,url ,method ,data ,headers) seen))
      (should (equal "https://b.test/up" url))
      (should (equal "POST" method))
      (should-not (multibyte-string-p data))
      (should (equal '((content . "你好 hi") (type . 0))
                     (json-parse-string (decode-coding-string data 'utf-8)
                                        :object-type 'alist :false-object nil)))
      (should (equal "Bearer T0K" (cdr (assoc "Authorization" headers))))
      (should-not (multibyte-string-p (cdr (assoc "Authorization" headers)))))))

(ert-deftest init-local-blinko-signals-the-server-error-and-never-the-token ()
  (cl-letf (((symbol-function 'my/blinko--server) (lambda () '("https://b.test/up" . "T0K")))
            ((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _) (init-local-blinko-tests--response 401 "bad token"))))
    (let ((err (should-error (my/blinko--post "x"))))
      (should (string-match-p "HTTP 401 bad token" (cadr err)))
      (should-not (string-match-p "T0K" (cadr err))))))

(ert-deftest init-local-blinko-stops-when-the-server-does-not-answer ()
  (cl-letf (((symbol-function 'my/blinko--server) (lambda () '("https://b.test/up" . "T")))
            ((symbol-function 'url-retrieve-synchronously) (lambda (&rest _) nil)))
    (should-error (my/blinko--post "x") :type 'user-error)))

(ert-deftest init-local-blinko-does-not-post-blank-text ()
  (cl-letf (((symbol-function 'my/blinko--server) (lambda () (error "Must not look up")))
            ((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _) (error "Must not post"))))
    (should-error (my/blinko--post " \n\t") :type 'user-error)))

(ert-deftest init-local-blinko-region-command-posts-the-region-only ()
  (let (posted)
    (cl-letf (((symbol-function 'my/blinko--post) (lambda (text) (setq posted text))))
      (with-temp-buffer
        (insert "one two three")
        (transient-mark-mode 1)
        (set-mark 5)
        (goto-char 8)
        (activate-mark)
        (call-interactively #'my/blinko-post-region)
        (should (equal "two" posted))
        (deactivate-mark)
        (setq posted nil)
        (should-error (call-interactively #'my/blinko-post-region) :type 'user-error)
        (should-not posted)))))

(ert-deftest init-local-blinko-buffer-command-posts-the-whole-buffer ()
  (let (posted)
    (cl-letf (((symbol-function 'my/blinko--post) (lambda (text) (setq posted text))))
      (with-temp-buffer
        (insert "all of it")
        (my/blinko-post-buffer)))
    (should (equal "all of it" posted))))

(provide 'init-local-blinko-tests)
;;; init-local-blinko-tests.el ends here
