# Ebox Playground 示例

此目录下的 `.ebox` 文件是通用 `ebox-playground` 运行器读取的具体布局。它们保持为普通、可读、可被 reader 读取的 Ebox DSL form，便于直接复制、编辑和打开。

文件本身就是 data form：结构表单保持不加 quote；list 和 symbol 类型的字面量属性值要和 `etaf-view` 一样加 quote，例如 `:gap '(1 (16))`、`:justify-content 'center`。未加 quote 的属性值会被运行器当作可执行的 Elisp 表达式求值；读取器本身仍然关闭 reader 求值。

`public-layout-gallery.ebox` 是 `M-x ebox-playground-open` 使用的默认 fixture。迁移来的低层参考和它并列放在 `examples/` 下：`basic.ebox`、`comprehensive.ebox`、`flex-reference.ebox`、`responsive-reference.ebox` 和 `grid-reference.ebox`。Flex 参考由根部 `:overflow 'scroll` 盒子拥有文档 viewport：键盘逐行作用于光标所在的最内层滚动 owner，鼠标滚轮按指针位置路由，剩余滚动量沿嵌套 owner 向外冒泡，最后才交给普通 buffer；splitter resize 时仍保持原有的完整内容语义。Grid 参考是完整的公共属性/值画廊：轨道模板（`auto`、`NFR`、`(fr FACTOR)`、`minmax`、`repeat`）、隐式轨道、row/column auto-flow、gap 简写/长写/别名、placement 与 span，以及所有受支持的 item/content 对齐值；同时注明 Ebox 支持 `row` 和 `column` auto-flow，不支持浏览器的 `dense` 变体。要渲染其他 fixture，可以访问该文件后按 `C-c C-c`，或调用 `ebox-playground-open-file`。
