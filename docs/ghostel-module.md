# Ghostel native module (local adjustWidth patch)

Mac/Linux only. Windows keeps the kiennq runtime.

## Why

dakra/ghostel v0.53.0 `adjustWidth` can hide a following space so a
standalone glyph can use two cells. It does not check whether that
space is the cursor cell or has visible style. A herdr border before
an empty Pi caret then steals the caret cell.

## Pair

- Lisp: MELPA `ghostel` 20260902.1753 (dakra/ghostel `2bea18f3b52bf97d8222fea706da6fabdfc2cbb8`, tag `v0.53.0`)
- Module: patched `ghostel-module` 0.53.0 in `ghostel-module/` (gitignored)
- Patch: `patches/ghostel-v0.53.0-protect-cursor-spaces.patch`

## Build

Need Zig 0.16.0 exactly. Use a temporary toolchain. Do not keep it on PATH.

```sh
git clone --branch v0.53.0 --depth 1 https://github.com/dakra/ghostel.git
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

When dakra/ghostel ships the same protection, delete the patch, the
module directory contents, and the `ghostel-module-directory` block.
Re-run the glyph tests before you remove them.
