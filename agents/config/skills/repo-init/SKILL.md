---
name: repo-init
description: |
  Set up a new repository the archetype way, or add a project to one that
  already exists. Use when starting a new repo or project, scaffolding a
  project structure, asking what folders a repo should have, wiring up
  .gitignore / .gitattributes / git-lfs for a fresh checkout, or when the
  user mentions archetype. Follows github.com/tomzorz/archetype, which is
  the source of truth: fetch the templates from there, never retype them.
author: congruens
version: 1.1.0
date: 2026-08-22
---

# Repo Init

Every repository gets the same core: a `sources/` folder with one folder per project, a root ignore file, a root attributes file with git-lfs wired up, and one ignore file per project. Everything else is conditional and waits for its trigger. That skeleton lives at <https://github.com/tomzorz/archetype> and this skill is how you apply it.

The thing to internalise: archetype is not a checklist to run to completion. Scaffolding a folder nobody needed yet is a cost, not a courtesy.

The templates are the source of truth. You fetch them, you do not reproduce them from memory. A gitignore you typed out yourself is a gitignore that silently drifts from every other repo.

## When to use this skill

- A new repository is being created, whether or not the word "archetype" comes up.
- A new project is being added inside an existing repo's `sources/` folder and needs its own ignore file.
- An existing repo is missing the skeleton and should be brought in line.
- Someone asks where the docs, sample data, or design files should go in a repo.

Do not use it to restructure a repo that already has a working layout of its own. Archetype is the default for greenfield work, not a conversion mandate.

## What archetype prescribes

### Core, in every repository

- `sources/`, with a folder per project, even when there is only one project. The nesting fights what `dotnet new`, `npm init`, `cargo new` and `uv init` produce, and it stays anyway: projects grow sidecars, and moving an established project into `sources/` later churns every path, script and CI reference in the repo.
- The repo-root gitignore, in the root.
- The gitattributes file with git-lfs, in the root. This is core even when the repo is nothing but code. It is inert when nothing matches it, and it is the one element you cannot add retroactively, because the fix after a large binary lands in the history is a history rewrite.
- One gitignore per project folder, matching that project's stack.

### Conditional, each on its own trigger

| Folder | Trigger |
|---|---|
| `media` | The repo holds source assets the build does not produce and that you edit elsewhere: the `.psd` for the logo, the `.flp` for the menu music. Not conditional for Unity, which has source art by definition. |
| `docs` | There is a document that is not the README, or more than one of them. Specs, install guides, third party API dumps. |
| `data` | Sample or fixture files are needed to run the project, and they are shared between projects or too big or awkward to sit next to the tests. Fixtures that belong beside their tests stay beside their tests. |
| `submodules` | Someone runs `git submodule add`. Nothing to anticipate. |
| `.agents` | Agents work in this repository. Holds `napkin.md`, `sticky-notes/` and `assumptions/`, and gets committed, because the point of the napkin is that the next session reads it. |

The reasoning behind the first four is the same: keep the repo root readable, keep raw assets out of the build tree (Unity in particular will generate `.meta` files for anything it can see), and give everyone one obvious place to look. `media` was called `assets` once; it got renamed so it stops colliding with Unity's `Assets`.

Do not create a conditional folder speculatively, and do not create placeholder files to hold an empty folder open. A folder that needs a `remove_when_something_is_here` file to justify itself was premature. Create it on the day its trigger fires, when there is real content to put in it.

## Fetching the templates

Pull them from the `main` branch of archetype:

| File | URL |
|---|---|
| repo-root ignore | `https://raw.githubusercontent.com/tomzorz/archetype/main/gitignores/repo-root/.gitignore` |
| attributes (git-lfs) | `https://raw.githubusercontent.com/tomzorz/archetype/main/gitattributes/.gitattributes` |
| Visual Studio / .NET | `https://raw.githubusercontent.com/tomzorz/archetype/main/gitignores/visualstudio/.gitignore` |
| Unity | `https://raw.githubusercontent.com/tomzorz/archetype/main/gitignores/unity/.gitignore` |
| Python | `https://raw.githubusercontent.com/tomzorz/archetype/main/gitignores/python/.gitignore` |
| JavaScript / TypeScript | `https://raw.githubusercontent.com/tomzorz/archetype/main/gitignores/javascript/.gitignore` |

Check the response actually looks like a gitignore before writing it anywhere. A 404 page saved as `.gitignore` fails quietly and nobody notices until something secret gets committed.

If there is no network, look for a local checkout of archetype under the user's project roots, or ask where it is. Do not fall back to writing an ignore file from memory, and do not fall back to a generic one off the internet. Say the fetch failed and stop.

If a template turns out to be missing something while you are using it, that is a change to archetype, not a local edit. Fix it upstream so every future repo gets it, then use the fixed version here.

## Procedure

1. **Establish the shape.** Repo name, where it goes on disk, and which stacks live in it. A repo can hold more than one project, so ask for the list, not just one answer. Ask what else the repo will hold besides code, since that is what decides the conditional folders, and it is one question rather than five. If the answer is obvious from context, say what you assumed and move on.

2. **Check the global gitignore.** Run `git config --get core.excludesfile` and look at what is in it. The recommendation is an empty global ignore, with everything handled per repository. The classic bite: global ignores usually carry a catch-all for `*.dll`, and Unity repos need checked-in DLLs (NuGet libraries get copied in by hand, and Asset Store packages ship DLLs). The build breaks and the diff looks clean. If the global file has content, tell the user what is in it rather than silently editing it.

3. **Init the repo.** `git init` if it is not a repo yet. Skip if it already is.

4. **Create `sources/` and a folder in it per project.** That is the only folder that gets created up front, and it never needs a placeholder because a project folder goes straight into it. Create a conditional folder only when its trigger has already fired, meaning there is content ready to go in it today.

5. **Place the root files.** The repo-root ignore and the attributes file, both in the repository root.

6. **Turn on git-lfs.** The attributes file routes models, audio, fonts, images, and documents through LFS, and it does nothing at all unless LFS is installed. Run `git lfs install`, and tell the user that clones of this repo need LFS checkout enabled. This is the step people forget, and the failure mode is pointer files where binaries should be.

7. **Add the project ignores.** One folder per project inside `sources/`, each with the ignore file for its stack. Do not try to merge two stacks into one file. Unity and Visual Studio contradict each other directly: Unity depends on `.meta` files, and nearly every Visual Studio ignore deletes them.

8. **Apply the per-stack extras.** For Unity, create `Assets/_project` and put all first party content there, so no third party package that expects to sit in the Assets root can collide with it, and so it sorts first in the Project window.

9. **Report and stop.** List what you created, and list the conditional folders you did not create along with the trigger that would bring each one in. That list is the useful half of the report: it tells the next person what to do when the first `.psd` or the first spec shows up. Do not commit or push unless asked; the commit-message skill applies when you are.

## Conventions worth carrying over

- Prefix a project name with `Ω` (ohm sign) when you want it sorted last on every system. Used for client work on personal Azure DevOps, in the shape `Ω ClientName - ProjectTitle`.
- Don't break the build.

## Stay in scope

Archetype covers the skeleton and nothing else. Do not invent a README, a license, a CI workflow or an editor config as part of initializing a repo. If the user wants those, they will say so, and each one is its own decision.

The `.agents` folder is the one exception, and only as far as archetype defines it: the folder itself, once agents are actually working in the repo. Writing an `AGENTS.md` or seeding napkin content is a separate decision and not part of init.

Conditional elements cut both ways. Skipping a folder that has no content yet is correct, and so is creating one the moment its trigger fires. Do not talk someone out of a `docs/` folder when they have a spec in hand.
