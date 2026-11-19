;;; init-local-translate.el --- Translate with gt and StarDict -*- lexical-binding: t -*-
;;; Commentary:
;; SPC g t runs `gt-translate`, as in the Earlier configuration.  The engine is
;; StarDict (`sdcv`), between English and Chinese.  Without `sdcv`, the module
;; warns and does not bind the key.  The package loads on first use.
;;; Code:

(declare-function my/hel-leader-bind "init-local-hel")

(defun my/translate-setup ()
  "Bind SPC g t to `gt-translate' when the sdcv program exists."
  (if (not (executable-find "sdcv"))
      (display-warning
       'init-local-translate
       "The sdcv program is not on the PATH; translate is off")
    (use-package gt
      :ensure t
      :commands gt-translate
      :config
      ;; Current gt takes the language pair on the taker, not in `gt-langs'.
      (setq gt-default-translator
            (gt-translator :taker (gt-taker :langs '(en zh))
                           :engines (gt-stardict-engine))))
    (my/hel-leader-bind "C-c g t" #'gt-translate)))

(provide 'init-local-translate)
;;; init-local-translate.el ends here
