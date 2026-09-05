---
name: coding-web
description: |
  House rules for HTML and CSS: unless told otherwise, use the newest
  platform feature that works across the major browsers, and prefer what
  the browser gives you over a custom or library replacement. Invoke
  whenever you touch an .html or .css file or write markup and styles
  inside another file, alongside the coding skill.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Coding: HTML and CSS

The `coding` skill carries the language-agnostic rules. This one is markup
and styles only. It is short on purpose; it grows when a rule earns its
place.

- **Newest broadly supported feature wins.** Unless the user specifies
  otherwise, do whatever the task needs with the latest platform technology
  that the major browsers all support. Container queries over media-query
  workarounds, native nesting over a preprocessor, `dialog` and `popover`
  over a hand-rolled modal, and so on. Check support before assuming; a
  feature shipped in one engine is not "available".
- **Built-in over custom.** When the browser has a control, element,
  attribute or CSS feature for it, use that before writing or importing a
  replacement. A native `select`, `details`, `input type="date"`, form
  validation, `scroll-snap`, view transitions. Custom is for when the
  built-in genuinely cannot do the job, and the reason goes in a comment.
