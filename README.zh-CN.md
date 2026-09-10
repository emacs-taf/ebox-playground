# ebox-playground

`ebox-playground` 是 Ebox DSL 的独立通用文件运行器，只使用 Ebox 公共 API；具体布局都放在 `examples/` 下易读的 `.ebox` fixture 中。`flex-reference.ebox`、`grid-reference.ebox` 和 `size-reference.ebox` 用克制的陶土色、鼠尾草绿、蓝色、紫色、赭石色和青绿色视觉语言，展示布局与尺寸规则。`interaction-reference.ebox` 展示 Ebox 原生交互及 retained 更新。

ECSS 0.1.0 与 TP 1.0.1 是互相独立的包，安装顺序任意；两者都安装后再安装 Ebox 2.0.1，最后安装 Ebox Playground 0.1.1。`ebox-playground` 不调用这些依赖的私有 API。

独立画廊入口默认使用明确的 720 px 画布，因此 batch 渲染和单窗口演示里的嵌套示例有稳定空间。分屏 `.ebox` 预览则会将 `(vw 100)` 解析为右侧预览窗口的显示安全宽度。章节分隔条使用所在 Column 的可用宽度，因此根容器缩窄时也会跟随。高层 Component/Runtime 展示仍由独立的 `etaf-playground` 提供。

独立和 batch fixture 渲染默认也使用紧凑的 720 px 视口；如果调用方动态绑定了 `ebox-viewport-width`，则保留调用方的值。因此依赖 viewport 的参考例子也会保持在示例画布内。通过 `C-c C-c` 渲染 `.ebox` 源文件时，命令会把源文件保留在左侧、在右侧打开预览，并将 `(vw 100)` 解析为 Ebox 统一计算的显示安全宽度；Ebox 唯一且串行的 viewport controller 会立即通过 retained 路径发布每次 window-size 变化，Playground 不再拥有第二套 resize hook 或 timer。

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

运行 `make size-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`，可检查核心尺寸契约、
示例的实际属性覆盖、已知计算结果、背景所指示的尺寸差异、完整渲染及保留状态的视口更新。`make check` 也包含此示例的回归测试。

## 滚动性能验证

使用共享 `scripts/ebox-playground-flex-resize-evaluator.el` 的入口：

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  --eval '(setq load-prefer-newer t native-comp-jit-compilation nil)' \
  -l scripts/ebox-playground-flex-resize-evaluator.el \
  --eval '(ebox-playground-scroll-evaluator-run "examples/flex-reference.ebox" 104 6 36)'
```

参数依次为文件路径或路径列表、视口像素宽度、采样次数、视口行高及可选 options
plist。默认完全缓存根滚动内容，再测量顶部和中间位置的往返单行滚动。传入
`(:region-id "log")` 可选择声明了 `:id "log"` 的嵌套滚动框；`(:cold t)` 则从
初始渲染开始连续向前滚动，不预热、不主动物化全部内容，也不跳到中间位置。
两者可以组合，所选区域必须有足够的滚动空间完成采样。

初始渲染可能已包含前瞻缓存行；要测量缓存未命中，采样次数应超过该前缀，并检查
`:prefix-renders`（实际前缀渲染）和 `:materializations`（完整内容生产）计数。
已完成缓存的空操作不计入完整物化次数。

结果报告 mean/p95/max 毫秒、采样循环的 GC 次数／耗时、完整根渲染、通用文档准备、surface 计划构造、样式计算及缓存生产次数，并与独立渲染已提交输入、
恢复其滚动位置后的结果比较。比较保留 callback 和 keymap 身份，不重新加载业务
状态；移动未完成或绘制不一致都会失败。测试使用临时 buffer，并清理挂载、advice
和定时器，不改变现有预览。测量包含 Ebox/TP 发布，不包含 GUI 输入传递、原生窗口
滚动或 Emacs redisplay。此入口取代临时的逐示例滚动探针。

## 图层与原生菜单示例

打开 `examples/layer-reference.ebox` 并按 `C-c C-c`，可查看 ORBIT 空间桌面、
保留内容的重叠面板及锚定菜单；`examples/layer-minimal.ebox` 保留最小重叠示例。
工具栏每个按钮支持点击、`RET` 和 `SPC`。悬停绘制仅覆盖按钮及其自身 padding，
按钮间隙和行内剩余空间保持不变；被覆盖笔记、根菜单选项等有意设置为块级交互的
区域仍保留自己的悬停绘制。

`layer-reference.ebox` 保存布局，`layer-reference.el` 保存业务状态与操作。每个
操作通过公共 `ebox-call-with-update-batch` 将 region 变化与状态栏更新合并。
helper 加入已有 batch 时不 flush；自己拥有 batch 时只发布一次待处理变化。
回滚覆盖排队的 Ebox 更新，不撤销 companion 中任意业务状态变化，详见
[批量更新契约](../ebox/docs/user/ebox-api-reference.zh.md#合并-region-更新)。

运行 `make layer-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`，
验证图层契约、实际原生命令及已提交快照的独立渲染一致性，无需打开 GUI 窗口。

使用共享入口测量桌面展开／收起路径：

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  --eval '(setq load-prefer-newer t native-comp-jit-compilation nil)' \
  -l scripts/ebox-playground-flex-resize-evaluator.el \
  --eval '(let ((r (ebox-playground-interaction-evaluator-run "examples/layer-reference.ebox" "EXPLODE STACK" "RET" 6 104 100))) (cl-remf r :text) (pp r))'
```

根菜单关闭时，桌面三个工具栏命令只将受影响的叠层宿主和状态文字一起发布，不再
完整渲染候选树。宿主内部仍会重新合成堆叠组；这是 owner 级增量，还不是像素级
最小脏矩形。可见根浮层和依赖内容的几何仍保留扩大合成范围的回退。回归测试要求
每次命令只发布一次，并禁止完整候选渲染；耗时是诊断数据，不作为 CI 时间阈值。

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
- **UPDATE STATUS GROUP** 通过一次公共 `ebox-update-selector` 调用，共同更新
  三个 `.demo-status` Box。
- 嵌套区域展示父节点覆盖、拥有独立命令的 Text 子节点，以及通过显式 `nil` 阻止
  外层能力覆盖的子节点。事件日志记录实际运行的命令。

Box 的帮助、指针和 keymap 范围包含内容、padding 和 border，不包含该 Box 自身的
margin 及结构性换行符。同一渲染行内，一个 hover owner 的文字与 padding 共享原生
`mouse-face`；未指定属性取自 owner 的基础样式，即使子文本的正常样式不同。
物理左右边框不参与悬停，水平边框线条保留自己的绘制。原生指针外观和帮助显示由
Emacs 设置及窗口系统决定，
见[公共能力契约](../ebox/docs/user/ebox-api-reference.zh.md#原生节点能力)。

`interaction-reference.el` 负责业务函数与状态，`interaction-reference.ebox` 负责
布局；运行器在每次预览前重新加载对应 `.el`。Ebox 的 `ebox-help-create` 提供原生
帮助适配，`ebox-keymap-create` 绑定
零参数回调，使用 `ebox-region-update` 更新命名 region；鼠标回调自动在事件窗口的
buffer 中运行。Ebox 不增加应用状态或焦点导航系统，使用键盘绑定时通过普通 point
移动定位。Keymap 会创建快照，发布新绑定需要替换 `:keymap`。每次求值都会创建
独立的新示例。

在本目录运行交互检查：

```sh
make interaction-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
```

该入口验证核心交互契约、示例渲染后的能力、命令效果、替换与清除/恢复。
`make check` 也包含 Playground 交互回归测试。

检查重复按键行为和命令耗时时，使用共享交互 evaluator：

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  -l scripts/ebox-playground-flex-resize-evaluator.el \
  --eval '(pp (ebox-playground-interaction-evaluator-run "examples/interaction-reference.ebox" "ADD " "RET" 30 720 200))'
```

函数签名为 `(FILE LABEL &optional KEY STEPS WIDTH HEIGHT)`。它创建全新的临时
预览，定位一次可见标签，然后在该 point 位置反复查找原生按键绑定，不在更新后重新
定位；失去节点绑定时检查失败。`KEY` 接受按键描述字符串或事件向量，默认参数为
`RET`、30 次命令、720 px 宽、200 行高；次数与尺寸必须为正整数。

返回的 plist 包含命令耗时的 mean/p95/max 毫秒数、GC 次数与耗时、cons 分配总数
（`:cons-cells`，用于观察分配压力）、发布次数、最终
纯文本，以及与独立渲染已提交快照的结果是否一致。计算计数器 `:layout-calls`、
`:surface-plans`、`:fragment-scans` 和 `:node-registrations` 分别统计布局渲染、
surface 规划、fragment 提取（包含局部切片）和节点树注册的调用次数。
局部补丁也会执行规划；`:full-surface-renders` 单独统计完整候选渲染次数。
`:fragment-characters` 累计传给 fragment 提取的字符数；结合调用次数与字符总量，
区分局部处理和全 surface 扫描。调用次数不是受影响节点数。快照对比不一致则检查失败。

计时包括同步命令执行、发布和 GC。耗时、GC、发布次数及计算计数器都只覆盖命令
循环，不包括初次挂载及最后的快照对比渲染。该入口也不测量 GUI redisplay、
操作系统按键重复延迟或空闲预热。采样循环在命令之间检查 30 秒期限；成功、报错、
超时或中断时都会清理临时预览和自身计时器，并保留现有预览与窗口。后续交互回归
复用此入口，不另建临时的重复按键计时脚本。

诊断已有可见预览中的原生点击分派时，加载同一 evaluator 并调用
`(ebox-playground-interaction-evaluator-click BUFFER LABEL &optional OFFSET)`。
`BUFFER` 是 live buffer 或其名称；第一个匹配标签必须位于显示窗口的可见区域内。
`OFFSET` 是标签内从零开始的整数字符偏移，默认为零。例如，在预览 buffer 中求值：

```elisp
(load (expand-file-name "scripts/ebox-playground-flex-resize-evaluator.el"
                        ebox-playground-directory) nil t t)
(ebox-playground-interaction-evaluator-click (current-buffer) "ADD " 0)
(ebox-playground-interaction-evaluator-click (current-buffer) "[-]" 1)
```

它构造 Emacs 鼠标事件，查找原生绑定并通过 `call-interactively` 调用，不注入操作
系统鼠标点击。辅助函数自身不切换窗口或移动 point，返回被点击的位置；业务结果需
另行通过计数器或事件日志检查。

## 编写和渲染 `.ebox` 文件

这个包也拥有 `.ebox` 文件入口。访问 Ebox DSL 文件时会自动进入 `ebox-dsl-mode`，header line 会显示 `C-c C-c Render preview`；按 `C-c C-c` 会求值文件中的唯一一个 Elisp 表达式，将得到的布局数据传给 `ebox-build`，渲染并自动并排显示源文件和预览 buffer。

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))
```

`.ebox` 中写的表达式与 Elisp 中传给 `(ebox-build ...)` 的参数完全一致。
静态布局对整个列表加 quote，内部的 list 和 symbol 属性不再单独加 quote：

```elisp
'(column :padding ((lh 1) (ch 2))
         :cross-align center
         (box :width (px 240) "Hello"))
```

必要的业务函数与变量放在 `.ebox` 旁边可选的同名 `.el` 文件中。每次预览求值前，
运行器先加载存在的对应 `.el` 源码，再求值 `.ebox` 表达式。`C-c C-c`、
`ebox-playground-open-file` 和文件渲染入口都遵循这个顺序；保存 `.el` 修改后再次
预览即可生效，不使用 `require` 缓存，也不选择旧 bytecode。允许没有配套文件；
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
  (ebox-region-update "article" :color "#166534"))
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
传入原生 keymap。详见[公共辅助函数契约](../ebox/docs/user/ebox-api-reference.zh.md#原生节点能力)。

运行器每次渲染都以词法绑定求值一个 `.ebox` 表达式。反引号保留布局数据，`,` 插入
值，`,@` 展开子节点列表。结果中的属性和子节点都是数据，运行器不会再单独求值。
业务定义留在配套文件中；原生帮助和命令适配使用 Ebox 公共接口，不要仅为了隐藏
重复 DSL 属性列表而添加辅助函数。

默认采用简洁写法：省略冗余默认值，把可继承的共同文字样式放到已有父节点，子节点只写差异。
示例正在讲解的属性仍显式保留。[编写原则](../ebox/docs/user/ebox-user-guide.zh.md#优先利用默认值和继承)
说明了哪些属性可以继承。空 Box 的自动内容高度为零；一行分隔框显式设置 `:height (lh 1)`。

简化示例时，使用已有 evaluator 对比保存的基准目录和当前 `examples` 目录：

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  -l scripts/ebox-playground-flex-resize-evaluator.el \
  --eval '(ebox-playground-compare-example-directories "/path/to/baseline" "examples")'
```

可选的第三、第四参数指定视口宽度和文件名；默认检查两个示例在 720、1000 px 下的首屏与全文。
比较内容包括文字、有效 face、display、交互属性和逐行宽度，发现差异时 batch 命令失败。
该入口不创建文件或 GUI 窗口，后续同类任务直接复用它，不再编写一次性比较脚本。

尺寸数据统一使用 `(单位 数值)`，支持 `px`、`%`、`vw`、`vh`、`ch`、`lh`，
以及 `calc`、`min`、`max`、`clamp`。[统一单位约束表](../ebox/docs/user/ebox-user-guide.zh.md#size-unit-constraints)
规定每个属性允许的单位；不能跨轴混用，嵌套函数的所有分支也遵循同一规则。
无效组合在 Ebox 构造树时就报错。边框厚度采用表中独立的绘制单位规则。
例如比视口少一个行高，写
`:height (calc (- (vh 100) (lh 1)))`；Ebox 会在每次布局时解析这个表达式。
`fit-content` 只作为裸关键词使用，不带参数。Ebox buffer 后端的纵向内容仍按
完整行量化，具体规则见 [Ebox 尺寸契约](../ebox/docs/user/ebox-user-guide.zh.md#4-使用几何与绘制-property)。

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
