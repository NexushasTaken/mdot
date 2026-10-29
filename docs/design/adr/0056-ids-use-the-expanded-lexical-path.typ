#import "../template.typ": adr

#adr(number: 56, title: [IDs use the expanded, absolute, lexically normal path], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0034 left open which form of a path goes into a resource ID: as written in the spec
(`~/.config/nvim`) or expanded (`/home/nexus/.config/nvim`). Its reason: it matters if state moves
between machines or users with different home directories. ADR 0054 puts the path into both the ID
(`link:<dst>`) and the slot (`fs:<dst>`).

Constraints:
- ADR 0020: only a leading `~` is expanded, to `$HOME`.
- `link-rules.typ`: normalize every input path once, to an absolute, lexically normal path, and use
  only that afterwards.
- ADR 0010 / `design.typ`: state lives per machine in `$XDG_STATE_HOME/mdot/<repo-id>/`.
- ADR 0021: the same-`dst` check compares paths, so two spellings of one place must give one string.
- The code already works this way: `link_match` asserts absolute paths, and `HasId` uses that `dst`.

= Options
- *As written* or *expanded.*
- *Lexical* normalizing (string rules only: drop a trailing `/`, remove `.`, fold `a/../`), or
  *resolved* (also follow symlinks in the parent directories, never the last part, which is the
  resource itself).
- *Case-insensitive filesystems:* ignore it, lowercase on some OSes, or probe the filesystem. Not
  decided (see Open).

= Decision
From the author:
- *The path is expanded, not stored as written.* State never moves between machines or users.
- *It is always absolute.*
- *Lexical normalizing,* chosen on Claude's recommendation. Claude's reasons: the ID comes from the
  spec alone with no disk access (live is observed only after matching, ADR 0034), so `plan` stays
  deterministic and IDs are testable without a filesystem; it works before parent directories exist
  (ADR 0016); the ID does not change when a parent symlink is re-pointed; and it is the rule
  `link-rules.typ` already states.

Accepted addition:
- *The slot uses the same form,* for example `fs:/home/nexus/.config/nvim`, so the conflict check and
  the freed-slot check (ADR 0054) compare the same spelling as the ID.

= Consequences
- Closes ADR 0034's last open item; ADR 0034 is confirmed as Accepted.
- If `$HOME` changes, every path ID changes: the old records become recorded-only and the specs'
  resources new. Accepted, since state is per machine and user.
- Two spellings of one place through a symlinked parent (`~/.config/nvim` with `~/.config` a link to
  `~/sync/config`, and `~/sync/config/nvim`) give two IDs, so the same-`dst` check misses them. Rare,
  and only from the user's own specs.

= Open
- *Case-insensitive filesystems* (macOS and Windows by default): `~/.Config/nvim` and
  `~/.config/nvim` are one place but two IDs. Revisit when macOS or Windows support is built.
- *Whether `plan` shows `~/...`* instead of the full path, for display only (ADR 0051).
- *`sudo` and system scope,* where `~` is another user's home (ADR 0007, ADR 0020).
]
