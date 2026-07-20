# Task Management

This context defines the task concepts used by the Emacs configuration.

## Language

**Task**:
An Org heading representing actionable work, with a stable ID and a TODO state.
_Avoid_: Item, record

**Task Table**:
An interactive collection view of Tasks showing their TODO state, Priority, and heading text.
_Avoid_: Task list, spreadsheet

**Priority**:
A Task's urgency rank: A, B, or C.
_Avoid_: Importance, severity

**Open Task**:
A Task whose TODO state is not a done state. Done-state membership follows the configured Org workflow.
_Avoid_: Active item, pending record
