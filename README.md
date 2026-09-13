# ebox-playground

`ebox-playground` is the independent, generic file runner for Ebox DSL examples. It uses only public Ebox APIs; concrete layouts live in readable `.ebox` fixtures under `examples/`. `flex-reference.ebox`, `grid-reference.ebox`, and `size-reference.ebox` demonstrate layout and sizing with a restrained terracotta, sage, blue, violet, ochre, and teal visual language. `interaction-reference.ebox` demonstrates native Ebox interaction and retained updates. `layer-reference.ebox` combines retained overlapping panels with a native anchored menu. `desktop-reference.ebox` provides five directly draggable, overlapping text windows.

ECSS 0.1.0 and TP 1.0.1 are independent packages and may be installed in either order. Install both before Ebox 2.0.1, then install Ebox Playground 0.1.1. `ebox-playground` never reaches into those packages' private APIs.

Standalone gallery entry points default to a definite 720 px canvas so nested examples have stable space in batch renders and one-window demos. Split-window `.ebox` previews instead resolve `(vw 100)` to the preview window's display-safe width. Section separators use their containing Column's available width, so they also fit a narrower root. `etaf-playground` remains the separate higher-level Component and Runtime showcase.

Standalone and batch fixture renders use the same compact 720 px default viewport unless the caller dynamically binds `ebox-viewport-width`; viewport-based references therefore stay inside the example canvas. When `C-c C-c` renders an `.ebox` source buffer, the command keeps the source on the left, opens the preview on the right, and resolves `(vw 100)` to Ebox's shared display-safe window width. Ebox's single serialized viewport controller publishes every window change immediately through its retained path; the Playground owns no second resize hook or timer.

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

Run `make size-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` to check
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
- Hold the primary button on a title bar and move it. Positions are published
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
Use at least 40 columns and 20 rows; larger previews leave more room to arrange
the five panes. Reopening the file creates an independent desktop state.

Run `make desktop-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` for
native command, intermediate motion, release, overlap, rollback, independent
preview and render-parity regressions. Normal `make check` includes this suite.
For repeated movement publication timing and CPU sampling, use the shared
interaction evaluator. Alternating directions keeps each step moving instead
of reaching the desktop boundary; four warmup commands are excluded:

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  -l benchmarks/ebox-playground-flex-resize-evaluator.el \
  --eval '(let ((r (ebox-playground-interaction-evaluator-run "examples/desktop-reference.ebox" "01 ST" "M-<right>" 30 104 36 (quote (:alternate-key "M-<left>" :warmup 4 :profile t))))) (cl-remf r :text) (pp r))'
```

This measures the same position publisher used by dragging, without OS event
delivery or GUI redisplay. Profiling adds sampling overhead; omit `:profile t`
for a timing comparison. See the interaction evaluator contract below.

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
`ebox-keymap-create`, `ebox-help-create`, `ebox-region-update`, and
`ebox-call-with-update-batch` APIs. Each action groups its region changes into
one batch, including the status update. The batch helper joins an existing
batch without flushing and otherwise publishes its pending changes once.
Its rollback covers queued Ebox updates, not arbitrary changes to the
companion's business state; see the [batch API
contract](https://gitea.gklazycat.heiyu.space/geekinney/ebox/src/branch/main/docs/manual.md).
Offsets use inline `ch` and block `lh` units. The text renderer composes whole
rows, and positioned content must share its host's line height.

Run the batch checks without opening GUI windows:

```sh
make layer-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
```

This target runs core layer contracts and the actual demo's native commands,
covered updates, movement, stacking, all four anchor placements, cross-buffer
mouse dispatch, and independent previews. After each command, the tests compare
the mounted output with a fresh render of the committed snapshot, including
paint and native capabilities. `make check` includes the Playground tests.
For repeated command timing, use the existing interaction evaluator with
`"examples/layer-reference.ebox"` and a toolbar label such as
`"UPDATE COVERED NOTE"`; see the invocation below.

For the spatial desktop's expand/collapse path, run:

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  --eval '(setq load-prefer-newer t native-comp-jit-compilation nil)' \
  -l benchmarks/ebox-playground-flex-resize-evaluator.el \
  --eval '(let ((r (ebox-playground-interaction-evaluator-run "examples/layer-reference.ebox" "EXPLODE STACK" "RET" 6 104 100))) (cl-remf r :text) (pp r))'
```

With the root menu closed, the three desktop toolbar commands publish the
affected layer host and status text together, without a full candidate render.
The layer host still recomposes its stacking group; this is owner-level
incremental work, not a minimal pixel rectangle. Visible root portals and
content-dependent geometry keep the broader composition fallback. Regression
tests require one publication per command and reject full candidate rendering;
wall-clock timings are diagnostic, not a CI threshold.

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
- **UPDATE STATUS GROUP** updates the three `.demo-status` Boxes together
  through one public `ebox-update-selector` call.
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
[public capability contract](https://gitea.gklazycat.heiyu.space/geekinney/ebox/src/branch/main/docs/manual.md).

`interaction-reference.el` owns the business functions and state;
`interaction-reference.ebox` owns the layout. The runner reloads the matching
`.el` before each preview. Ebox's `ebox-help-create` supplies the native help
adapter; `ebox-keymap-create` binds
zero-argument callbacks and updates named regions with
`ebox-region-update`. Mouse callbacks automatically run in the event window's
buffer. Ebox adds no application state or focus navigation system; use ordinary
point motion for keyboard bindings. Keymaps are snapshotted, so publishing new
bindings requires replacing `:keymap`. Each evaluation creates a fresh demo.

Run the interaction checks from this directory:

```sh
make interaction-tests EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
```

The target verifies the core interaction contracts and this fixture's rendered
capabilities, command effects, replacements, and removal/restoration.
`make check` also includes the Playground interaction regression tests.

For repeated-key behavior and command timing, use the shared interaction
evaluator:

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  -l benchmarks/ebox-playground-flex-resize-evaluator.el \
  --eval '(pp (ebox-playground-interaction-evaluator-run "examples/interaction-reference.ebox" "ADD " "RET" 30 720 200))'
```

The signature is `(FILE LABEL &optional KEY STEPS WIDTH HEIGHT OPTIONS)`. It opens a
fresh temporary preview, finds the visible label once, and repeats native key
lookup at the resulting point without repositioning after updates. Losing the
node's binding fails the run. `KEY` accepts a key-description string or event
vector; defaults are `RET`, 30 commands, 720 px width, and 200 lines of height.
Sample count and dimensions must be positive integers. `OPTIONS` is an optional
plist accepting `:alternate-key` (the same key formats), `:warmup` (nonnegative
integer, default 0), and `:profile` (boolean, default nil). Both keys must be
bound on the label. Alternation continues across warmup and measured commands,
so an odd warmup starts measurement with the alternate key. Unknown or repeated
option names, invalid values, or a lost binding fail the run.

The returned plist reports mean/p95/max command milliseconds, GC count/time,
allocated cons cells (`:cons-cells`, to track allocation pressure),
publication count, final plain text, and parity with an independent render of
the committed snapshot. Work counters `:layout-calls`, `:surface-plans`,
`:fragment-scans`, and `:node-registrations` count calls to layout rendering,
surface planning, fragment extraction (including local slices), and node-tree
registration. Planning also runs for local patches; the legacy
`:full-surface-renders` field counts candidate-render calls, which may render a
scoped candidate. It does not prove a full-root render. `:last-update` includes
only scalar `:strategy`, `:projection-kind`, `:publication-scope`, and
`:constraint-source` fields from the final public update report.
`:fragment-characters` sums the characters passed to fragment extraction. Read
the call counts alongside this character total to distinguish local work from full-surface scanning; call counts are not affected-node counts.
A parity mismatch fails.

With `:profile t`, `:cpu-profile` adds `:total-samples`, the sampling interval in
nanoseconds, and at most 15 rows each for inclusive and exclusive CPU samples.
Each row contains only a function name, sample count, and percentage of the
total. Inclusive counts include callees and count recursive frames once per
stack; exclusive counts use the top frame. Unnamed frames share `<anonymous>`;
no closures, runtime objects, or call trees are returned. A short run can have
zero samples. Sampling refuses to start while any CPU or memory profiler is
active, preserving that session. Existing stopped logs remain available; an
undrained low-level CPU log is merged into `profiler-cpu-log` before sampling.

Timing includes synchronous command execution, publication, and GC. Timings,
GC, publication counts, and work counters cover only the command loop.
Initial mounting, explicit warmup, and the final parity render are excluded.
The evaluator excludes GUI redisplay, OS key-repeat latency, and idle prewarming.
Warmup and samples share a 30-second deadline checked between commands. Temporary preview, advice, owned profiler, and owned
timer cleanup runs on success, error, timeout, or interruption, preserving
existing previews and windows.
Reuse this entry point for interaction regressions instead of ad hoc key-repeat
timing scripts.

For native click dispatch in an already visible preview, load the same evaluator
and call `(ebox-playground-interaction-evaluator-click BUFFER LABEL &optional OFFSET)`.
`BUFFER` is a live buffer or its name; the first matching label must be visible
in a displaying window. `OFFSET` is a zero-based integer within the label and
defaults to zero. For example, evaluate from the preview buffer:

```elisp
(load (expand-file-name "benchmarks/ebox-playground-flex-resize-evaluator.el"
                        ebox-playground-directory) nil t t)
(ebox-playground-interaction-evaluator-click (current-buffer) "ADD " 0)
(ebox-playground-interaction-evaluator-click (current-buffer) "[-]" 1)
```

This constructs an Emacs mouse event, resolves the native binding, and uses
`call-interactively`; it does not inject an OS mouse click. The helper does not
select a window or move point itself. It returns the clicked position; check
the counter or event log separately to verify the business result.

## Author and render `.ebox` files

The package also owns the `.ebox` file boundary. Visiting an Ebox DSL file selects `ebox-dsl-mode`; its header line shows `C-c C-c Render preview`. Press `C-c C-c` to evaluate the file's single Elisp expression, build its resulting layout data through `ebox-build`, and automatically display the source and preview side by side.

```elisp
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))
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
that exact `.el` source if it exists, then evaluates the `.ebox` expression.
This applies to `C-c C-c`, `ebox-playground-open-file`, and file rendering;
saved `.el` edits are loaded on the next preview without `require` caching or
selecting stale bytecode. A missing companion is allowed; a companion load error
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
  (ebox-region-update "article" :color "#166534"))
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
See the [public helper contract](https://gitea.gklazycat.heiyu.space/geekinney/ebox/src/branch/main/docs/manual.md).

The runner evaluates one `.ebox` expression with lexical bindings on each
render. Backquote preserves layout data, `,` inserts a value, and `,@` inserts a
list of children. Properties and children in the result are data; the runner
does not evaluate them separately. Keep business definitions in the companion;
use Ebox's public adapters for native help and command plumbing, and do not add
helpers merely to hide repeated DSL property lists.

Prefer concise DSL: omit redundant defaults, put common inheritable text
styles on an existing parent, and write child overrides only. Keep explicit
values in panels that teach those properties. The [authoring rules](https://gitea.gklazycat.heiyu.space/geekinney/ebox/src/branch/main/docs/manual.md#prefer-defaults-and-inheritance)
explain which properties inherit. Empty Boxes have zero automatic content
height; give one-line separators an explicit `:height (lh 1)`.

For example simplifications, compare a saved baseline directory with the
current `examples` directory using the existing evaluator:

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  -l benchmarks/ebox-playground-flex-resize-evaluator.el \
  --eval '(ebox-playground-compare-example-directories "/path/to/baseline" "examples")'
```

The optional third and fourth arguments select viewport widths and file names.
Defaults cover both references at 720 and 1000 px, including their complete
documents. The comparison checks text, effective faces, display and interaction
properties, and line widths; a mismatch fails the batch command. It creates no
files or GUI windows and supersedes one-off comparison probes for this task.

For scrolling regressions across examples, use the same evaluator's generic
scroll entry point:

```sh
emacs -Q --batch -L . -L ../ebox -L ../ecss -L ../tp \
  -l benchmarks/ebox-playground-flex-resize-evaluator.el \
  --eval '(ebox-playground-scroll-evaluator-run (directory-files "examples" t "\\.ebox$") 721 20 45)'
```

The arguments are one file path or a list of paths, viewport width in pixels,
sample count, viewport height in lines, and an optional options plist.
By default, each file needs a scrollable root.
Content is fully cached before alternating one-line motions at the top and
midpoint. Results report mean/p95/max milliseconds, measurement-loop GC count/time,
full root renders, general document preparations, surface-plan construction,
node style visits, style computations, prefix rendering, full content materialization, and
fresh-render parity; incomplete motion or changed
output fails the run. The independent render comparison ignores runtime identity
and zero-pixel spacers beside identical font faces; height carriers are retained.
This measures retained TP scroll publication, excluding
native window scrolling, idle prewarming, and redisplay. To compare GUI font
metrics, load this evaluator and call the same function in the existing GUI
Emacs. It uses undisplayed temporary buffers, preserves live previews and windows,
and cleans its mounts, advice, and timers even on errors or interruption. This
entry point supersedes temporary per-example scroll timing probes.

Pass `(:region-id "log")` to measure a nested scroll box declared with
`:id "log"`. Pass `(:cold t)` to measure consecutive forward steps from the
initial render without materializing or warming the content first; combine
both options for a nested cold run. Cold mode requires enough forward scroll
capacity for the requested samples and does not seek to the midpoint. The
initial render can already include lookahead rows; use enough steps to cross
that prefix and inspect `:prefix-renders` and `:materializations` when measuring
a cache miss. Completed-cache no-ops do not count as materialization. The
fresh oracle renders the committed input with its scroll offsets, preserving
callback and keymap identity. It does not reload companion application state.
These checks cover Ebox publication work; use an actual displayed window when
measuring input delivery and Emacs redisplay latency.
Inspect `:document-preparations` and `:surface-plans` to distinguish a viewport
publication from scrolling that still enters the general document update path.

Size data uses `(unit number)` with `px`, `%`, `vw`, `vh`, `ch`, and `lh`, plus
`calc`, `min`, `max`, and `clamp`. The [shared unit-constraint
table](https://gitea.gklazycat.heiyu.space/geekinney/ebox/src/branch/main/docs/manual.md#size-unit-constraints) defines which
units each property accepts; the axes cannot be mixed, including in nested
function branches. Ebox rejects invalid combinations when it builds the tree.
For example, the preview can stay one line
shorter than the viewport with `:height (calc (- (vh 100) (lh 1)))`; the
expression is resolved by Ebox on each layout. `fit-content` stays a bare
keyword and does not take an argument. Border thickness has its own paint-unit
rule in the same table. Ebox's buffer backend quantizes
vertical content to complete lines. See the [Ebox sizing
contract](https://gitea.gklazycat.heiyu.space/geekinney/ebox/src/branch/main/docs/manual.md#4-use-geometry-and-paint-properties).

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

Run `make performance` for the committed Flex resize gate.  It prepares ECSS,
TP, Ebox, Playground bytecode, and the Rust module, then renders a read-only
`HEAD:examples/flex-reference.ebox` snapshot without touching the working-tree
fixture.  The GUI driver performs five warmups followed by 30 accepted viewport
updates; requested and published widths must match exactly, and both p95 and max
must remain at or below 50ms.  For uncontaminated repeated samples, run
`make performance-prepare`, let compilation activity settle, then run
`make performance-evaluator` without rebuilding.

## Development

After cloning, run `make setup-hooks`. Before submitting a change, run `make check`; `make structure-check` is the fast organization gate. The shared rules are in [AGENTS.md](AGENTS.md).

[docs/architecture.md](docs/architecture.md)

`make check` runs structure checks, compilation and the public acceptance scenarios listed in [tests/acceptance.json](tests/acceptance.json). `make test` runs the broader regression suite; GUI and performance checks remain explicit targets. The acceptance inventory is selected by user-visible contracts, not by current pass/fail status.
