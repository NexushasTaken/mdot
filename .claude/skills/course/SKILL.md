---
name: course
description: Teach a topic as a short structured course (mental model, API map, failure modes, exercises, bridge to mdot). Use when the user runs /course <topic> or asks for a course or lesson on a topic.
---

# Course

The goal is to close the gap between "I understand the concept" and "I can write the
code without getting overwhelmed". Don't assume my level. Find it in the scope step.
Once the basics are in place, focus on API behavior, edge cases, and deciding rules
before coding.

## 1. Scope first (in chat, before writing anything)

- Ask what I'm about to build with this topic.
- Ask 2–3 short check questions to find my level. "I don't know" is a valid answer;
  this is a placement check, not a test.
- If the basics are missing, start the outline with foundations lessons: concepts and
  small observe-it toy demos, no API traps yet.
- Propose a short outline: lessons of about one sitting each. Keep it small.
- Wait for my OK.

## 2. Each lesson (saved to `docs/design/learn/<topic>/NN-<name>.md`)

1. **Mental model:** what the OS or library actually does underneath.
2. **API map:** the functions involved, what each follows or doesn't, how each reports
   errors, and the known traps. Verify behavior by experiment in the scratchpad.
   Cite cppreference or man pages.
3. **Failure-mode table:** every case that can happen, and the sensible response.
4. **Exercises:** 2–4 small tasks, unrelated to mdot's code, that I solve in
   `learn/<topic>/`. Never write solutions.
5. **Bridge to mdot:** which part of mdot this applies to, and a prompt for me to write
   my own "rules" for that function before coding.

In foundations lessons, the failure-mode table and the bridge to mdot can be light or
skipped.

Code blocks in lessons are toy examples only (see CLAUDE.md rule 2).

## 3. Exercises and review

Review my solutions with the hint ladder from CLAUDE.md. Move to the next lesson only
when I say so.
