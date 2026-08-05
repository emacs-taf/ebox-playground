# ebox-playground

`ebox-playground` is the independent, generic file runner for Ebox DSL examples. It uses only public Ebox APIs; concrete layouts live in readable `.ebox` fixtures under `examples/`. The migrated low-level fixtures include the original Basic, Comprehensive, Flex, and Responsive references, while `grid-reference.ebox` provides a complete Grid property gallery with the same restrained terracotta, sage, blue, violet, ochre, and teal visual language.

The gallery owns one definite 720 px canvas so its nested Grid examples cannot each reinterpret the surrounding viewport width. It fits a compact GUI Emacs window with at least 760 px of body width. `etaf-playground` remains the separate higher-level Component and Runtime showcase.

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

The package also owns the `.ebox` file boundary. Visiting an Ebox DSL file selects `ebox-dsl-mode`; press `C-c C-c` to build the single DSL form and render a preview through the public Ebox API.

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
