# Denote Journal Carry-Forward Open Todos

## Summary

Add a new interactive command, `my/denote-journal-new-entry-with-open-todos`, to the local Denote configuration. The command will create or open the current journal entry, copy unfinished Markdown checkbox items from the most recent earlier journal file, and preserve the existing timestamp insertion behavior used by the local journal helper.

## Goals

- Keep the current `my/denote-journal-new-or-existing-entry` command unchanged.
- Provide a separate command for explicitly carrying unfinished todos forward.
- Select the source journal as the latest journal file strictly older than the target journal date.
- Copy only unfinished Markdown checkbox items such as `- [ ] task` or `* [ ] task`.
- Avoid duplicating the carried-forward block when the command is run repeatedly on the same journal file.

## Non-Goals

- Parsing Org-mode TODO states.
- Carrying forward nested task blocks, metadata, or arbitrary Markdown sections.
- Scanning all historical journals for unfinished items.
- Modifying the previous journal file.

## User Flow

1. The user invokes `my/denote-journal-new-entry-with-open-todos`.
2. The command opens an existing journal file for the requested date, or creates a new one through Denote journal APIs.
3. The command finds the latest journal file with a Denote identifier date earlier than the target date.
4. The command extracts unfinished Markdown checkbox lines from that source file.
5. If unfinished items exist and the target file does not already contain the carry-forward section, the command inserts:
   - a heading named `## Carried Forward`
   - the copied unfinished checkbox lines
6. The command appends the existing timestamp section format at the end of the file and enters Evil insert state when available.

## Source File Resolution

- The target date defaults to today and may be overridden by the same optional prefix-date flow used by the existing local command.
- Source selection is based on journal file dates, not filename modification time.
- The chosen source is the journal with the greatest Denote identifier date that is still strictly less than the target date.
- Year boundaries are handled naturally because comparison is based on the parsed identifier date, so a January entry can pick a December entry from the prior year.

## Markdown Todo Matching

The carry-forward logic only matches standalone unfinished Markdown checkbox lines:

- `- [ ] task`
- `* [ ] task`
- `+ [ ] task`

Completed items such as `- [x] task` or `- [X] task` are excluded.

Indented or nested checkbox items are not part of the initial scope unless they already match the same simple line-based pattern cleanly.

## Idempotency Rules

- If the target journal already contains a `## Carried Forward` heading, the command must not insert a second carry-forward block.
- If there is no previous journal file, the command should skip carry-forward silently.
- If the previous journal contains no unfinished Markdown checkboxes, the command should skip carry-forward silently.

## Implementation Shape

Add helper functions in `lisp/init-local-denote.el` for:

- listing journal files
- resolving the latest prior journal file relative to a target date
- extracting unfinished Markdown checkbox lines from a file
- inserting the carry-forward section when absent
- reusing the existing timestamp insertion logic from a small shared helper

Bind the new command in local keybindings after implementation so it is easy to invoke without replacing the existing journal command.

## Error Handling

- If Denote journal is unavailable, startup should still fail the same way it does today rather than adding custom suppression.
- Missing or unreadable source files should result in a normal Emacs error only when file access itself fails unexpectedly.
- The common no-source and no-open-todos cases should not raise errors.

## Testing

- Add regression tests for latest-prior-journal resolution across normal and cross-year cases.
- Add regression tests for Markdown unfinished checkbox extraction.
- Add regression tests for idempotent insertion of the carry-forward block.
- Run `./test-startup.sh` to confirm the configuration still loads cleanly.
