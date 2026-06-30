# Frame State Cache Design

## Problem
`frame-state.el` (the persisted data file) is runtime cache, not trusted
configuration. On Windows, minimized frames can report sentinel coordinates
near `-32000`; geometry saved on one monitor layout can also be off-screen on
another. If such values are restored into `initial-frame-alist` during
`early-init.el`, Emacs can start with an invisible or unusable first frame.

## Decision
Treat the persisted state as untrusted disposable cache. Keep frame restore,
but validate every field on load. A rejected cache self-heals on the next good
save.

## Implementation
- `lib/frame-state.el` — dependency-free helper (built-ins only), loaded by
  `early-init.el` via absolute path (`lib/` is not on `load-path` that early).
      - `my/frame-state-sanitize` — pure validator; the testable core.
  - `my/save-frame-state` / `my/load-frame-state` — load pipes through sanitize.
- `early-init.el` — loads the helper, then restores + registers the save hook.

## Validation (per-field degradation)
- `left`/`top`: integer in `(-31000, 31000)`. Position is a pair — if either
  axis is invalid, both are dropped and the window manager places the frame.
- `width`/`height`: integer in `(0, 10000)`; dropped individually.
- `fullscreen`: one of `nil fullboth fullheight fullwidth maximized`.
- Malformed/garbage input → `nil`, no error. Valid fields always survive.

The save-side minimize guard (skips writing `~-32000`) is kept as complementary
defense; load validation is the trust boundary.

## Not covered
Off-screen detection for geometry that is *in range but on a monitor that no
longer exists* (e.g. `top=1410` on a since-removed display). That needs monitor
geometry unavailable in `early-init` before the first frame; a post-frame
recenter on `window-setup-hook` is a possible future follow-up.

## Tests
`tests/frame-state-tests.el` (ERT):
`emacs --batch -l tests/frame-state-tests.el -f ert-run-tests-batch-and-exit`
