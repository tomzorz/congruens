---
name: intent-driven-ui
description: |
  Framework-agnostic tenets for naming and structuring UI components, styles,
  and design variables. Applies to XAML, React, Svelte, Vue, SwiftUI, Compose,
  CSS, or any component-based UI. Use when creating or reviewing UI components,
  styles, design tokens, or resource dictionaries. Core rules: name by intent
  not by value, one purpose per component, components own their look but never
  their position, and dedicated layout elements do all positioning.
author: congruens
version: 1.0.0
date: 2026-07-15
---

# Intent-Driven UI

You apply these tenets whenever you create, name, or review UI components,
styles, design tokens, resources, or variables — regardless of the framework
(XAML, React, Svelte, Vue, SwiftUI, Jetpack Compose, plain CSS, etc.).

## Tenet 1: Name by intent, not by value

A name must say what something is **for** — where and why it should be used —
never what it currently **does** or **is**.

Names that describe values are an anti-pattern:

| Bad (describes the value)    | Good (describes the intent)     |
|------------------------------|---------------------------------|
| `Thickness20`                | `StandardPageContentsMargin`    |
| `blue500`, `colorBlue`       | `primaryActionColor`            |
| `font14Bold`                 | `sectionHeadingFont`            |
| `gap8`                       | `formFieldSpacing`              |
| `AddTwentyPercent()`         | `AddTaxToPrice()`               |
| `RoundedCorners8`            | `CardCornerRadius`              |

Why this matters:

- When the design changes, an intent-named token changes **in one place** with
  no renaming and no risk to unrelated usages.
- A value-named token that changes value becomes a lie (`Thickness20` that is
  now 24), or forces a review of every usage to split it.
- Intent names make misuse visible: using `CardCornerRadius` on a dialog is
  obviously wrong; using `RoundedCorners8` is not.

Consequences you must accept and not "fix":

- **Duplicate values with different names are correct.** If the card margin
  and the page margin are both 20 today, define two tokens. They coincide;
  they are not the same thing. Never consolidate tokens just because their
  values match.
- Base/primitive palettes (e.g. a raw color scale) may exist, but only
  intent-named semantic tokens may be referenced from components. Primitives
  feed semantic tokens; nothing else reads them directly.

## Tenet 2: One component, one purpose, own default style

Each functional component has exactly **one specific function**, and it loads
its own designated default style without the consumer having to wire it up.

- A component's name states its purpose (`SubmitOrderButton`,
  `UserAvatarBadge`), not its appearance (`BigGreenButton`, `RoundImage`).
- The component is responsible for applying its default style itself:
  - XAML: `DefaultStyleKey` / implicit style in the control's resource
    dictionary.
  - React/Svelte/Vue: the component imports its own stylesheet / CSS module /
    scoped styles; consumers never import a component's CSS separately.
  - SwiftUI/Compose: default modifiers/theme values baked into the component.
- If a component needs two visual variants for two different purposes, that is
  usually two components (or an intent-named variant: `variant="destructive"`,
  not `variant="red"`).
- Do not create generic "do-everything" components configured entirely through
  props/parameters; split by purpose instead.

## Tenet 3: Components own their look, never their position

A functional component may define everything about its **internal**
appearance: colors, typography, internal padding, corner radius, internal
spacing between its own children.

A functional component must never define its **external** placement:

- No outer margins.
- No alignment relative to siblings (`align-self`, `Grid.Row`,
  `HorizontalAlignment` on its own root for placement purposes).
- No absolute positioning of itself.
- No flex/grid item properties on itself (`flex-grow`, `order`,
  `grid-column`) — those belong to the parent layout.
- Width/height: intrinsic sizing (content-driven, min/max constraints for its
  own integrity) is the component's business; stretching or filling assigned
  space is the parent's.

Rule of thumb: **padding is the component's; margin is the parent's.**
A component dropped into any container must look right without leaking
spacing or alignment assumptions into that container.

## Tenet 4: Dedicated layout elements do the positioning

Positioning is done by separate, purpose-built layout elements — never by the
functional components they arrange.

- XAML: `Grid`, `StackPanel`, `WrapPanel`, or purpose-named layout styles
  (`SettingsPageLayout`).
- React/Svelte/Vue: layout components (`<PageLayout>`, `<FormRow>`,
  `<CardGrid>`) or layout-only wrapper elements with the flex/grid rules.
- SwiftUI/Compose: `VStack`/`HStack`/`Grid`, `Column`/`Row`/`Box`.

Rules:

- Layout elements are named by intent too: `CheckoutFormLayout`, not
  `FlexColumnGap16`.
- Layout elements own margins, gaps between children, alignment, ordering,
  and responsive re-flow.
- Layout elements have **no visual identity of their own** (no borders,
  backgrounds, or typography) — if a wrapper needs a look, that look belongs
  to a functional component.
- Prefer parent-driven spacing (`gap`, `spacing`, `RowSpacing`) over child
  margins, so children stay position-agnostic.

## Review checklist

When writing or reviewing UI code, check:

1. Does every style/token/resource name state where and why it's used, rather
   than its value? Would the name survive the value changing?
2. Does each component do exactly one thing, with its purpose in its name?
3. Does each component load its own default style, with no styling burden on
   the consumer?
4. Does any component set its own margin, alignment, or grid/flex-item
   placement? Move it to the parent layout.
5. Is all positioning done by dedicated, intent-named layout elements with no
   visual styling of their own?
6. Were any tokens merged just because values coincided? Split them back.

When you find violations, fix them (or flag them in review) with a short note
naming the tenet, e.g. "names the value, not the intent" or "component
positions itself — lift the margin into the parent layout".
