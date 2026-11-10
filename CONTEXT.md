# emacs.d-nn

A fork of the upstream Emacs configuration. The user's own modules stay in separate files, so that upstream changes merge with little work.

## Fork

**Base**:
The upstream code in this fork. Changes to it are removals and value changes only.
_Avoid_: Core, vanilla

**Local layer**:
The user's own modules, in `user-lisp/init-local*.el`. It wins every overlap with the Base.
_Avoid_: Overlay, plugin, patch set

**Upstream**:
The repository `zHaOdANiuu/.emacs.d`, from which this fork was made.
_Avoid_: Origin (this is the name of the fork's own remote)

**Concept rules**:
The four rules of the Upstream design: small modules, built-in features first, a package only if used weekly, and deferred loading with no eager `require`. They bind the Local layer.
_Avoid_: Style guide

**Cutover**:
The switch of `~/.emacs.d` from the earlier configuration to this fork.
_Avoid_: Migration, release

## Task management

**Task**:
An Org heading representing actionable work, with a stable ID and a TODO state.
_Avoid_: Item, record

**Priority**:
A Task's urgency rank: A, B, or C.
_Avoid_: Importance, severity

**Open Task**:
A Task whose TODO state is not a done state. Done-state membership follows the configured Org workflow.
_Avoid_: Active item, pending record
