;;; init-local-proofread.el --- Context-aware LLM proofreading -*- lexical-binding: t -*-
;;; Commentary:

;; This module holds the machinery only.  The endpoint that serves the model is
;; private, so its coordinates live in `init-local-proofread-config.el', which
;; is gitignored.  To enable proofreading on a new machine, copy
;; `init-local-proofread-config.el.template' to that name and fill it in.
;;
;; Without that file the module defines its variables and stops: it touches no
;; `load-path', installs no package, and leaves `proofread-profiles' alone.

;;; Code:

(require 'auth-source)

(defvar ml-proofread-checker-name 'openrouter
  "Symbol that identifies the checker inside proofread.")

(defvar ml-proofread-endpoint-url nil
  "Base URL of the OpenAI-compatible endpoint, with a trailing slash.
`llm' appends the command itself, so this stops before the command:
use \"https://example.test/v1/\", not \".../v1/chat/completions\".")

(defvar ml-proofread-auth-host nil
  "Value of the `:host' field that carries the API key in ~/.authinfo.")

(defvar ml-proofread-auth-user "apikey"
  "Value of the `:user' field that carries the API key in ~/.authinfo.")

(defvar ml-proofread-chat-model nil
  "Name of the model to request from `ml-proofread-endpoint-url'.")

(defvar ml-proofread-provider-identity nil
  "Provider identity string recorded on each proofread result.")

(defvar ml-proofread-source-label nil
  "Human-readable label shown for results from this checker.")

(require 'init-local-proofread-config nil t)

(defun ml-proofread--model-request-params (model)
  "Return the non-standard chat parameters that MODEL needs, if any.
Only Gemini 3.7 Flash gets any: it names a route that serves that model
alone, so every other model starts clean.  A model that needs parameters
of its own takes a clause here."
  (and (equal model "google/gemini-3.7-flash")
       '((reasoning . ((effort . "low")
                       (exclude . t)))
         (provider . ((order . ["google-vertex/global"])
                      (allow_fallbacks . :false)
                      (require_parameters . t))))))

(defun ml-proofread--ensure-gemini-3-7-flash-metadata ()
  "Register Gemini 3.7 Flash capabilities when `llm' does not know them."
  (when (and (equal ml-proofread-chat-model "google/gemini-3.7-flash")
             (not (llm-models-match ml-proofread-chat-model)))
    (llm-models-add
     :name "Gemini 3.7 Flash"
     :symbol 'gemini-3-7-flash
     ;; Only what proofreading asks of it: `proofread-llm' picks provider JSON
     ;; over prompt-only JSON on `json-response', and the checker sends a
     ;; reasoning effort.
     :capabilities '(generation json-response reasoning)
     :context-length 1048576
     :regex "gemini-3\\.7-flash\\'")))

(defun ml-proofread--provider (model params)
  "Build an `llm' provider that reaches MODEL over the private endpoint.
PARAMS is an alist of non-standard chat parameters, as returned by
`ml-proofread--model-request-params'."
  (make-llm-openrouter
   :url ml-proofread-endpoint-url
   ;; llm resolves a function-valued `:key' at request time, so ~/.authinfo is
   ;; read on first check and the secret never lands in the provider struct.
   :key (lambda ()
          (auth-source-pick-first-password
           :host ml-proofread-auth-host
           :user ml-proofread-auth-user))
   :chat-model model
   :default-chat-non-standard-params params))

(defun ml-proofread--checker ()
  "Build the proofread checker from the private endpoint settings."
  `( :name ,ml-proofread-checker-name
     :backend llm
     :options ( :provider ,(ml-proofread--provider
                            ml-proofread-chat-model
                            (ml-proofread--model-request-params
                             ml-proofread-chat-model))
                :provider-identity ,ml-proofread-provider-identity
                :source-label ,ml-proofread-source-label
                :response-strategy auto
                :diagnostic-passes 1)))

;; Everything below is optional tooling, so nothing is loaded or installed
;; until the private config proves there is an endpoint to talk to.
(when (and ml-proofread-endpoint-url ml-proofread-chat-model)
  ;; Proofread is registered in lisp/package-list.el, but async-installer only
  ;; extends `load-path' during install postprocess, so — as with anvil — the
  ;; directory has to be re-added on every startup.
  (let ((proofread-dir (expand-file-name
                        "external-packages/emacs-proofread/lisp/proofread"
                        user-emacs-directory)))
    (when (file-directory-p proofread-dir)
      (add-to-list 'load-path proofread-dir)))

  ;; `maybe-require-package' downgrades an install failure to a warning, and
  ;; the clone is asynchronous on a fresh machine, so tolerate proofread being
  ;; absent on the very first startup after registration.
  (when (and (maybe-require-package 'llm)
             (require 'llm-openai nil t)
             (require 'proofread nil t))
    (ml-proofread--ensure-gemini-3-7-flash-metadata)
    (setq proofread-profiles
          `((english . ( :language "en"
                         :display-language "English"
                         :checkers (,(ml-proofread--checker))))))
    (setq proofread-profile 'english)))

(provide 'init-local-proofread)
;;; init-local-proofread.el ends here
