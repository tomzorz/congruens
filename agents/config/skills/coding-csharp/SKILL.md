---
name: coding-csharp
description: |
  House style and ship checklist for C# and .NET: ternary over if-else,
  same-line single statements or Allman braces, strong types, real
  exception handling, async over blocking, var rules, multi-line XML doc
  summaries, inheritdoc only where there is a parent. Invoke whenever you
  touch a .cs, .csproj or .sln file, alongside the coding skill.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Coding: C#

The `coding` skill carries the language-agnostic rules. This one is C# and
.NET only.

## Style

- **Ternary over if-else.** Prefer `? :` over declaring a variable and
  assigning it in branches. If the ternary becomes unreadable (deeply
  nested, very long), break it across lines or fall back to if-else.
  ```csharp
  // Good
  var label = isActive ? "Active" : "Inactive";

  // Bad: an if-else for a simple assignment
  string label;
  if (isActive)
      label = "Active";
  else
      label = "Inactive";
  ```
- **Brace style.** A single-statement branch (if, else, for, foreach, and
  the rest) goes on the same line with no braces. A body on its own line
  always has braces, Allman style. Never a bare statement on its own line.
  ```csharp
  // Good: single statement, same line, no braces
  if (condition) return value;
  foreach (var item in items) Process(item);

  // Good: multi-line body, braces, Allman
  if (condition)
  {
      DoFirstThing();
      DoSecondThing();
  }

  // Bad: dangling statement
  if (condition)
      DoSomething();
  ```
- Prefer strong types over strings. Enums and records when the domain is
  closed or needs validation.
- Handle exceptions properly. Never swallow one without logging or
  rethrowing.
- `async`/`await` over blocking calls. No `.Result`, no `.Wait()`.
- `var` when the type is obvious from the right-hand side; an explicit type
  when it aids readability.
- **XML doc style.** Multi-line `<summary>` with the opening and closing
  tags on their own lines. Never a single-line `<summary>Text</summary>`.
  ```csharp
  // Good
  /// <summary>
  /// Registers all platform services. Call this once from Program.cs.
  /// </summary>
  public static void AddPlatformServices(this IServiceCollection services)

  // Bad
  /// <summary>Registers all platform services.</summary>
  public static void AddPlatformServices(this IServiceCollection services)
  ```
- **`<inheritdoc />`** only on members that override a base class member or
  implement an interface member. Never on constructors or on methods with
  no parent definition to inherit from.

## Before shipping

1. `dotnet format`
2. `dotnet build --warnaserror`, and address every warning.
3. The relevant `dotnet test`, covering unit and end-to-end paths.
