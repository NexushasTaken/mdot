---
name: learn
description: Teach any topic as a short structured lesson series (mental model, key facts, failure modes or misconceptions, check questions). No exercises, no link to a project. Use when the user runs /learn <topic> or asks for a general lesson on a topic.
---

# Learn

A general-purpose lesson on any topic: programming, tools, theory, or anything else.
The goal is understanding: a correct mental model and the key facts, without having to
apply it to a project. There are no exercises and no bridge to mdot (use `/course` for
that). Don't assume my level. Find it in the scope step.

## 1. Scope first (in chat, before writing anything)

- Ask what I want out of the topic (curiosity, a decision, reading something, etc.).
- Ask 2–3 short check questions to find my level. "I don't know" is a valid answer;
  this is a placement check, not a test.
- If the basics are missing, start the outline with foundations lessons.
- Propose a short outline: lessons of about one sitting each. Keep it small.
- Wait for my OK.

## 2. Each lesson (saved to `docs/learn/<topic>/NN-<name>.md`)

If `docs/learn/<topic>/` already has lessons (from `/learn` or `/course`), continue
the numbering after the highest existing `NN`.

1. **Mental model:** how the thing actually works underneath, and why it is that way.
2. **Key facts:** the vocabulary, rules, or parts that matter. For code topics this is
   the API map: the functions involved, how each reports errors, and the known traps.
3. **Failure modes or misconceptions:** what goes wrong, or what people commonly get
   wrong, and the correct view. A table when it fits. Skip it if the topic has none.
4. **Sources:** cite where the facts come from (man pages, cppreference, official
   docs, papers, books). Verify claims by experiment in the scratchpad when possible.
   Say when unsure.
5. **Check questions:** 2–3 short questions to answer in chat. Optional for me.

Explain the why. Don't flood me: keep each lesson to one sitting.

Inside mdot, code blocks in lessons are toy examples only (see CLAUDE.md rule 2).

## 3. Between lessons

If I answer the check questions, give honest, kind feedback and fix any wrong mental
model before moving on. Move to the next lesson only when I say so.
