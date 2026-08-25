# ebox-playground

`ebox-playground` 是 Ebox DSL 的独立通用文件运行器，只使用 Ebox 公共 API；具体布局都放在 `examples/` 下易读的 `.ebox` fixture 中。迁移后的低层 fixture 包含原有的 Basic、Comprehensive、Flex 和 Responsive 参考；`grid-reference.ebox` 则用同一套克制的陶土色、鼠尾草绿、蓝色、赭石色和青绿色视觉语言，完整展示 Grid 公共属性及其值形式。

ECSS 0.1.0 与 TP 1.0.0 是互相独立的包，安装顺序任意；两者都安装后再安装 Ebox 2.0.0，最后安装本包。`ebox-playground` 不调用这些依赖的私有 API。

独立画廊入口默认使用明确的 720 px 画布，因此 batch 渲染和单窗口演示里的嵌套示例有稳定空间。分屏 `.ebox` 预览则会把 `(viewport)` 绑定为右侧预览窗口的显示安全宽度，所以依赖 viewport 的分隔条和区块会适配右侧窗格。高层 Component/Runtime 展示仍由独立的 `etaf-playground` 提供。

独立和 batch fixture 渲染默认也使用紧凑的 720 px 视口；如果调用方动态绑定了 `ebox-viewport-width`，则保留调用方的值。因此依赖 viewport 的参考例子也会保持在示例画布内。通过 `C-c C-c` 渲染 `.ebox` 源文件时，命令会把源文件保留在左侧、在右侧打开预览，并将 `(viewport)` 绑定为 Ebox 统一计算的显示安全宽度；Ebox 唯一且串行的 viewport controller 会立即通过 retained 路径发布每次 window-size 变化，Playground 不再拥有第二套 resize hook 或 timer。

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

这个包也拥有 `.ebox` 文件入口。访问 Ebox DSL 文件时会自动进入 `ebox-dsl-mode`，header line 会显示 `C-c C-c Render preview`；按 `C-c C-c` 会通过 Ebox 公开 API 构建单个 DSL form、渲染并自动并排显示源文件和预览 buffer。

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))
```

参考 fixture 直接位于 `examples/` 下。例如：

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/grid-reference.ebox"
                   ebox-playground-directory))
```

在该目录运行 `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`。
