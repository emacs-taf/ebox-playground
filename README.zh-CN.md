# ebox-playground

`ebox-playground` 是 Ebox 的独立开发示例包，只使用 Ebox 公共构造函数，并通过一套精心设计的三段式画廊展示固定与分数轨道、显式 Grid 放置，以及公开的 Column/Flex/Grid 组合能力。克制的陶土色、鼠尾草绿、蓝色与紫色配色延续了原 Flex 参考示例的视觉标准，同时不依赖特定主题 face。

画廊统一拥有一个明确的 720 px 画布，因此嵌套 Grid 不会各自重新解释外层视口宽度。只要 GUI Emacs 的正文区域不小于 760 px，它就能完整显示。高层 Component/Runtime 展示仍由独立的 `etaf-playground` 提供。

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

在该目录运行 `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`。
