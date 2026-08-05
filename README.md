# ebox-playground

`ebox-playground` is the independent developer example package for Ebox. It uses only public Ebox constructors and presents a polished three-part gallery for fixed and fractional tracks, explicit Grid placement, and public Column/Flex/Grid composition. Its restrained terracotta, sage, blue, and violet palette follows the visual standard of the original Flex reference without depending on theme-specific faces.

The gallery owns one definite 720 px canvas so its nested Grid examples cannot each reinterpret the surrounding viewport width. It fits a compact GUI Emacs window with at least 760 px of body width. `etaf-playground` remains the separate higher-level Component and Runtime showcase.

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

Run `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` from this directory.
