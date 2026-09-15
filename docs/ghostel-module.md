# Ghostel native module (local adjustWidth patch)

Mac/Linux only. Windows keeps the kiennq runtime.

## Why

dakra/ghostel v0.53.0 `adjustWidth` can hide a following space so a
standalone glyph can use two cells. It does not check whether that
space is the cursor cell or has visible style. A herdr border before
an empty Pi caret then steals the caret cell.

## Pair

- Lisp: MELPA `ghostel` 20260915.554 (dakra/ghostel `f1b03e52c4c48bd66772317ebedfa374a4083afe`, tag `v0.54.0`)
- Module: patched `ghostel-module` 0.54.0 in `ghostel-module/` (gitignored)
- Patch: `patches/ghostel-v0.53.0-protect-cursor-spaces.patch` (still applies cleanly on `v0.54.0`)
- Upstream: [dakra/ghostel#678](https://github.com/dakra/ghostel/pull/678)

`v0.54.0` also carries the [#686](https://github.com/dakra/ghostel/pull/686)
fix for [#677](https://github.com/dakra/ghostel/issues/677): the native PTY
backend now fills `ws_xpixel`/`ws_ypixel` in `TIOCSWINSZ`, so `kitten icat`
and other pixel-size readers work.

## Build

Need Zig 0.16.0 exactly. Use a temporary toolchain. Do not keep it on PATH.

```sh
git clone --branch v0.54.0 --depth 1 https://github.com/dakra/ghostel.git
cd ghostel
git apply /path/to/emacs.d/patches/ghostel-v0.53.0-protect-cursor-spaces.patch
zig build --prefix . -Doptimize=ReleaseFast -Dcpu=baseline
mkdir -p ~/.emacs.d/ghostel-module
cp ghostel-module.dylib ghostel-module.version ~/.emacs.d/ghostel-module/
```

On Linux the module name is `ghostel-module.so`. `nix-shell -p zig` is
one way to get 0.16.0 without a permanent install.

## Test

From the patched checkout:

```sh
make .build/tests/native-ghostel-glyph-test.ok
```

## Rollback

Delete `~/.emacs.d/ghostel-module/ghostel-module.dylib` and the sidecar.
The config then leaves `ghostel-module-directory` unset and MELPA's
module is used. Restart Emacs.

## Remove when upstream replaces it

Watch [dakra/ghostel#678](https://github.com/dakra/ghostel/pull/678).
When it merges, or upstream ships the same protection another way,
delete the patch, the module directory contents, and the
`ghostel-module-directory` block. Re-run the glyph tests before you
remove them.
