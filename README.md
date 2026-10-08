# ebox-playground

Add the repository root to `load-path` and use `(require 'ebox-playground)`.
[`ebox-playground.el`](ebox-playground.el) documents the supported API; `lisp/` contains internal implementations.

`ebox-playground` is the independent, generic file runner for Ebox DSL examples. It uses only public Ebox APIs; concrete layouts live in readable `.ebox` fixtures under `examples/`. `flex-reference.ebox`, `grid-reference.ebox`, and `size-reference.ebox` demonstrate layout and sizing with a restrained terracotta, sage, blue, violet, ochre, and teal visual language. `interaction-reference.ebox` demonstrates native Ebox interaction and retained updates. `layer-reference.ebox` combines retained overlapping panels with a native anchored menu. `desktop-reference.ebox` provides a standalone Ebox-only sample with five draggable overlapping text panes.

Install ECSS 0.1.0 before Ebox 3.0.0, then install Ebox Playground 0.1.1. `ebox-playground` never reaches into those packages' private APIs.

Standalone gallery entry points default to a definite 720 px canvas so nested examples have stable space in batch renders and one-window demos. Split-window `.ebox` previews instead resolve `(vw 100)` to the preview window's display-safe width. Section separators use their containing Column's available width, so they also fit a narrower root. `etaf-playground` remains the separate higher-level Component and Runtime showcase.

Standalone and batch fixture renders use the same compact 720 px default viewport unless the caller dynamically binds `ebox-viewport-width`; viewport-based references therefore stay inside the example canvas. When `C-c C-c` renders an `.ebox` source buffer, the command keeps the source on the left, opens the preview on the right, and resolves `(vw 100)` to Ebox's shared display-safe window width. Ebox's viewport controller relayouts the retained tree on every window change; the Playground owns no second resize hook or timer.

```elisp
(require 'ebox-playground)
(ebox-playground-open)
```

Open `examples/size-reference.ebox` and press `C-c C-c` for **Ebox Size
Reference**. It demonstrates the six length units on their permitted axes, the supported keyword values
for all six size constraints, `calc/min/max/clamp`, and combinations with fonts,
spacing, Flex, and Grid. Resize the preview to compare percentages with viewport
units and see fluid sizes change. Precision and buffer-renderer limitations are
stated in the example rather than presented as browser-equivalent behavior.
Constrained long-text samples separate intrinsic widths; Row samples separate
`auto` from `stretch`. Height content keywords are explicitly marked equivalent
in the current renderer. Shared low/middle/high inputs show how `min`, `max`,
and `clamp` respond at their boundaries.
Solid rectangles mark the measured Box's full extent, including empty space;
pale rulers show available parent width, while white cards contain the labels.

Run `make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` to check
the core size contracts and the actual example declarations, known arithmetic
results, painted sizing differences, complete rendering, and retained viewport updates. `make check` also
includes the example's regression tests.

## PARALLAX draggable desktop

Open `examples/desktop-reference.ebox` and press `C-c C-c`, or use:

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/desktop-reference.ebox"
                   ebox-playground-directory))
```

Five independent panes share a midnight-blue desktop: violet Studio, paper
Notes, cyan Signal, mint Terminal, and rose Palette. Each contains its own
text and layered artwork. All text uses the configured font size.

- Click any exposed pane, including its blank body area, to bring the entire
  window forward. Other windows keep their relative stacking order.
- Hold the primary button on a title bar and move it. Positions update
  while the button is held, preserving the initial grab offset; release applies
  the final position. Windows can partially or fully cover one another.
- The five dock entries raise windows even when they are completely covered.
  **CYCLE** brings the backmost window forward; **RESET** restores all initial
  positions and the original stack, including panes clipped off the desktop.
- **LIGHT/DARK** switches the complete palette: workspace, all five card bodies,
  text, title bars, dock, artwork, swatches and hover colors. Light mode uses
  pastel cards with dark ink. Window positions and stacking survive a toggle;
  **RESET** keeps the chosen theme.
- Mouse clicks and drags do not select text, including between dock buttons and
  at line/buffer ends. This policy belongs only to the Desktop preview; ordinary
  buffers and other examples keep their normal mouse behavior.
- `RET`/`SPC` activates the control at point. `Alt+arrows` on a title or dock
  entry moves its pane; point follows the same native control for key repeat.
  `C-g` stops a drag and keeps the last accepted position.

Horizontal dragging uses pixel positions; vertical movement follows Ebox's
host text rows. This is live text-window composition, not sub-row raster motion.
The companion uses `ebox-keymap-create :drag`; Ebox owns native tracking and
the companion applies pane positions. Leaving the original text window ends
the gesture at its last accepted position.
Use at least 40 columns and 20 rows; larger previews leave more room to arrange
the five panes. Reopening the file creates an independent desktop state.

Run `make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` for
public file rendering, viewport behavior, intermediate desktop motion and
release positions. Normal `make check` includes this suite.
Repeated keyboard movement is the `ebox-playground.desktop.nudge`
[performance scenario](#performance-scenarios).


## ORBIT spatial desktop and layer lab

`examples/layer-minimal.ebox` is the smallest static overlap example. The complete
lab opens with **ORBIT / CREATIVE OS**, a dark spatial desktop with violet,
ice-blue, and acid-green cards, offset shadow slabs, nested geometric artwork,
and floating badges. It uses the same generic runner and a companion for
application state:

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/layer-reference.ebox"
                   ebox-playground-directory))
```

Visit the `.ebox` file and press `C-c C-c` for the source/preview split. Every
control supports click, `RET`, and `SPC`, with native help and hover paint.
All text uses one font size.
Toolbar hover paint belongs to each button, including its own padding; gaps
and unused row space stay unchanged. Deliberate block interaction areas, such
as the covered note and root menu choices, retain their own hover paint.

- **EXPLODE STACK** spreads the three cards apart and returns them to their
  original positions without moving the following sections.
- **CYCLE FOCUS** brings the studio, task card, and player to the front in turn.
- **SWITCH MOOD** changes the card palette between lunar violet/ice/lime and
  solar pink/apricot/mint. Each preview has independent state.
- **UPDATE COVERED NOTE** changes a note fully covered by Panel A. Update it
  twice, then **TOGGLE PANEL A** to reveal revision 02. The revealed note has
  its own native action and live help; covering it never removes its logical
  data or bindings.
- **MOVE PANEL A** changes `:left` and `:top` without adding flow rows.
  **RAISE / LOWER A** changes `:z-index` between 2 and 4 while Panel B stays at
  3. Opaque panel content and padding replace the lower layer's visible paint.
- The relative marker reserves its original flow row and paints one row lower.
  Each parent forms a local stacking group automatically; no isolation
  declaration is needed.
- **OPEN / CLOSE ROOT MENU** shows a menu whose logical owner clips to one
  row. The nested absolute menu declares `:layer root` and anchors to the
  trigger's semantic ID, so it can paint beyond that local clip.
  **CYCLE PLACEMENT** visits `bottom-start`, `bottom-end`, `top-start`, and
  `top-end`; **MOVE ANCHOR** moves the trigger and its open menu together.
  Choosing sage or amber updates the result and closes the menu.

`layer-reference.ebox` contains layout data and state references;
`layer-reference.el` owns state and business actions. It uses only public
`ebox-keymap-create`, `ebox-help-create`, `ebox-selector-query-buffer`,
`ebox-node-set-props` and `ebox-call-with-batch` APIs: each action finds its
nodes by `:id`, changes their properties and the status text, and flushes the
batch once. See the [batch API
contract](https://gitea.gklazycat.heiyu.space/emacs-taf/ebox/src/branch/main/docs/manual.md).
Offsets use inline `ch` and block `lh` units. The text renderer composes whole
rows, and positioned content must share its host's line height.

Run the batch checks without opening GUI windows:

```sh
make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
```

This target runs the demo's native commands: covered note updates, panel
visibility and the card layout toggle. `make check` includes the Playground
tests. Repeated EXPLODE STACK timing is the `ebox-playground.layer.explode`
[performance scenario](#performance-scenarios).

<a id="native-interaction-lab"></a>
## Native interaction lab

Open the interaction reference with the existing file runner:

```elisp
(require 'ebox-playground)
(ebox-playground-open-file
 (expand-file-name "examples/interaction-reference.ebox"
                   ebox-playground-directory))
```

You can also visit `examples/interaction-reference.ebox` and press `C-c C-c`
for a source/preview split. **Ebox Native Interaction Lab** first separates
help text and pointer shapes from hover paint, then combines `:help-echo`,
`:pointer`, `:hover-style`, and `:keymap` in a live counter and event log.

- Hover the bordered cards, including their padding, to compare static help,
  dynamic help, native pointers, and color/text-decoration changes.
- Click **ADD / [+]** to add or the separate **[-]** Text to subtract. Move
  point into an action to use `RET` / `SPC`, or use its `+` / `-` shortcuts.
  **SWITCH STEP 1 / 5** replaces its keymap with commands for the chosen step.
- **SWITCH HOVER PALETTE** replaces hover paint. **REMOVE / RESTORE** clears
  all four capabilities with explicit `nil`, then restores them. The Text
  reset action resets the count.
- **UPDATE STATUS GROUP** updates the three `.demo-status` Boxes found by one
  `ebox-selector-query-buffer` class query in one batch.
- The nested surface demonstrates parent coverage, a Text child with its own
  commands, and an explicit-`nil` child that blocks enclosing capabilities.
  The event log records which command ran.

Box help, pointer, and keymap include content, padding, and border, excluding
that Box's margin and structural newlines. A hover owner's text and padding
share one native `mouse-face` within a rendered line; unspecified attributes
use that owner's base style, including when child text normally differs.
Physical left/right borders are excluded from hover; horizontal border strokes
keep their paint. Native pointer appearance and help display depend on Emacs
settings and the window system. See the
[public capability contract](https://gitea.gklazycat.heiyu.space/emacs-taf/ebox/src/branch/main/docs/manual.md).

`interaction-reference.el` owns the business functions and state;
`interaction-reference.ebox` owns the layout. The runner reloads the matching
`.el` before each preview. Ebox's `ebox-help-create` supplies the native help
adapter; `ebox-keymap-create` binds
zero-argument callbacks, which update nodes found by `:id` with
`ebox-node-set-props`, `ebox-node-set-text` and `ebox-node-replace-children`. Mouse callbacks automatically run in the event window's
buffer. Ebox adds no application state or focus navigation system; use ordinary
point motion for keyboard bindings. Keymaps are snapshotted, so installing new
bindings requires replacing `:keymap`. Each evaluation creates a fresh demo.

Run the interaction checks from this directory:

```sh
make test EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
```

The target runs this fixture's counter, event log, status group and binding
removal. `make check` also includes the Playground interaction regression tests.
Repeated ADD timing is the `ebox-playground.interaction.add`
[performance scenario](#performance-scenarios).

## Author and render `.ebox` files

The package also owns the `.ebox` file boundary. Visiting an Ebox DSL file selects `ebox-playground-mode`; its header line shows `C-c C-c Render preview`. Press `C-c C-c` to evaluate the file's single Elisp expression, build its resulting layout data through `ebox-build`, and automatically display the source and preview side by side.

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-playground-mode))
```

Write the same expression in `.ebox` that you would pass as the argument to
`(ebox-build ...)` in Elisp. Quote a whole static layout; its list and symbol
properties do not need additional quotes:

```elisp
'(column :padding ((lh 1) (ch 2))
         :cross-align center
         (box :width (px 240) "Hello"))
```

Keep necessary business functions and variables in an optional same-basename
`.el` file beside the `.ebox`. Before each preview evaluation, the runner loads
that `.el` companion if it exists, then evaluates the `.ebox` expression.
This applies to `C-c C-c`, `ebox-playground-open-file`, and file rendering;
saved `.el` edits are loaded on the next preview without `require` caching.
Compiled companion bytecode is used only when it is newer than the source. A missing companion is allowed; a companion load error
stops evaluation. Ordinary Elisp variable definitions control state retention
or reset on reload.

For example, put the data and action in `notes.el`:

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

Keep `notes.ebox` focused on the layout:

```elisp
`(column :padding ((lh 1) (ch 2))
         (box :id "article" :width (px 480)
              :help-echo ,(ebox-help-create #'notes-help)
              :pointer hand
              :keymap ,(ebox-keymap-create :activate #'notes-activate)
              ,notes-body))
```

`ebox-help-create` adapts a zero-argument business function returning a string
or `nil` to native help with the hovered buffer as context. `ebox-keymap-create`
handles `RET`, `[return]`, `SPC`, and `[mouse-1]` through
`:activate`. Its optional `:bindings` alist pairs key-description strings or
event vectors with zero-argument callbacks. Raw native keymaps are also accepted.
See the [public helper contract](https://gitea.gklazycat.heiyu.space/emacs-taf/ebox/src/branch/main/docs/manual.md).

The runner evaluates one `.ebox` expression with lexical bindings on each
render. Backquote preserves layout data, `,` inserts a value, and `,@` inserts a
list of children. Properties and children in the result are data; the runner
does not evaluate them separately. Keep business definitions in the companion;
use Ebox's public adapters for native help and command plumbing, and do not add
helpers merely to hide repeated DSL property lists.

Prefer concise DSL: omit redundant defaults, put common inheritable text
styles on an existing parent, and write child overrides only. Keep explicit
values in panels that teach those properties. The [authoring rules](https://gitea.gklazycat.heiyu.space/emacs-taf/ebox/src/branch/main/docs/manual.md#prefer-defaults-and-inheritance)
explain which properties inherit. Empty Boxes have zero automatic content
height; give one-line separators an explicit `:height (lh 1)`.

Size data uses `(unit number)` with `px`, `%`, `vw`, `vh`, `ch`, and `lh`, plus
`calc`, `min`, `max`, and `clamp`. The [shared unit-constraint
table](https://gitea.gklazycat.heiyu.space/emacs-taf/ebox/src/branch/main/docs/manual.md#size-unit-constraints) defines which
units each property accepts; the axes cannot be mixed, including in nested
function branches. Ebox rejects invalid combinations when it builds the tree.
For example, the preview can stay one line
shorter than the viewport with `:height (calc (- (vh 100) (lh 1)))`; the
expression is resolved by Ebox on each layout. `fit-content` stays a bare
keyword and does not take an argument. Border thickness has its own paint-unit
rule in the same table. Ebox's buffer backend quantizes
vertical content to complete lines. See the [Ebox sizing
contract](https://gitea.gklazycat.heiyu.space/emacs-taf/ebox/src/branch/main/docs/manual.md#4-use-geometry-and-paint-properties).

To migrate an old unquoted `.ebox` layout, quote the whole static list and
remove the quotes around its list and symbol properties, for example
`:padding '(1 2)` becomes `:padding ((lh 1) (ch 2))`. For dynamic values, use
backquote and an explicit comma: a computed pixel width becomes
`:width (px ,(+ 200 40))`. Bare lengths, singleton pixel lists, and the old
viewport keywords must also be migrated. The runner does not auto-detect the
legacy format.

The reference fixtures live directly under `examples/`. For example:

```elisp
(ebox-playground-open-file
 (expand-file-name "examples/grid-reference.ebox"
                   ebox-playground-directory))
```

Run `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` from this directory.

<a id="performance-scenarios"></a>
### Performance scenarios

[`benchmarks/performance-scenarios.el`](benchmarks/performance-scenarios.el)
registers interaction workloads on these examples for the workspace
[performance tool](https://gitea.gklazycat.heiyu.space/emacs-taf/emacs-taf/src/branch/main/docs/manual.md):
`ebox-playground.desktop.nudge`, `ebox-playground.layer.explode`,
`ebox-playground.interaction.add` and `ebox-playground.flex.resize`. Each
opens a fresh preview, repeats one native key binding at a control label (or
alternates the Flex reference width) and compares the buffer with a fresh
render of the retained tree. Run them in batch with `make perf-check`, or pass
`--mode gui` to `scripts/performance.py` for real redisplay.

## Development

After cloning, run `make setup-hooks`. Before submitting a change, run `make check`; `make structure-check` is the fast organization gate.

[docs/architecture.md](docs/architecture.md)

`make check` runs structure checks, compilation and the public acceptance scenarios listed in [tests/acceptance.json](tests/acceptance.json). `make test` runs the same public API suite. The inventory covers every maintained Lisp test. GUI and performance checks use separate targets.

## Source layout

Add the repository root to `load-path` and require `ebox-playground`. The root entry
loads the implementation in `lisp/` and documents the supported public APIs in
its Commentary. Package archives include both the root entry and `lisp/`.
The preview mode is `ebox-playground-mode`; use `ebox-playground-render` to render the current file.
