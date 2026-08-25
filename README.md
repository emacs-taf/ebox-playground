# ebox-playground

`ebox-playground` is the independent, generic file runner for Ebox DSL examples. It uses only public Ebox APIs; concrete layouts live in readable `.ebox` fixtures under `examples/`. The migrated low-level fixtures include the original Basic, Comprehensive, Flex, and Responsive references, while `grid-reference.ebox` provides a complete public Grid property/value gallery with the same restrained terracotta, sage, blue, violet, ochre, and teal visual language.

ECSS 0.1.0 and TP 1.0.0 are independent packages and may be installed in either order. Install both before Ebox 2.0.0, then install this package. `ebox-playground` never reaches into those packages' private APIs.

Standalone gallery entry points default to a definite 720 px canvas so nested examples have stable space in batch renders and one-window demos. Split-window `.ebox` previews instead bind `(viewport)` to the preview window's display-safe width, so viewport-based separators and sections fit the right-hand pane. `etaf-playground` remains the separate higher-level Component and Runtime showcase.

Standalone and batch fixture renders use the same compact 720 px default viewport unless the caller dynamically binds `ebox-viewport-width`; viewport-based references therefore stay inside the example canvas. When `C-c C-c` renders an `.ebox` source buffer, the command keeps the source on the left, opens the preview on the right, and binds `(viewport)` to Ebox's shared display-safe window width. Continuous window changes are coalesced by Ebox's single viewport controller; the Playground owns no second resize hook or timer.

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

The package also owns the `.ebox` file boundary. Visiting an Ebox DSL file selects `ebox-dsl-mode`; its header line shows `C-c C-c Render preview`. Press `C-c C-c` to build the single DSL form, render it through the public Ebox API, and automatically display the source and preview side by side.

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))
```

The reference fixtures live directly under `examples/`. For example:

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/grid-reference.ebox"
                   ebox-playground-directory))
```

Run `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` from this directory.
