# Ebox Playground examples

The `.ebox` files in this directory are the concrete layouts consumed by the generic `ebox-playground` runner. They are intentionally ordinary, reader-valid Ebox DSL forms so authors can copy, edit, and open them directly.

The file itself is the data form: structural forms stay unquoted, while literal list and symbol property values use quote just as they do in `etaf-view` (for example, `:gap '(1 (16))` and `:justify-content 'center`). An unquoted property value is an executable Elisp expression and is evaluated by the runner. The reader itself keeps read-time evaluation disabled.

`public-layout-gallery.ebox` is the default fixture used by `M-x ebox-playground-open`. The migrated low-level references live directly beside it: `basic.ebox`, `comprehensive.ebox`, `flex-reference.ebox`, `responsive-reference.ebox`, and `grid-reference.ebox`. The Grid reference covers track templates, implicit tracks, auto-flow, gaps, placement, spans, item alignment, and content alignment. To render another fixture, visit it and press `C-c C-c`, or call `ebox-playground-open-file`.
