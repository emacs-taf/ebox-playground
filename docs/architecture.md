# Ebox Playground architecture

## Ownership

`ebox-playground.el` is the file runner and preview integration. Ebox owns DSL
parsing, layout, retained rendering, scrolling and native interaction. The
playground calls public Ebox APIs; it does not implement another renderer,
selector engine or viewport controller.

## Source and lifecycle

`examples/` contains `.ebox` layouts and same-basename `.el` companions for
interactive behavior. A preview loads its companion and builds the declared
layout. Each preview owns its own interaction state. Reopening or resizing a
preview must preserve the public Ebox mount and teardown contracts.

The examples cover flex, grid, explicit units, cascade, interaction and layers.
`desktop-reference.ebox` is an Ebox-only gesture and overlap fixture: it
demonstrates how a companion can use Ebox's public keymap and node update
APIs, but it is not a desktop manager or reusable framework service.
Application-level registration, workspaces and window policy belong to the
higher-level `etaf-desktop` package. These examples are executable acceptance
inputs, not screenshots standing in for running behavior. Product usage and
entry points are in the [README](../README.md).

## Validation

`tests/acceptance.json` selects rendered output, cascade, interaction, preview
isolation and resize behavior. `make check` runs these scenarios after compilation.
`make test` runs broader regressions. `benchmarks/` owns performance workloads;
GUI appearance requires inspection of actual Emacs output under recorded fonts
and window dimensions. Batch success alone does not certify appearance.

Keep new layouts in `examples/`; extend the generic runner only when the same
capability is needed by more than one layout. Application components and data
controllers belong to the higher-level ETAF packages.
