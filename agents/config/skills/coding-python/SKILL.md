---
name: coding-python
description: |
  House rules for Python: uv and pyproject.toml in every repo, no pip
  venvs, Poetry or requirements.txt unless asked, type hints everywhere,
  explicit models over loose dicts. Invoke whenever you touch a .py file
  or a pyproject.toml, alongside the coding skill.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Coding: Python

The `coding` skill carries the language-agnostic rules. This one is Python
only.

- **Repo standard.** `uv` and `pyproject.toml` in every Python repo. `uv
  sync` for the environment and dependency resolution. Do not introduce
  `pip` venvs, Poetry, or `requirements.txt` unless asked. If you add a Nix
  shell, include `uv` in it.
- Strong types. Type hints everywhere, and explicit models instead of loose
  dicts or strings.
