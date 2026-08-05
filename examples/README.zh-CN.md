# Ebox Playground 示例

此目录下的 `.ebox` 文件是通用 `ebox-playground` 运行器读取的具体布局。它们保持为普通、可读、可被 reader 读取的 Ebox DSL form，便于直接复制、编辑和打开。

文件本身就是 data form：结构表单保持不加 quote；list 和 symbol 类型的字面量属性值要和 `etaf-view` 一样加 quote，例如 `:gap '(1 (16))`、`:justify-content 'center`。未加 quote 的属性值会被运行器当作可执行的 Elisp 表达式求值；读取器本身仍然关闭 reader 求值。

`public-layout-gallery.ebox` 是 `M-x ebox-playground-open` 使用的默认 fixture。迁移来的低层参考和它并列放在 `examples/` 下：`basic.ebox`、`comprehensive.ebox`、`flex-reference.ebox`、`responsive-reference.ebox` 和 `grid-reference.ebox`。其中 Grid 参考覆盖轨道模板、隐式轨道、auto-flow、gap、placement、span、item 对齐和 content 对齐。要渲染其他 fixture，可以访问该文件后按 `C-c C-c`，或调用 `ebox-playground-open-file`。
