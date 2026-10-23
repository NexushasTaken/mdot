---
name: decide
description: Make one mdot design decision together and record it as an ADR or spec change. I reason first, Claude challenges and explains, then records only what I confirmed. Use when the user runs /decide <topic>, wants to make or revisit a design/spec decision, or wants to confirm a Proposed ADR.
---

# Decide

Adapted from VibeWise (github.com/nykooi1/vibe-wise), with "AI writes the code"
replaced by "AI writes the docs". I own the design. Claude asks, explains,
challenges, and then writes down what I decided. The CLAUDE.md rules under "Writing
design docs" apply throughout.

One decision per run. If the topic splits into several decisions, say so and pick one.

**No Artifacts or hosted docs.** Don't use the Artifact tool, Claude Docs, or any other
published page, not even for a summary or diagram. Discussion stays in chat. Every
change is a file edit inside `docs/`.

## 1. Context (in chat)

- Read the related ADRs, `design.typ`, and code if it exists. If the topic is a
  Proposed ADR, this run is its confirmation: start from that ADR.
- State the problem in 1–3 sentences: what must be decided, the requirements, and which
  existing ADRs constrain it. Facts only, no design yet.

## 2. Build checkpoint

Ask how I would approach it. Then wait. Don't offer options or a preferred design
first. Plain English, sketches, or pseudocode are all fine answers.

- Respond to my actual reasoning: challenge assumptions, edge cases, and how it fits
  the other ADRs. A workable approach doesn't have to be the one you'd pick.
- Don't lead me to your design one missing piece at a time.
- If I say I'm stuck or ask for options, give enough to let me take the lead again
  (a concept, a tradeoff, two or three options), not a full design to approve.
- A few questions at a time, not ten.

## 3. Concept / Why this matters

When a concept is unfamiliar, explain it as **Concept** (what it is, how it works) and
**Why this matters** (its consequence for mdot). Then leave the decision open and ask
me to apply it. Verify claims; say when unsure.

## 4. Design checkpoint

When the reasoning is enough, summarize in chat:

- **My decision:** what I chose and my reasons, in my words. Don't add reasons I
  didn't give.
- **Options considered:** only those we actually discussed.
- **Proposed additions:** a table (Detail / Proposal / Why) of details you'd add. I
  accept or reject each. Consequential open questions aren't rows to approve; they
  go back to step 2.
- **Open:** what stays undecided.

Then ask with AskUserQuestion: **Confirm and record** or **Discuss**. Confirming
means I'm ready to record it. It doesn't prove I understand it.

## 5. Record

- Write a new ADR in `docs/adr/NNNN-<slug>.typ` using `docs/template.typ` (`#adr(...)`, Context /
  Options / Decision / Consequences), add it to `docs/adr/main.typ`'s table, and
  update `design.typ` if the spec changes.
- Status: **Accepted** for what I decided in this run. My rejected additions are left
  out. Open items are written as open, not filled in.
- Accepted ADRs are never edited: superseding one means a new ADR and a status update
  in the index. Confirming a Proposed ADR may update it in place to Accepted.
- Report in chat which files changed. No commits unless I ask.

Docs must not become a back door for mdot's implementation (CLAUDE.md rule 3).
