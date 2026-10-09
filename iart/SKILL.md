---
name: iart
description: |
  "I ain't reading that." Summarize long text, files, links, or threads
  into a short, no-fluff briefing. Use when the user runs /iart or says
  "summarize this", "tldr", "what does this say", or drops a wall of text
  they clearly don't want to read end to end.
metadata:
  version: "1.0.0"
---

# IART: I Ain't Reading That

Compress whatever the user points at into the shortest accurate briefing you can write.

## Input

The user gives you one of:
- Pasted text (a long message, article, email thread, Slack dump, spec, RFC, diff, PR description)
- A file path
- A URL
- A conversation thread or document already in context

Read the full thing before summarizing. Do not skim.

## Output

1. **One sentence** that says what the thing is about and why someone would care.
2. **Key points** as a flat list, 3-7 items. Each item is one sentence. No sub-bullets, no headers, no bold labels.
3. If there are action items, deadlines, decisions, or open questions, list those separately under "Action items" or "Open questions" (whichever applies). Skip this section if there are none.

That's it. No intro, no "here's a summary of...", no closing line.

## Rules

- Preserve names, numbers, dates, and technical terms exactly.
- Do not editorialize, interpret, or add context the source does not contain.
- Do not pad. If the source can be summarized in two bullet points, use two.
- If the source is already short (under ~200 words), say so and give the one-sentence summary only.
- Match the register of the source. A casual Slack thread gets a casual summary. An RFC gets a dry one.
- Code diffs: say what changed and why (if stated), not line-by-line commentary.
