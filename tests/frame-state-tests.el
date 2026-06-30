;;; frame-state-tests.el --- Tests for frame-state cache validation -*- lexical-binding: t; -*-

(require 'ert)

(load-file (expand-file-name "../lib/frame-state.el"
                             (file-name-directory load-file-name)))

(ert-deftest frame-state-sanitize-passes-clean-state ()
  "A well-formed state survives sanitization unchanged."
  (let ((state '((left . 0) (top . 100) (width . 200) (height . 60)
                 (fullscreen . maximized))))
    (should (equal (my/frame-state-sanitize state) state))))

(ert-deftest frame-state-sanitize-rejects-minimized-sentinel ()
  "The Windows -32000 minimize sentinel never reaches the frame alist."
  (let ((clean (my/frame-state-sanitize
                '((left . -32000) (top . -32000) (width . 200) (height . 60)))))
    (should-not (assq 'left clean))
    (should-not (assq 'top clean))
    ;; Size is still usable and is preserved.
    (should (equal (cdr (assq 'width clean)) 200))
    (should (equal (cdr (assq 'height clean)) 60))))

(ert-deftest frame-state-sanitize-drops-both-positions-when-one-bad ()
  "Position is a pair: a single bad axis drops both, size is kept."
  (let ((clean (my/frame-state-sanitize
                '((left . 0) (top . 999999) (width . 200) (height . 60)))))
    (should-not (assq 'left clean))
    (should-not (assq 'top clean))
    (should (equal (cdr (assq 'width clean)) 200))))

(ert-deftest frame-state-sanitize-drops-invalid-size ()
  "Non-positive or absurd dimensions are dropped individually."
  (let ((clean (my/frame-state-sanitize
                '((left . 0) (top . 0) (width . 0) (height . 60)))))
    (should (equal (cdr (assq 'left clean)) 0))
    (should-not (assq 'width clean))
    (should (equal (cdr (assq 'height clean)) 60))))

(ert-deftest frame-state-sanitize-enforces-fullscreen-whitelist ()
  "Only known `fullscreen' symbols pass."
  (should (equal (my/frame-state-sanitize '((fullscreen . maximized)))
                 '((fullscreen . maximized))))
  (should-not (assq 'fullscreen
                    (my/frame-state-sanitize '((fullscreen . bogus))))))

(ert-deftest frame-state-sanitize-handles-garbage ()
  "Malformed input yields nil without signalling."
  (should-not (my/frame-state-sanitize 42))
  (should-not (my/frame-state-sanitize '(1 2 3)))
  (should-not (my/frame-state-sanitize "not a list")))

(provide 'frame-state-tests)
;;; frame-state-tests.el ends here
