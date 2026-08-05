# ebox-playground

`ebox-playground` 是 Ebox DSL 的独立通用文件运行器，只使用 Ebox 公共 API；具体布局都放在 `examples/` 下易读的 `.ebox` fixture 中。维护中的画廊通过这些源文件展示固定与分数轨道、显式 Grid 放置，以及公开的 Column/Flex/Grid 组合能力，并使用克制的陶土色、鼠尾草绿、蓝色与紫色配色。

画廊统一拥有一个明确的 720 px 画布，因此嵌套 Grid 不会各自重新解释外层视口宽度。只要 GUI Emacs 的正文区域不小于 760 px，它就能完整显示。高层 Component/Runtime 展示仍由独立的 `etaf-playground` 提供。

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

这个包也拥有 `.ebox` 文件入口。访问 Ebox DSL 文件时会自动进入 `ebox-dsl-mode`；按 `C-c C-c` 会通过 Ebox 公开 API 构建单个 DSL form 并渲染预览。

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))
```

在该目录运行 `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`。
