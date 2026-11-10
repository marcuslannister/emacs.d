# Fork the upstream configuration and keep a separate Local layer

The user's earlier configuration (`marcuslannister/emacs.d`) and the Upstream configuration overlap in most areas. We use the Upstream code as the Base of this fork, and we keep the user's modules in new files (`user-lisp/init-local*.el`) that one `(require 'init-local)` line loads. Changes to Base files are removals and value changes only, each marked `;; emacs.d-nn:`. This keeps a merge from Upstream small. The cost is that Upstream commit messages do not say what changed, so each merge (about once a month) needs a full diff review.

## Considered options

- **Replace the earlier configuration with Upstream.** The user loses the modules they use daily (Hel, Org, Denote, Ghostel, the case guard).
- **Keep the earlier configuration and copy ideas from Upstream.** The two configurations drift apart, and copied code brings GPL-3.0 terms into a BSD-2-Clause project.

## Named exceptions to the Concept rules

- **`async-installer`.** It installs the Git packages (`anvil.el`, `hel`, `hel-leader`, `org-gtd`). `package-vc` does not resolve VC dependencies, and the earlier update command also refreshes the Anvil bridge script.
- **JIT native compilation stays on.** The Base turns it off. On macOS, native code parses `ORG-NEWS` 1.6 times faster, and Emacs ships almost no native code of its own. Whether Windows needs JIT off is not yet checked on a real Windows machine.

## Consequences

- This fork is GPL-3.0. Do not copy code from the Purcell-derived files of the earlier configuration. Write the same idea again in your own words.
- Completion stays with the Base (`fido`). The earlier `vertico` and `consult` stack does not come over.
