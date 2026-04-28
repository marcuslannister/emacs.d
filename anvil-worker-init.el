;;; anvil-worker-init.el --- Auto-generated -*- lexical-binding: t; -*-

(add-to-list 'load-path "/Users/ken/.emacs.d/external-packages/anvil.el/")
(require 'anvil-server)
(require 'anvil-server-commands)

(defun anvil-worker--eval (expression)
  "Evaluate EXPRESSION on the worker daemon.

MCP Parameters:
  expression - Emacs Lisp expression as a string"
  (anvil-server-with-error-handling
    (let ((result (eval (read expression) t)))
      (format "%S" result))))

(anvil-server-register-tool #'anvil-worker--eval
  :id "eval"
  :description "Evaluate Emacs Lisp on the isolated worker"
  :server-id "worker")

(anvil-server-start)
(message "[anvil-worker] ready")
