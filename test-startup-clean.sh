#!/bin/sh -e
# Run test-startup.sh the way CI does: a copy of the repo files (tracked and
# not ignored, so uncommitted edits count), an empty HOME, and a PATH without
# rg.  Gitignored folders such as external-packages/ and elpa-*/ are absent, so
# a hard dependency on one of them fails here, as it does in CI.
# Installs every package from the network; it takes a few minutes.
root=$(cd "$(dirname "$0")" && pwd)
emacs=$(command -v "${EMACS:-emacs}")
tmp=$(mktemp -d)
trap 'find "$tmp" -delete' EXIT
mkdir "$tmp/repo" "$tmp/bin" "$tmp/home"
ln -s "$emacs" "$tmp/bin/emacs"
ln -s "$(command -v git)" "$tmp/bin/git"
git -C "$root" ls-files -z --cached --others --exclude-standard |
  tar -C "$root" --null -T - -cf - | tar -C "$tmp/repo" -xf -
cd "$tmp/repo"
env PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp/home" EMACS="$emacs" ./test-startup.sh
