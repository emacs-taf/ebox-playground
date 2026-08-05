# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-08-05
- Primary product surfaces: The `.ebox` files under `examples/`, the buffer opened by `ebox-playground-open`, and the generic file mode.
- Evidence reviewed: `ebox-playground.el`, `examples/public-layout-gallery.ebox`, `tests/ebox-playground-tests.el`, `README.md`, `README.zh-CN.md`, and the rendered current example.

## Brand
- Personality: Precise, modern, restrained, and educational.
- Trust signals: Pixel-aligned sections, exact Grid placement, explicit text contrast, public-only construction, and a layout that remains legible without theme-specific faces.
- Avoid: Bare unstyled fixture text, low-contrast pastel typography, arbitrary rainbow colors, oversized blank canvas, and private diagnostic internals.

## Product goals
- Goals: Demonstrate Ebox Grid and composition in a polished standalone example; give the low-level package a visual quality bar consistent with the Flex reference.
- Non-goals: ETAF Components, application state, browser imitation, or a second Playground framework.
- Success signals: The first frame clearly communicates hierarchy and Grid behavior; every tinted block has readable text; no content crosses the visible viewport.

## Personas and jobs
- Primary personas: Ebox authors and maintainers.
- User jobs: Open one buffer, understand the public node contract, and see fixed/fractional tracks, placement, and composition rendered attractively.
- Key contexts of use: GUI Emacs, fullscreen demonstrations, and ERT rendering checks.

## Information architecture
- Primary navigation: None; this is one self-contained reference surface.
- Core routes/screens: One header and three capability sections.
- Content hierarchy: Title and description, labeled capability bands, then small contrasting examples.

## Design principles
- Principle 1: Mirror the Flex reference's title—explanation—example rhythm.
- Principle 2: Use one restrained semantic accent per capability section.
- Principle 3: Keep the runner generic; put each concrete layout in a readable `.ebox` source file.
- Tradeoffs: Prefer a compact representative gallery over exhaustive property coverage.

## Visual language
- Color: Warm paper canvas with terracotta, sage, slate blue, and violet section families; explicit dark ink or white text according to contrast.
- Typography: Configured monospace, bold only for titles and short labels.
- Spacing/layout rhythm: One-line vertical gaps, 12 px horizontal gaps, 16–24 px section padding.
- Shape/radius/elevation: Square one-pixel borders; no shadows or fake radius.
- Motion: None.
- Imagery/iconography: Text-only.

## Components
- Existing components to reuse: `ebox-create`, `ebox-column`, `ebox-row`, `ebox-flex`, `ebox-grid`, and `ebox-spacer`.
- New/changed components: Header band, capability section band, fixed/fractional track cards, placement cards, and public-contract footer.
- Variants and states: Static semantic color families only.
- Token/component ownership: Palette values and example composition live in `.ebox` fixtures; the runner owns only parsing and rendering.

## Accessibility
- Target standard: High contrast and readable labels in ordinary GUI Emacs themes.
- Keyboard/focus behavior: No interactive controls in this static example.
- Contrast/readability: Explicit foreground on every tinted surface.
- Screen-reader semantics: Plain descriptive text remains present in the buffer.
- Reduced motion and sensory considerations: No motion.

## Responsive behavior
- Supported breakpoints/devices: GUI Emacs windows with at least 760 px of body width, from compact frames to fullscreen desktop widths.
- Layout adaptations: The gallery owns one fixed 720 px content canvas; nested Grid and Flex sections divide that width through public Ebox layout behavior instead of reading the viewport independently.
- Touch/hover differences: None.

## Interaction states
- Loading: Not applicable.
- Empty: Not applicable.
- Error: Public Ebox errors surface normally.
- Success: The rendered gallery itself is the success state.
- Disabled: Not applicable.
- Offline/slow network, if applicable: Not applicable.

## Content voice
- Tone: Concise, factual, and self-explaining.
- Terminology: Ebox, node, Grid, fixed track, fractional track, placement, public API.
- Microcopy rules: Explain what a visible section proves in one sentence.

## Implementation constraints
- Framework/styling system: Emacs 29.1+ and public Ebox constructors/properties only.
- Design-token constraints: Reuse the Flex reference's restrained color families without introducing a theme package.
- Performance constraints: One synchronous render, no timers or background work.
- Compatibility constraints: No ETAF dependency and no `ebox--*` calls.
- Test/screenshot expectations: `make check` passes and a fullscreen one-window screenshot shows complete, unclipped labeled sections.

## Open questions
- [ ] Add more standalone `.ebox` fixtures only when each teaches a distinct public Ebox responsibility / maintainer / prevents fixture sprawl.
