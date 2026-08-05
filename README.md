# ebox-playground

`ebox-playground` is the independent, generic file runner for Ebox DSL examples. It uses only public Ebox APIs; concrete layouts live in readable `.ebox` fixtures under `examples/`. The maintained gallery demonstrates fixed and fractional tracks, explicit Grid placement, and public Column/Flex/Grid composition with a restrained terracotta, sage, blue, and violet palette.

The gallery owns one definite 720 px canvas so its nested Grid examples cannot each reinterpret the surrounding viewport width. It fits a compact GUI Emacs window with at least 760 px of body width. `etaf-playground` remains the separate higher-level Component and Runtime showcase.

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

The package also owns the `.ebox` file boundary. Visiting an Ebox DSL file selects `ebox-dsl-mode`; press `C-c C-c` to build the single DSL form and render a preview through the public Ebox API.

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))
```

Run `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` from this directory.
