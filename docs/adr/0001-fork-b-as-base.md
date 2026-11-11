# Fork the upstream configuration and keep a separate Local layer

The earlier configuration and the Upstream configuration overlap in most areas. We use the Upstream code as the Base of this fork. The user's modules stay in new files (`user-lisp/init-local*.el`), which one `(require 'init-local)` line loads. This keeps a merge from Upstream small. The cost is that Upstream commit messages do not say what changed. Each merge (about once a month) needs a full diff review.

## Considered options

- **Replace the earlier configuration with Upstream.** The user loses the modules they use daily (Hel, Org, Denote, Ghostel, the case guard).
- **Keep the earlier configuration and copy ideas from Upstream.** The two configurations drift apart. Copied code also brings GPL-3.0 terms into a BSD-2-Clause project.

## Named exceptions

- **`async-installer`.** It installs the Git packages (`anvil.el`, `hel`, `hel-leader`, `org-gtd`). `package-vc` does not resolve VC dependencies. The earlier update command also refreshes the Anvil bridge script. `async-installer` has no licence file, so the fork only uses it, and installs it at one reviewed commit.
- **JIT native compilation stays on.** The Base turns it off. On macOS, native code parses `ORG-NEWS` 1.6 times faster, and Emacs ships almost no native code of its own. On Windows, the official GNU build has no `libgccjit` and needs the MSYS2 MINGW64 toolchain. A machine with only the UCRT64 toolchain crashes on every native compile (seen on a real Windows machine). A helper puts the MINGW64 toolchain on the `PATH`, or turns native compilation off with a warning when it finds none.

  **Decision (2026-11-11): JIT stays on for every system, Windows included.** Measured on a real Windows machine (Windows 10, Scoop Emacs 31.1, MINGW64 toolchain), `ORG-NEWS` parsed 5 times: native 3.3 s, byte code 3.8 s, about 12% faster (on macOS, 1.6 times). There were no compile errors or crashes in the async log: 83 `.eln` files after the queue drained. The Base also sets `native-comp-async-on-battery-power` to nil, and Emacs 31.1 reads "not charging" as battery power (`native--compile-skip-on-battery-p`, `comp-run.el`). That skipped every JIT compile on a desktop with no battery (67 files stayed queued) and on a Mac on AC power with a full battery (188 files queued). The fork sets the option to t on every system (marked in `early-init.el`), and a startup check fails if Emacs would skip compiles. If no MINGW64 toolchain exists, the helper still turns JIT off with one warning.
- **`(require 'init-local)` in `init.el`.** It is a line added to a Base file, and it is an eager `require`. It is the one hook that loads the Local layer.
- **A `(load ...)` line in `early-init.el`.** It loads the Windows native-compile helper before package activation. `init-local` is too late, because package activation can start a native compile.

## Consequences

- This fork is GPL-3.0. Do not copy code from the Purcell-derived files of the earlier configuration. Write the same idea again in your own words.
- Completion stays with the Base (`fido`). The earlier `vertico` and `consult` stack does not come over.
