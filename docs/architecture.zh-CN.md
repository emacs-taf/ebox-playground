# Ebox Playground 架构

## 职责

`ebox-playground.el` 负责文件运行和预览接入。DSL 解析、布局、保留式渲染、滚动及
原生交互由 Ebox 负责。Playground 只调用公共 API，不再实现渲染器、选择器或 viewport 控制器。

## 源文件与生命周期

`examples/` 保存 `.ebox` 布局和同名 `.el` 交互逻辑。预览先加载伴随文件，再构建
声明的布局；不同预览具有独立交互状态。重新打开、调整大小和关闭预览都遵循 Ebox 的
公共挂载与清理契约。

示例涵盖 flex、grid、显式单位、cascade、交互、图层，是可执行验收输入。
使用方式及入口见 [README](../README.zh-CN.md)。

## 验证

`tests/acceptance.json` 选择渲染输出、cascade、交互、预览隔离及 resize 场景。
`make check` 编译后运行这些验收；`make test` 提供更广泛的回归。
性能工作负载放在 `benchmarks/`。GUI 外观必须结合实际 Emacs 输出、字体和窗口尺寸检查，
批处理通过不等于视觉验收完成。

新增布局放入 `examples/`，只有多种布局共同需要的能力才进入通用运行器。
应用组件与数据控制器属于上层 ETAF 包。
