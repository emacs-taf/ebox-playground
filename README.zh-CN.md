# ebox-playground

`ebox-playground` 是 Ebox DSL 的独立通用文件运行器，只使用 Ebox 公共 API；具体布局都放在 `examples/` 下易读的 `.ebox` fixture 中。`flex-reference.ebox`、`grid-reference.ebox` 和 `size-reference.ebox` 用克制的陶土色、鼠尾草绿、蓝色、紫色、赭石色和青绿色视觉语言，展示布局与尺寸规则。`interaction-reference.ebox` 展示 Ebox 原生交互及 retained 更新。 `desktop-reference.ebox` 提供独立的 Ebox 文本窗口拖拽示例。

先安装 ECSS 0.1.0，再安装 Ebox 3.0.0，最后安装 Ebox Playground 0.1.1。`ebox-playground` 只使用 Ebox 公共接口。

独立画廊入口默认使用明确的 720 px 画布，因此 batch 渲染和单窗口演示里的嵌套示例有稳定空间。分屏 `.ebox` 预览则会将 `(vw 100)` 解析为右侧预览窗口的显示安全宽度。章节分隔条使用所在 Column 的可用宽度，因此根容器缩窄时也会跟随。高层 Component/Runtime 展示仍由独立的 `etaf-playground` 提供。

独立和 batch fixture 渲染默认也使用紧凑的 720 px 视口；如果调用方动态绑定了 `ebox-viewport-width`，则保留调用方的值。因此依赖 viewport 的参考例子也会保持在示例画布内。通过 `C-c C-c` 渲染 `.ebox` 源文件时，命令会把源文件保留在左侧、在右侧打开预览，并将 `(vw 100)` 解析为 Ebox 统一计算的显示安全宽度；Ebox 的 viewport controller 会在每次 window-size 变化时重新布局保留树，Playground 不再拥有第二套 resize hook 或 timer。

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

打开 `examples/size-reference.ebox`，按 `C-c C-c` 即可查看 **Ebox Size Reference**。
示例按允许的方向展示六种长度单位、六个尺寸约束属性支持的关键词、`calc/min/max/clamp`，以及字体、
间距、Flex、Grid 中的组合用法。调整预览宽度可以对照百分比和视口单位，并观察流式尺寸的变化。
精度和 buffer 渲染器的限制会直接标明，不把当前实现描述成与浏览器完全一致。
受限容器里的长文本用于区分内容宽度关键词，Row 对照用于区分 `auto` 和 `stretch`。
高度内容关键词会明确标注当前渲染器中的等效关系；`min`、`max`、`clamp` 使用相同的低、中、高输入展示边界变化。
实色矩形标明被测 Box 的完整范围（包含空白），浅色标尺表示父容器的可用宽度，白色卡片承载说明。

运行 `make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`，可检查核心尺寸契约、
示例的实际属性覆盖、已知计算结果、背景所指示的尺寸差异、完整渲染及保留状态的视口更新。`make check` 也包含此示例的回归测试。

## PARALLAX 可拖拽桌面

打开 `examples/desktop-reference.ebox`，按 `C-c C-c`，或执行：

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/desktop-reference.ebox"
                   ebox-playground-directory))
```

深蓝工作台中放置五个内容各异的窗口：Studio、Notes、Signal、Terminal、Palette。
点击露出的标题、正文或空白区域，会将整窗置顶；按住标题栏拖动时持续更新位置，
保留抓取偏移，松手时应用最终位置。窗口可以部分或完全覆盖其他窗口，原有内容始终保留。

底部五个窗口入口可以找回被完全遮住的窗口；**CYCLE** 将最下面的窗口放到最上面，
**RESET** 恢复原始位置和次序，也能找回拖出桌面裁剪边界的窗口。RET/SPC 激活当前
控件，标题或窗口入口上的 Alt+方向键移动对应窗口并支持连续按键；C-g 结束拖拽，
保留最后已接受的位置。每次打开的预览状态互相独立。

**LIGHT/DARK** 切换整套配色：五张卡片在亮色模式下都使用浅色底与深色文字，标题栏、
窗口入口、装饰图案、波形、色板和悬停颜色也同步适配。切换保留窗口位置与层次，
**RESET** 保留所选主题。每个新预览默认深色。

Desktop 中的鼠标点击与拖动不会选中文本，按钮之间、换行和缓冲区末尾也受保护。
这项策略只作用于 Desktop 预览，其他缓冲区和示例仍保留正常的鼠标行为。

横向按像素移动，纵向遵循 Ebox 的文本行网格。推荐至少 40 列、20 行，更大的预览
有更多摆放空间。所有文本保持当前字体大小，不使用额外字体或图片依赖。
Companion 使用 `ebox-keymap-create :drag`，由 Ebox 管理原生跟踪，示例只更新
面板位置。指针离开原文本窗口时，在最后已接受的位置结束手势。

运行 `make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`
检查公共文件渲染、viewport 行为、桌面中间移动和释放位置；
`make check` 已包含该套件。重复键盘移动的耗时由
[性能场景](#performance-scenarios) `ebox-playground.desktop.nudge` 测量。


## 图层与原生菜单示例

打开 `examples/layer-reference.ebox` 并按 `C-c C-c`，可查看 ORBIT 空间桌面、
保留内容的重叠面板及锚定菜单；`examples/layer-minimal.ebox` 保留最小重叠示例。
工具栏每个按钮支持点击、`RET` 和 `SPC`。悬停绘制仅覆盖按钮及其自身 padding，
按钮间隙和行内剩余空间保持不变；被覆盖笔记、根菜单选项等有意设置为块级交互的
区域仍保留自己的悬停绘制。

`layer-reference.ebox` 保存布局，`layer-reference.el` 保存业务状态与操作。它只使用
公共 `ebox-keymap-create`、`ebox-help-create`、`ebox-selector-query-buffer`、
`ebox-node-set-props` 和 `ebox-call-with-batch`：每个操作按 `:id` 找到节点，修改
其属性与状态文字，并在 batch 结束时只刷新一次，详见
[批量更新契约](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/incremental-updates-and-publication.md#批处理与-flush)。

运行 `make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`，
验证示例的原生命令：被覆盖笔记更新、面板显隐与卡片展开／收起，无需打开 GUI 窗口。
重复 EXPLODE STACK 的耗时由[性能场景](#performance-scenarios)
`ebox-playground.layer.explode` 测量。

<a id="native-interaction-lab"></a>
## 原生交互实验室

使用已有文件运行器打开交互参考：

```elisp
(require 'ebox-playground)
(ebox-playground-open-file
 (expand-file-name "examples/interaction-reference.ebox"
                   ebox-playground-directory))
```

也可以访问 `examples/interaction-reference.ebox` 后按 `C-c C-c`，并排显示源码和
预览。**Ebox Native Interaction Lab** 先分别展示帮助文字、指针形状与悬停绘制，
再通过实时计数器和事件日志组合 `:help-echo`、`:pointer`、`:hover-style` 与 `:keymap`。

- 悬停在带边框的卡片上（包括 padding），对比静态帮助、动态帮助、原生指针以及
  颜色和文本装饰变化。
- 点击 **ADD / [+]** 增加，点击独立的 **[-]** Text 减少；把 point 移到对应操作上
  使用 `RET` / `SPC`，也可以使用其 `+` / `-` 快捷键。
  **SWITCH STEP 1 / 5** 将其 keymap 替换为使用对应步长的命令。
- **SWITCH HOVER PALETTE** 替换悬停绘制；**REMOVE / RESTORE** 通过显式
  `nil` 清除四种能力，再恢复它们。Text 重置操作可以清零计数。
- **UPDATE STATUS GROUP** 通过一次 `ebox-selector-query-buffer` 类选择器查询，
  在同一 batch 中更新三个 `.demo-status` Box。
- 嵌套区域展示父节点覆盖、拥有独立命令的 Text 子节点，以及通过显式 `nil` 阻止
  外层能力覆盖的子节点。事件日志记录实际运行的命令。

Box 的帮助、指针和 keymap 范围包含内容、padding 和 border，不包含该 Box 自身的
margin 及结构性换行符。同一渲染行内，一个 hover owner 的文字与 padding 共享原生
`mouse-face`；未指定属性取自 owner 的基础样式，即使子文本的正常样式不同。
物理左右边框不参与悬停，水平边框线条保留自己的绘制。原生指针外观和帮助显示由
Emacs 设置及窗口系统决定，
见[公共能力契约](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/events.md#悬停反馈)。

`interaction-reference.el` 负责业务函数与状态，`interaction-reference.ebox` 负责
布局；运行器在每次预览前重新加载对应 `.el`。Ebox 的 `ebox-help-create` 提供原生
帮助适配，`ebox-keymap-create` 绑定
零参数回调，回调按 `:id` 找到节点并用 `ebox-node-set-props`、`ebox-node-set-text`
和 `ebox-node-replace-children` 更新；鼠标回调自动在事件窗口的
buffer 中运行。Ebox 不增加应用状态或焦点导航系统，使用键盘绑定时通过普通 point
移动定位。Keymap 会创建快照，安装新绑定需要替换 `:keymap`。每次求值都会创建
独立的新示例。

在本目录运行交互检查：

```sh
make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
```

该入口验证本示例的计数、事件日志、状态组以及绑定清除。
`make check` 也包含 Playground 交互回归测试。重复 ADD 的耗时由
[性能场景](#performance-scenarios) `ebox-playground.interaction.add` 测量。

## 编写和渲染 `.ebox` 文件

这个包也拥有 `.ebox` 文件入口。访问 Ebox DSL 文件时会自动进入 `ebox-playground-mode`，header line 会显示 `C-c C-c Render preview`；按 `C-c C-c` 会求值文件中的唯一一个 Elisp 表达式，将得到的布局数据传给 `ebox-build`，渲染并自动并排显示源文件和预览 buffer。

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-playground-mode))
```

`.ebox` 中写的表达式与 Elisp 中传给 `(ebox-build ...)` 的参数完全一致。
静态布局对整个列表加 quote，内部的 list 和 symbol 属性不再单独加 quote：

```elisp
'(column :padding ((lh 1) (ch 2))
         :cross-align center
         (box :width (px 240) "Hello"))
```

必要的业务函数与变量放在 `.ebox` 旁边可选的同名 `.el` 文件中。每次预览求值前，
运行器先加载存在的对应 `.el` 配套文件，再求值 `.ebox` 表达式。`C-c C-c`、
`ebox-playground-open-file` 和文件渲染入口都遵循这个顺序；保存 `.el` 修改后再次
预览即可生效，不使用 `require` 缓存；只有比源码更新的编译产物才会被使用。允许没有配套文件；
配套文件加载出错则停止求值。普通 Elisp 变量定义决定重新加载时保留还是重置状态。

例如，把数据与操作放在 `notes.el`：

```elisp
;;; notes.el --- Notes example behavior -*- lexical-binding: t; -*-
(defvar notes-body "A long article.")

(defun notes-help ()
  "Return business help for the article."
  (format "Article: %s" notes-body))

(defun notes-activate ()
  "Mark the article in the current Ebox buffer."
  (dolist (node (ebox-selector-query-buffer (current-buffer) "#article"))
    (ebox-node-put node :color "#166534")))
```

`notes.ebox` 专注表达布局：

```elisp
`(column :padding ((lh 1) (ch 2))
         (box :id "article" :width (px 480)
              :help-echo ,(ebox-help-create #'notes-help)
              :pointer hand
              :keymap ,(ebox-keymap-create :activate #'notes-activate)
              ,notes-body))
```

`ebox-help-create` 把返回字符串或 `nil` 的零参数业务函数适配为原生帮助，并提供悬停
buffer 上下文。`ebox-keymap-create` 的 `:activate` 处理 `RET`、`[return]`、`SPC`
和 `[mouse-1]`。
可选的 `:bindings` alist 将按键描述字符串或事件向量与零参数回调配对；也可以直接
传入原生 keymap。详见[公共辅助函数契约](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/keyboard.md#ebox-keymap)。

运行器每次渲染都以词法绑定求值一个 `.ebox` 表达式。反引号保留布局数据，`,` 插入
值，`,@` 展开子节点列表。结果中的属性和子节点都是数据，运行器不会再单独求值。
业务定义留在配套文件中；原生帮助和命令适配使用 Ebox 公共接口，不要仅为了隐藏
重复 DSL 属性列表而添加辅助函数。

默认采用简洁写法：省略冗余默认值，把可继承的共同文字样式放到已有父节点，子节点只写差异。
示例正在讲解的属性仍显式保留。[编写原则](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/values.md#继承与全局关键字)
说明了哪些属性可以继承。空 Box 的自动内容高度为零；一行分隔框显式设置 `:height (lh 1)`。

尺寸数据统一使用 `(单位 数值)`，支持 `px`、`%`、`vw`、`vh`、`ch`、`lh`，
以及 `calc`、`min`、`max`、`clamp`。[统一单位约束表](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/values.md#长度)
规定每个属性允许的单位；不能跨轴混用，嵌套函数的所有分支也遵循同一规则。
无效组合在 Ebox 构造树时就报错。边框厚度采用表中独立的绘制单位规则。
例如比视口少一个行高，写
`:height (calc (- (vh 100) (lh 1)))`；Ebox 会在每次布局时解析这个表达式。
`fit-content` 只作为裸关键词使用，不带参数。Ebox buffer 后端的纵向内容仍按
完整行量化，具体规则见 [Ebox 尺寸契约](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/style-properties.md)。

迁移旧的裸结构 `.ebox` 时，静态布局在最外层加 quote，并去掉内部 list 和 symbol
属性的 quote，例如 `:padding '(1 2)` 改成 `:padding ((lh 1) (ch 2))`。动态值使用
反引号和显式逗号，例如计算像素宽度时写 `:width (px ,(+ 200 40))`。
裸长度、单元素像素列表和旧的视口关键词也需要迁移；运行器不自动识别旧格式。

参考 fixture 直接位于 `examples/` 下。例如：

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/grid-reference.ebox"
                   ebox-playground-directory))
```

在该目录运行 `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`。

<a id="performance-scenarios"></a>
### 性能场景

[`benchmarks/performance-scenarios.el`](benchmarks/performance-scenarios.el)
为这些示例注册交互负载，供工作区[性能工具](https://gitea.gklazycat.heiyu.space/emacs-taf/emacs-taf/src/branch/main/docs/manual.md)
使用：`ebox-playground.desktop.nudge`、`ebox-playground.layer.explode`、
`ebox-playground.interaction.add` 和 `ebox-playground.flex.resize`。每个场景打开
全新预览，在控件标签处重复同一原生按键（或交替 Flex 参考的视口宽度），并将
buffer 与保留树的全新渲染比较。`make perf-check` 在 batch 中运行；向
`scripts/performance.py` 传 `--mode gui` 可包含真实 redisplay。

## 开发

克隆后运行 `make setup-hooks`。提交变更前运行 `make check`；`make structure-check` 用于快速检查目录、命名和引用。

[docs/architecture.zh-CN.md](docs/architecture.zh-CN.md)

`make check` 运行规范检查、编译及 [tests/acceptance.json](tests/acceptance.json) 中的公共验收场景。`make test` 运行同一套公共 API 测试。清单涵盖全部维护的 Lisp 测试。GUI 与性能验收使用独立入口。
