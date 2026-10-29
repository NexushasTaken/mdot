#import "../template.typ": adr

#adr(number: 72, title: [Prompts read one line like pacman: `y`/`yes` is yes, anything else is no], status: [Accepted], date: [2026-10-28])[
= Context
ADR 0062 (the repo-path prompt) and ADR 0068 (the `apply` guard) left open the prompt mechanics they
share: the wording, how an answer is read, what counts as yes, and what EOF or Ctrl-C at the prompt
does. Facts that shaped it:

- ADR 0062 and ADR 0068: both prompts are on stderr, `[y/N]`, default No. `--yes` skips only the
  `apply` prompt. With no terminal on stdin, mdot refuses before asking (exit 1).
- ADR 0068: after a no at the `apply` prompt, nothing more is printed and the exit code is 0.
- ADR 0050: diagnostics are `<word>: <message>` with a lowercase word; normal output has no prefix.
- `design.typ` and ADR 0029: there is no special Ctrl-C handling. ADR 0063: the lock is an OS file
  lock, so a Ctrl-C never leaves mdot locked. ADR 0053: a run killed by a signal gets the code the
  shell gives it.
- The author's reference is pacman. Its `question()` (`src/pacman/util.c`, checked by Claude on
  2026-10-28) reads one line; EOF is no; it trims spaces; an empty line is the default; `y`/`yes`
  is yes and `n`/`no` is no, case-insensitive; *any other answer is no*.

= Options
- *An answer that is not a valid word:*
  - A. Treat it as no. Chosen.
  - B. Ask again.
  - C. Print an error and exit 2. Chosen first, on the belief that pacman does this; replaced by A
    once pacman's source showed it treats such an answer as no.
- *The word `no`:* accepted like `yes` (chosen), or only `n`.
- *Spaces around the answer:* an error (the author's first rule), or trimmed as pacman does (chosen).

= Decision
From the author:

- *Both prompts read an answer the same way,* matching pacman.
- *Yes* is `y` or `yes`; *no* is `n` or `no`. Case does not matter (`Yes`, `YES` are yes).
- *Spaces around the answer are trimmed.*
- *An empty answer is no* (the default).
- *Any other answer is no.*

```
ask(question):
  print "<question> [y/N] " to stderr
  line = read one line from stdin
  if EOF:                      print newline to stderr; return no
  line = trim spaces(line)
  if lowercase(line) in {y, yes}: return yes
  return no                    # n, no, empty, anything else
```

Accepted additions proposed by Claude (reasons are Claude's):
+ *EOF (Ctrl-D) is no,* with a newline printed first so the shell prompt starts on a new line. It
  matches pacman, and no is the safe direction.
+ *Ctrl-C at the prompt has no handler,* as everywhere else in mdot. Nothing has changed yet, the
  lock is released by the OS (ADR 0063), and the repo path is not stored (ADR 0062); the shell
  reports the code (130 in bash).
+ *The `apply` prompt* is `apply? [y/N] `. It names the command it guards.
+ *The repo-path prompt* is `continue anyway? [y/N] `, after the ADR 0062 `warning:` line. "anyway"
  ties the question to the warning above it.
+ *Style:* lowercase, no prefix (no `::` as in pacman), on stderr, the cursor waits after `] `.
  This follows ADR 0050.
+ *An invalid answer is a plain no:* no extra message. For `apply` it exits 0, as any no does
  (ADR 0068).

A moved-repo `apply` (stream on the left):

```
2 | warning: state belongs to /home/nexus/old-dots, this repo is /home/nexus/dotfiles
2 | continue anyway? [y/N] y
2 | apply? [y/N] y
1 | foot
1 |   + link  ~/.config/foot/foot.ini -> foot.ini
```

#table(
  columns: 2,
  [*Answer (any case, spaces trimmed)*], [*Result*],
  [`y`, `yes`], [yes],
  [`n`, `no`, empty], [no],
  [anything else], [no, no message],
  [EOF (Ctrl-D)], [newline, then no],
  [Ctrl-C], [the process dies; nothing changed; the shell's code],
)

= Consequences
- A typo such as `ye` or `yy` is a no, never a yes. The user re-runs the command.
- `yes | mdot apply` is not a way to say yes: stdin is not a terminal, so mdot refuses before
  asking (ADR 0068). Scripts use `--yes`.
- Unlike pacman, a no at the `apply` prompt exits 0, not 1 (ADR 0068).
- Answers are English words only; translated answers are not supported.

= Open
- *The exit code after a no at the repo-path prompt.* ADR 0062 says a no "stops" but gives no code;
  this ADR does not decide it.
]
