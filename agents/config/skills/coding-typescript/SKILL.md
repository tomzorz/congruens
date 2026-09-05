---
name: coding-typescript
description: |
  House rules for TypeScript: no any, no as, model the real shapes, and
  assume modern browsers with no polyfills for browser apps. Invoke
  whenever you touch a .ts or .tsx file, alongside the coding skill.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Coding: TypeScript

The `coding` skill carries the language-agnostic rules. This one is
TypeScript only.

- No `any`. We are better than that.
- No `as`. Use the types you are given everywhere, and model the real
  shapes instead of asserting your way past them.
- For a browser app, assume all modern browsers unless told otherwise. Most
  polyfills are not needed.
