;;; ebox-playground-flex-resize-evaluator.el --- Flex resize evaluator -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; This evaluator exercises the public playground path used by an interactive
;; `.ebox' preview: source buffer on the left, rendered buffer on the right,
;; and a sustained window-resize burst that reaches
;; `window-size-change-functions'.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'profiler)
(require 'ebox-playground)
(require 'ebox)

(defcustom ebox-playground-flex-resize-evaluator-fixture
  (or (getenv "EBOX_PLAYGROUND_FLEX_FIXTURE")
      (expand-file-name "examples/flex-reference.ebox"
                        ebox-playground-directory))
  "Read-only Flex fixture used by the performance evaluator."
  :type 'file
  :group 'ebox-playground)

(defconst ebox-playground-flex-resize-evaluator-warmup-count 5)
(defconst ebox-playground-flex-resize-evaluator-sample-count 30)

(defcustom ebox-playground-flex-resize-evaluator-max-seconds 2.0
  "Maximum allowed end-to-end time for the measured resize burst."
  :type 'number
  :group 'ebox-playground)

(defcustom ebox-playground-flex-resize-evaluator-max-update-seconds 0.05
  "Maximum allowed time for one published viewport update."
  :type 'number
  :group 'ebox-playground)

(defcustom ebox-playground-flex-resize-evaluator-max-gap-seconds 0.08
  "Maximum allowed completion gap during the resize burst."
  :type 'number
  :group 'ebox-playground)

(defvar ebox-playground-flex-resize-evaluator--output-lines nil
  "Report lines collected during one evaluator run.")

(defun ebox-playground-flex-resize-evaluator--percentile
    (samples percentile)
  "Return nearest-rank PERCENTILE from numeric SAMPLES."
  (unless samples
    (error "Flex evaluator cannot summarize empty samples"))
  (let* ((ordered (sort (copy-sequence samples) #'<))
         (rank (max 1 (ceiling (* percentile (length ordered))))))
    (nth (1- rank) ordered)))

(defconst ebox-playground-flex-resize-evaluator--runtime-properties
  (delete-dups
   (append (mapcar #'cdr ebox-region-types)
           '(ebox-content-idx ebox-content-owners ebox-scroll-window
             ebox--paint-origin)))
  "Ebox identity properties omitted from fresh-render comparison.")

(defun ebox-playground-flex-resize-evaluator--line-widths (buffer)
  "Return pixel widths for every rendered line in BUFFER."
  (with-current-buffer buffer
    (mapcar #'ebox-string-pixel-width
            (ebox-string-lines (buffer-string)))))

(defun ebox-playground-flex-resize-evaluator--merge-face (higher lower)
  "Merge HIGHER priority face attributes into LOWER without losing relative sizes."
  (let ((result (copy-sequence lower)))
    (while higher
      (let ((attribute (pop higher))
            (value (pop higher)))
        (unless (eq value 'unspecified)
          (setq result
                (plist-put result attribute
                           (if (plist-member result attribute)
                               (merge-face-attribute
                                attribute value (plist-get result attribute))
                             value))))))
    result))

(defun ebox-playground-flex-resize-evaluator--effective-face (face &optional seen)
  "Return sorted effective attributes of FACE, guarding inheritance with SEEN.
Face lists put higher priority entries first.  Relative heights are merged using
Emacs's own attribute operation; named faces use the current display frame."
  (let
      ((attributes
        (cond
         ((null face) nil)
         ((facep face)
          (when (member face seen)
            (error "Cyclic face inheritance: %S" face))
          (ebox-playground-flex-resize-evaluator--effective-face
           (cl-mapcan (lambda (entry) (list (car entry) (cdr entry)))
                      (face-all-attributes face (selected-frame)))
           (cons face seen)))
         ((and (proper-list-p face) (keywordp (car face)))
          (unless (zerop (% (length face) 2))
            (error "Invalid anonymous face: %S" face))
          (let ((own (copy-sequence face))
                (inherited (plist-get face :inherit)))
            (cl-remf own :inherit)
            (ebox-playground-flex-resize-evaluator--merge-face
             own
             (unless (memq inherited '(nil unspecified))
               (ebox-playground-flex-resize-evaluator--effective-face
                inherited seen)))))
         ((proper-list-p face)
          (let (result)
            (dolist (entry (reverse face))
              (setq result
                    (ebox-playground-flex-resize-evaluator--merge-face
                     (ebox-playground-flex-resize-evaluator--effective-face
                      entry seen)
                     result)))
            result))
         (t (error "Unsupported face value in render comparison: %S" face)))))
    (cl-loop for key in (sort (cl-loop for (key _value) on attributes by #'cddr
                                      collect key)
                              (lambda (a b)
                                (string-lessp (symbol-name a) (symbol-name b))))
             append (list key (plist-get attributes key)))))

(defun ebox-playground-flex-resize-evaluator--visual-text (text)
  "Return TEXT with runtime ids removed and face cascades normalized.
Keep characters, display dimensions, effective face attributes, and interactive
properties.  Equivalent anonymous face stacks compare equal; changes to visible
color, relative font size, measurement, or interaction still compare unequal."
  (let ((copy (copy-sequence text))
        (hover-owners (make-hash-table :test #'eql)))
    (when (> (length copy) 0)
      (remove-list-of-text-properties
       0 (length copy)
       ebox-playground-flex-resize-evaluator--runtime-properties
       copy)
      ;; Fresh renders allocate different owner ids.  Preserve the owner
      ;; partition, while comparing all of the retained hover paint facts.
      (let ((start 0) end)
        (while (< start (length copy))
          (setq end (next-single-property-change
                     start 'ebox--hover-style copy (length copy)))
          (when-let* ((declaration (get-text-property start 'ebox--hover-style copy))
                      (owner (plist-get declaration :owner)))
            (put-text-property
             start end 'ebox--hover-style
             (plist-put
              (copy-sequence declaration) :owner
              (or (gethash owner hover-owners)
                  (puthash owner (1+ (hash-table-count hover-owners)) hover-owners)))
             copy))
          (setq start end)))
      (dolist (property '(face font-lock-face mouse-face))
        (let ((start 0) end)
          (while (< start (length copy))
            (setq end (next-single-property-change
                       start property copy (length copy)))
            (when-let* ((face (get-text-property start property copy)))
              (put-text-property
               start end property
               (ebox-playground-flex-resize-evaluator--effective-face face)
               copy))
            (setq start end)))))
    copy))

(defun ebox-playground-flex-resize-evaluator--example-text (file width full)
  "Render FILE at WIDTH, using an unclipped document copy when FULL is non-nil."
  (let ((ebox-viewport-width width)
        (ebox-viewport-height 36))
    (if full
        (let ((form (ebox-playground--evaluate-form
                     (ebox-playground--read-file file) file)))
          ;; These changes affect only the comparison copy, never the author file.
          (cl-remf (cdr form) :height)
          (cl-remf (cdr form) :overflow)
          (setcdr form (append '(:height auto :overflow visible) (cdr form)))
          (ebox-render (ebox-build form)))
      (ebox-render (ebox-playground-view file width)))))

(defun ebox-playground-compare-example-directories
    (baseline-directory current-directory &optional widths files)
  "Compare FILES in BASELINE-DIRECTORY and CURRENT-DIRECTORY at WIDTHS.
Default FILES are the Flex and Grid references; default WIDTHS are 720 and 1000.
Compare both the authored 36-line viewport and the complete document so changes
below the fold cannot pass unnoticed.  Print bounded results and signal an error
on changed text, effective face, display, interaction, or measured line width.
No files, windows, buffers, or persistent render state are modified."
  (let (results failures)
    (dolist (file (or files '("flex-reference.ebox" "grid-reference.ebox")))
      (dolist (width (or widths '(720 1000)))
        (unless (and (numberp width) (> width 0))
          (error "Comparison viewport must be a positive number: %S" width))
        (dolist (full '(nil t))
          (let* ((before (ebox-playground-flex-resize-evaluator--example-text
                          (expand-file-name file baseline-directory) width full))
                 (after (ebox-playground-flex-resize-evaluator--example-text
                         (expand-file-name file current-directory) width full))
                 (before-widths (mapcar #'ebox-string-pixel-width
                                       (ebox-string-lines before)))
                 (after-widths (mapcar #'ebox-string-pixel-width
                                      (ebox-string-lines after)))
                 (left (ebox-playground-flex-resize-evaluator--visual-text before))
                 (right (ebox-playground-flex-resize-evaluator--visual-text after))
                 (same-widths (and (= (length before-widths) (length after-widths))
                                   (cl-every #'= before-widths after-widths)))
                 (same-text (equal-including-properties left right))
                 (same (and same-widths same-text))
                 (result (list :file file :width width
                               :mode (if full 'document 'viewport)
                               :equal same :line-widths-equal same-widths
                               :before-length (length before)
                               :after-length (length after))))
            (princ (format "%s %s width=%s mode=%s characters=%s/%s line-widths=%s\n"
                           (if same "PASS" "FAIL") file width
                           (if full 'document 'viewport)
                           (length before) (length after) same-widths))
            (unless same
              (let* ((position
                      (cl-loop for index below (min (length left) (length right))
                               unless (equal-including-properties
                                       (substring left index (1+ index))
                                       (substring right index (1+ index)))
                               return index))
                     (print-level 4) (print-length 12))
                (when position
                  (princ (format "  first difference at character %s: %S -> %S\n"
                                 position
                                 (list (aref left position)
                                       (text-properties-at position left))
                                 (list (aref right position)
                                       (text-properties-at position right))))))
              (push result failures))
            (push result results)))))
    (when failures
      (error "Example render comparison failed in %d cases" (length failures)))
    (nreverse results)))

(defun ebox-playground-flex-resize-evaluator--check (name condition detail)
  "Record a named check and return whether CONDITION passed."
  (push (format "%s %s -- %s"
                (if condition "PASS" "FAIL") name detail)
        ebox-playground-flex-resize-evaluator--output-lines)
  condition)

(defun ebox-playground-scroll-evaluator--measure (region-id steps &optional cold)
  "Measure STEPS one-line scrolls of REGION-ID.
Alternate cached motion by default; COLD advances without retracing prior rows."
  (let ((root-renders 0) (node-styles 0) (style-computations 0)
        (document-preparations 0) (surface-plans 0)
        (prefix-renders 0) (materializations 0)
        (deadline (+ (float-time) 30))
        samples installed gc-start gc-time-start)
    (unwind-protect
        (progn
          (dolist (entry
                   (list
                    (cons 'ebox-incremental-prepare-scoped-commit
                          (lambda (&rest _) (cl-incf document-preparations)))
                    (cons 'ebox-surface--surface-plan
                          (lambda (&rest _) (cl-incf surface-plans)))
                    (cons 'ebox-surface--render-candidate
                          (lambda (&rest _) (cl-incf root-renders)))
                    (cons 'ebox-surface--apply-node-style
                          (lambda (&rest _) (cl-incf node-styles)))
                    (cons 'ebox-surface--compute-node-style
                          (lambda (&rest _) (cl-incf style-computations)))
                    (cons 'ebox--render-scroll-window-source
                          (lambda (&rest _) (cl-incf prefix-renders)))
                    (cons 'ebox--scroll-state-materialize-lines
                          (lambda (_region state)
                            ;; The entry point also accepts already-complete
                            ;; state; count only actual producer invocations.
                            (when (plist-get state :materialize-content-lines)
                              (cl-incf materializations))))))
            (advice-add (car entry) :before (cdr entry))
            (push entry installed))
          (setq gc-start gcs-done gc-time-start gc-elapsed)
          (dotimes (index steps)
            (when (> (float-time) deadline)
              (error "Scroll evaluator exceeded 30 seconds after %d/%d samples"
                     index steps))
            (let* ((delta (if (or cold (zerop (% index 2))) 1 -1))
                   (start (float-time))
                   (consumed (ebox--scroll-region-by region-id delta 1)))
              (push (* 1000.0 (- (float-time) start)) samples)
              (unless (equal consumed delta)
                (if cold
                    (error
                     "Cold scroll stopped at sample %d/%d after %d completed steps: moved %S, expected 1 (capacity may be exhausted)"
                     (1+ index) steps index consumed)
                  (error "Scroll evaluator moved %S lines, expected %S"
                         consumed delta)))))
          (list :gc-count (- gcs-done gc-start)
                :gc-ms (* 1000.0 (- gc-elapsed gc-time-start))
                :mean-ms (/ (apply #'+ samples) (float steps))
                :p95-ms (ebox-playground-flex-resize-evaluator--percentile
                         samples 0.95)
                :max-ms (apply #'max samples)
                :root-renders root-renders :node-styles node-styles
                :document-preparations document-preparations
                :surface-plans surface-plans
                :style-computations style-computations
                :prefix-renders prefix-renders :materializations materializations))
      (dolist (entry installed)
        (advice-remove (car entry) (cdr entry))))))

(defun ebox-playground-scroll-evaluator--fresh-parity (buffer file)
  "Compare BUFFER with its committed input at every committed scroll offset.
FILE is retained for caller compatibility; the oracle never reloads source or
recreates the companion's business state, callbacks, or keymaps."
  (ignore file)
  (let* ((state (ebox--buffer-render-state buffer))
         (snapshot (ebox-surface-buffer-snapshot buffer))
         (input (plist-get snapshot :input))
         (ebox-viewport-width (plist-get state :viewport-width))
         (ebox-viewport-height (plist-get state :viewport-height))
         (published-root (plist-get state :root-node))
         (offsets (make-hash-table :test #'eql))
         (source-ids (make-hash-table :test #'eq))
         (rendered-owners (make-hash-table :test #'eql))
         rendered-root
         (set-offsets
          (lambda (root)
            (unless rendered-root
              (when (eq root published-root)
                (error "Fresh scroll oracle reached the published root"))
              (setq rendered-root root)
              ;; Snapshots omit runtime node IDs.  Preserved opaque source
              ;; handles bridge each committed ID to its detached counterpart.
              (cl-labels
                  ((visit (node)
                     (when-let* ((node-id (gethash (ebox-node-source-handle node)
                                                  source-ids)))
                       (when (gethash node-id rendered-owners)
                         (error "Fresh scroll oracle found duplicate owner %s" node-id))
                       (ebox-put node :scroll-offset (gethash node-id offsets))
                       (ebox-put node :ebox-scroll-offset-controlled-p t)
                       (puthash node-id node rendered-owners))
                     (ebox-tree-for-each-direct-child node #'visit)))
                (visit root)))))
         expected)
    (maphash
     (lambda (region scroll-state)
       (let* ((node-id (ebox-runtime-index-get
                       region (plist-get state :region-node-table)))
              (node (and node-id (ebox-runtime-index-get
                                 node-id (plist-get state :node-table))))
              (source (and node (ebox-node-source-handle node)))
              (offset (plist-get scroll-state :scroll-offset)))
         (unless (and source (integerp offset) (>= offset 0)
                      (equal offset (ebox-get node :scroll-offset)))
           (error "Fresh scroll oracle requires a consistent committed offset for region %s"
                  region))
         (when (gethash source source-ids)
           (error "Fresh scroll oracle found ambiguous source for region %s" region))
         (puthash node-id offset offsets)
         (puthash source node-id source-ids)))
     (plist-get state :scroll-state-table))
    ;; Scroll offset is runtime state, not an authorable DSL style property.
    ;; Set it on the independent candidate immediately before its first render.
    (unwind-protect
        (progn
          (advice-add 'ebox--render-layout :before set-offsets)
          (setq expected (ebox-render input))
          (unless (and rendered-root
                       (= (hash-table-count offsets)
                          (hash-table-count rendered-owners)))
            (error "Fresh scroll oracle did not reach every committed scroll owner"))
          (maphash
           (lambda (node-id offset)
             (unless (equal offset (ebox-get (gethash node-id rendered-owners)
                                            :scroll-offset))
               (error "Fresh scroll oracle changed offset for owner %s" node-id)))
           offsets))
      (advice-remove 'ebox--render-layout set-offsets))
    (with-current-buffer buffer
      (let* ((actual (ebox-playground-scroll-evaluator--visual-text
                      (buffer-string)))
             (fresh (ebox-playground-scroll-evaluator--visual-text expected))
             (same (equal-including-properties actual fresh)))
        (unless same
          (ebox-playground-scroll-evaluator--report-mismatch actual fresh))
        same))))

(defun ebox-playground-scroll-evaluator--report-mismatch (actual fresh)
  "Print bounded differences between ACTUAL and FRESH without opaque values.
Report character codes, changed property names, line widths, and face summaries;
never print callback environments or keymap contents."
  (let* ((limit (min (length actual) (length fresh)))
         (position
          (or (cl-loop for index below limit
                       unless (equal-including-properties
                               (substring actual index (1+ index))
                               (substring fresh index (1+ index)))
                       return index)
              limit))
         (left (and (< position (length actual))
                    (text-properties-at position actual)))
         (right (and (< position (length fresh))
                     (text-properties-at position fresh)))
         (keys (delete-dups
                (append (cl-loop for (key _value) on left by #'cddr collect key)
                        (cl-loop for (key _value) on right by #'cddr collect key))))
         (changed (cl-remove-if
                   (lambda (key) (equal (plist-get left key) (plist-get right key)))
                   keys)))
    (cl-labels
        ((bounded (value)
           (let* ((print-level 3) (print-length 8) (print-circle t)
                  (print-escape-newlines t)
                  (text (prin1-to-string value)))
             (if (> (length text) 160) (concat (substring text 0 157) "...") text)))
         (line-width (text)
           (let ((start (or (cl-position ?\n text :end position :from-end t) -1))
                 (end (or (cl-position ?\n text :start position) (length text))))
             (ebox-string-pixel-width (substring text (1+ start) end)))))
      (princ
       (format
        "  render lengths=%d/%d first-difference=%d char-codes=%S/%S changed-properties=%s line-widths=%s/%s faces=%s -> %s\n"
        (length actual) (length fresh) position
        (and (< position (length actual)) (aref actual position))
        (and (< position (length fresh)) (aref fresh position))
        (bounded changed) (line-width actual) (line-width fresh)
        (bounded (plist-get left 'face)) (bounded (plist-get right 'face)))))))

(defun ebox-playground-scroll-evaluator--visual-text (text)
  "Normalize visible TEXT, ignoring identity and inert zero-pixel spacers.
Fresh layout may retain empty padding spaces that materialized scroll content
omits.  Drop one only beside a visible character with identical faces, so line
font metrics are preserved.  Retain height, ascent and alignment carriers."
  (let ((text (ebox-playground-flex-resize-evaluator--visual-text text))
        (start 0) parts)
    (dotimes (index (length text))
      (when (and (= (aref text index) ?\s)
                 (equal (get-text-property index 'display text)
                        '(space :width (0)))
                 (cl-some
                  (lambda (neighbor)
                    (and (<= 0 neighbor) (< neighbor (length text))
                         (/= (aref text neighbor) ?\n)
                         (let ((display (get-text-property neighbor 'display text)))
                           (or (null display)
                               (pcase display
                                 (`(space :width (,width))
                                  (and (numberp width) (> width 0))))))
                         (cl-every
                          (lambda (property)
                            (equal (get-text-property index property text)
                                   (get-text-property neighbor property text)))
                          '(face font-lock-face))))
                  (list (1- index) (1+ index))))
        (push (substring text start index) parts)
        (setq start (1+ index))))
    (push (substring text start) parts)
    (apply #'concat (nreverse parts))))

(defun ebox-playground-interaction-evaluator-click (buffer label &optional offset)
  "Simulate a native mouse-1 at visible LABEL in BUFFER, plus character OFFSET.
This GUI diagnostic resolves the actual text-property keymap with an Emacs
mouse event and invokes its interactive command.  It does not call a business
action directly, move point, select a window or generate an OS mouse event.
Return the clicked position; the caller must verify the application's result."
  (setq buffer (get-buffer buffer) offset (or offset 0))
  (unless (and (buffer-live-p buffer) (stringp label) (> (length label) 0)
               (integerp offset) (<= 0 offset) (< offset (length label)))
    (error "Click diagnostic needs a live buffer, label and in-label offset"))
  (let* ((window (or (get-buffer-window buffer t)
                     (error "Click diagnostic target is not visible")))
         (position
          (with-current-buffer buffer
            (save-excursion
              (goto-char (point-min))
              (unless (search-forward label nil t)
                (error "Click diagnostic label is missing: %s" label))
              (+ (- (point) (length label)) offset))))
         (posn (or (posn-at-point position window)
                   (error "Click diagnostic label is outside the visible window")))
         (event (list 'mouse-1 posn))
         (command (key-binding (vector event)))
         (native (with-current-buffer buffer
                   (get-text-property position 'keymap))))
    (unless (and (keymapp native) (commandp command)
                 (eq command (lookup-key native [mouse-1])))
      (error "Click diagnostic label has no native mouse-1 command"))
    (let ((last-input-event event)) (call-interactively command))
    position))

(defun ebox-playground-interaction-evaluator--cpu-summary (log)
  "Return bounded function names and sample counts from CPU LOG.
Count recursive frames once per stack for inclusive totals.  Anonymous frames
share one name; never format closures or their captured runtime objects."
  (let ((names (make-hash-table :test #'eq))
        (inclusive (make-hash-table :test #'equal))
        (exclusive (make-hash-table :test #'equal))
        (total 0))
    (mapatoms (lambda (symbol)
                (when (fboundp symbol)
                  (puthash (symbol-function symbol) (symbol-name symbol) names))))
    (when log
      (maphash
       (lambda (stack count)
         (cl-incf total count)
         (let (seen)
           (dotimes (index (length stack))
             (when-let* ((frame (aref stack index)))
               (let ((name (if (symbolp frame) (symbol-name frame)
                             (gethash frame names "<anonymous>"))))
                 (when (zerop index)
                   (puthash name (+ count (gethash name exclusive 0)) exclusive))
                 (unless (member name seen)
                   (push name seen)
                   (puthash name (+ count (gethash name inclusive 0)) inclusive)))))))
       log))
    (cl-labels
        ((top (table)
           (let (rows)
             (maphash (lambda (name count)
                        (push (list :function name :samples count
                                    :percent (if (zerop total) 0.0
                                               (/ (* 100.0 count) total))) rows))
                      table)
             (seq-take
              (sort rows
                    (lambda (left right)
                      (let ((a (plist-get left :samples))
                            (b (plist-get right :samples)))
                        (if (= a b)
                            (string-lessp (plist-get left :function)
                                          (plist-get right :function))
                          (> a b)))))
              15))))
      (list :total-samples total :inclusive (top inclusive)
            :exclusive (top exclusive)))))

(defun ebox-playground-interaction-evaluator--activate (binding deadline)
  "Activate native BINDING before DEADLINE and return elapsed milliseconds."
  (when (> (float-time) deadline)
    (error "Interaction evaluator exceeded 30 seconds"))
  (let ((keys (car binding)) (command (cdr binding)))
    (unless (eq (key-binding keys) command)
      (error "Repeated %s lost its node binding at point %d"
             (key-description keys) (point)))
    (let ((started (float-time))
          (last-input-event (aref (vconcat keys) (1- (length keys)))))
      (call-interactively command)
      (* 1000 (- (float-time) started)))))

(defun ebox-playground-interaction-evaluator-run
    (file label &optional key steps width height options)
  "Measure repeated native KEY activation at LABEL in FILE with OPTIONS.
KEY defaults to RET, STEPS to 30, WIDTH to 720 pixels and HEIGHT to 200 lines.
OPTIONS accepts :alternate-key (a second native key), :warmup (a nonnegative
command count, default zero), and :profile (boolean, default nil).  Alternate
KEY and :alternate-key continuously across warmup and measured commands.
Place point at LABEL once, then perform normal key lookup for every command;
fail if an update loses that binding.  Return command timing in milliseconds,
GC counts and time, allocated cons cells, publication count and work counts,
fragment extraction input characters, final plain text and fresh-render parity.
:cpu-profile contains at most 15 inclusive and exclusive function names, sample
counts and percentages plus :total-samples.  Existing profiler logs are kept;
refuse CPU sampling when any profiler is running.  A stopped low-level CPU log
is retained in `profiler-cpu-log' before starting isolated sampling.

This measures synchronous commands and publication, including GC, without
redisplay, OS key repeat or idle prewarming.  Mounting, explicit warmup and
final parity rendering are outside all measurements.  Use current font metrics
and a temporary preview, preserving existing buffers, windows and runtime state.
Cleanup runs on success, error and quit.  Check a 30-second command deadline."
  (setq key (or key "RET") steps (or steps 30)
        width (or width 720) height (or height 200))
  (unless (and (stringp file) (stringp label) (> (length label) 0)
               (or (stringp key) (vectorp key)))
    (error "Interaction evaluator needs a file, nonempty label and native key"))
  (unless (and (proper-list-p options) (zerop (% (length options) 2)))
    (error "Interaction evaluator OPTIONS must be an even property list"))
  (let (seen)
    (cl-loop for (option _value) on options by #'cddr do
             (unless (and (memq option '(:alternate-key :warmup :profile))
                          (not (memq option seen)))
               (error "Interaction evaluator OPTIONS has an unknown or repeated key"))
             (push option seen)))
  (let ((alternate (plist-get options :alternate-key))
        (warmup (if (plist-member options :warmup)
                    (plist-get options :warmup) 0)))
    (unless (and (or (null alternate) (stringp alternate) (vectorp alternate))
                 (integerp warmup) (>= warmup 0)
                 (memq (plist-get options :profile) '(nil t)))
      (error "Interaction evaluator needs a native alternate key, nonnegative warmup and boolean profile")))
  (dolist (value (list steps width height))
    (unless (and (integerp value) (> value 0))
      (error "Interaction evaluator dimensions and steps must be positive integers")))
  (when (plist-get options :profile)
    (unless (fboundp 'profiler-cpu-start)
      (error "CPU sampling is unavailable in this Emacs"))
    (when (profiler-running-p)
      (error "Interaction evaluator cannot sample while a profiler is running")))
  (let* ((keys (if (stringp key) (kbd key) key))
         (alternate (plist-get options :alternate-key))
         (alternate-keys (if (stringp alternate) (kbd alternate) alternate))
         (warmup (or (plist-get options :warmup) 0))
         (profile (plist-get options :profile))
         (buffer (generate-new-buffer " *ebox-interaction-evaluator*"))
         (ebox-viewport-width width) (ebox-viewport-height height)
         (ebox-runtime-idle-prewarm nil)
         (ebox-runtime-idle-reflow-cache-prewarm nil)
         (ebox-scroll-lazy-idle-prefetch-lines 0)
         (gc-cons-threshold gc-cons-threshold)
         (gc-cons-percentage gc-cons-percentage)
         (ebox--deferred-render-gc-state nil)
         (ebox--deferred-render-gc-timer nil)
         (ebox--deferred-render-gc-depth 0)
         (ebox--deferred-render-gc-generation 0)
         (work (list :layout-calls 0 :surface-plans 0 :full-surface-renders 0
                     :fragment-scans 0 :fragment-characters 0
                     :node-registrations 0))
         samples installed profile-owned profile-log)
    (unwind-protect
        (progn
          (dolist (sequence (if alternate-keys (list keys alternate-keys) (list keys)))
            (when (zerop (length sequence))
              (error "Interaction evaluator key must not be empty")))
          (ebox-playground-open-file file (buffer-name buffer))
          (with-current-buffer buffer
            (goto-char (point-min))
            (unless (search-forward label nil t)
              (error "Interaction label is not visible: %s" label))
            (backward-char (length label))
            (let* ((bindings
                    (mapcar
                     (lambda (sequence)
                       (let ((command (key-binding sequence))
                             (native (get-text-property (point) 'keymap)))
                         (unless (and (keymapp native) (commandp command)
                                      (eq command (lookup-key native sequence)))
                           (error "Interaction label has no native command for %s"
                                  (key-description sequence)))
                         (cons sequence command)))
                     (if alternate-keys (list keys alternate-keys) (list keys))))
                   (deadline (+ (float-time) 30)) revision)
              (dotimes (index warmup)
                (ebox-playground-interaction-evaluator--activate
                 (nth (% index (length bindings)) bindings) deadline))
              (dolist (entry '((ebox--render-layout . :layout-calls)
                               (ebox-surface--surface-plan . :surface-plans)
                               (ebox-surface--render-candidate . :full-surface-renders)
                               (ebox-surface--ensure-node-tree . :node-registrations)))
                (let* ((counter (cdr entry))
                       (advice (lambda (&rest _)
                                 (cl-incf (plist-get work counter)))))
                  (advice-add (car entry) :before advice)
                  (push (cons (car entry) advice) installed)))
              (let ((advice
                     (lambda (text)
                       (cl-incf (plist-get work :fragment-scans))
                       (cl-incf (plist-get work :fragment-characters) (length text)))))
                (advice-add 'ebox-surface--rendered-fragments :before advice)
                (push (cons 'ebox-surface--rendered-fragments advice) installed))
              (setq revision
                    (plist-get (ebox-surface-buffer-snapshot buffer) :revision))
              (when profile
                (when (profiler-running-p)
                  (error "Interaction evaluator cannot sample while a profiler is running"))
                ;; Low-level stop retains a pending C log.  Move it to the
                ;; ordinary report variable, preserving any previous samples.
                (when-let* ((pending (profiler-cpu-log)))
                  (let ((saved (if profiler-cpu-log
                                   (copy-hash-table profiler-cpu-log)
                                 (make-hash-table :test #'equal))))
                    (maphash (lambda (stack count)
                               (puthash stack (+ count (gethash stack saved 0)) saved))
                             pending)
                    (setq profiler-cpu-log saved)))
                (let ((inhibit-quit t))
                  (setq profile-owned t)
                  (profiler-cpu-start profiler-sampling-interval)))
              (let ((gc-count gcs-done) (gc-time gc-elapsed)
                    (cons-count (car (memory-use-counts))))
                (dotimes (index steps)
                  (push (ebox-playground-interaction-evaluator--activate
                         (nth (% (+ warmup index) (length bindings)) bindings) deadline)
                        samples))
                (setq cons-count (- (car (memory-use-counts)) cons-count)
                      gc-count (- gcs-done gc-count)
                      gc-time (* 1000 (- gc-elapsed gc-time)))
                (when profile-owned
                  (profiler-cpu-stop)
                  (setq profile-log (profiler-cpu-log) profile-owned nil))
                (dolist (entry installed) (advice-remove (car entry) (cdr entry)))
                (setq installed nil)
                (let* ((snapshot (ebox-surface-buffer-snapshot buffer))
                       (update (ebox-buffer-update-report buffer))
                       (last-update
                        (cl-loop for field in '(:strategy :projection-kind
                                               :publication-scope :constraint-source)
                                 for value = (plist-get update field)
                                 when (or (symbolp value) (numberp value))
                                 append (list field value)))
                       (fresh (ebox-render (plist-get snapshot :input)))
                       (actual (buffer-string))
                       (parity (equal-including-properties
                                (ebox-playground-scroll-evaluator--visual-text actual)
                                (ebox-playground-scroll-evaluator--visual-text fresh))))
                  (unless parity
                    (error "Repeated interaction differs from committed snapshot render"))
                  (append
                   (list :file (expand-file-name file) :label label
                         :key (key-description keys)
                         :alternate-key (and alternate-keys (key-description alternate-keys))
                         :warmup warmup :steps steps
                         :mean-ms (/ (apply #'+ samples) (float steps))
                         :p95-ms (ebox-playground-flex-resize-evaluator--percentile samples 0.95)
                         :max-ms (apply #'max samples)
                         :gc-count gc-count :gc-ms gc-time :cons-cells cons-count
                         :publications (- (plist-get snapshot :revision) (or revision 0))
                         :last-update last-update
                         :fresh-parity parity :text (substring-no-properties actual))
                   (when profile
                     (list :cpu-profile
                           (append (list :sampling-interval-ns profiler-sampling-interval)
                                   (ebox-playground-interaction-evaluator--cpu-summary
                                    profile-log))))
                   work))))))
      (when profile-owned
        (profiler-cpu-stop)
        (profiler-cpu-log))
      (dolist (entry installed) (advice-remove (car entry) (cdr entry)))
      (when (buffer-live-p buffer) (ebox-playground-close (buffer-name buffer)))
      (when (timerp ebox--deferred-render-gc-timer)
        (cancel-timer ebox--deferred-render-gc-timer)))))

(defun ebox-playground-scroll-evaluator--max-offset (state)
  "Return STATE's final maximum offset, or nil for an incomplete lazy prefix."
  (when (or (plist-get state :content-lines-complete-p)
            (not (or (plist-get state :render-content-prefix)
                     (plist-get state :materialize-content-lines))))
    (max 0 (- (length (plist-get state :content-lines))
              (plist-get state :content-height)))))

(defun ebox-playground-scroll-evaluator-run
    (files &optional width steps height options)
  "Profile scrolling for FILES at WIDTH with STEPS, HEIGHT, and OPTIONS.
FILES is one `.ebox' path or a list of paths.  WIDTH defaults to 720 pixels,
STEPS to 20 alternating one-line motions, and HEIGHT to 36 viewport lines.
OPTIONS accepts :region-id, an author semantic ID resolved in each mount,
and :cold, either t or nil.  An omitted or nil ID selects the root.  Runtime
numeric region metadata is not accepted as an address; integer IDs mean author
IDs.  The selected node must be scrollable.

By default fully materialize selected content outside the samples, then measure
cached top and midpoint motion.  With :cold t, measure only forward one-line
motion from the initial mounted offset, with no explicit prewarming,
materialization, or seek.  Signal an error identifying the failed sample if
capacity runs out before STEPS completes; do not report incomplete success.

Return bounded plists with :mode, semantic :region-id, :start-offset,
:end-offset, :content-complete-p, timings, full root render counts, node style
visits, style computations, and fresh-render parity for each position.
:prefix-renders counts calls to the bounded scroll source renderer;
:materializations counts full-content producer invocations during samples.
:document-preparations counts general scoped document preparation;
:surface-plans counts construction of full surface publication plans.
:position is top/middle for cached samples or cold for advancing samples.
:max-offset is nil unless the selected content is fully materialized.
The oracle independently renders the committed snapshot, preserving opaque
callbacks and keymaps, and reapplies every committed scroll owner's offset.
Signal an error on missing scroll capacity, incomplete motion or render drift.

Use the current Emacs frame's font metrics without displaying temporary
buffers or changing windows.  This measures retained TP publication; native
window scrolling, idle prewarming and redisplay are excluded.  Existing live
buffers, timers and runtime tables are preserved.  Temporary mounts and advice
are cleaned on success, error or quit; no global runtime reset is performed.
Each sample loop checks a 30-second deadline between motions."
  (setq files (if (stringp files) (list files) files)
        width (or width 720) steps (or steps 20) height (or height 36))
  (unless (and files (proper-list-p files) (cl-every #'stringp files))
    (error "Scroll evaluator needs a file path or nonempty list of paths"))
  (unless (and (proper-list-p options) (zerop (% (length options) 2)))
    (error "Scroll evaluator OPTIONS must be an even property list"))
  (let (seen)
    (cl-loop for (key _value) on options by #'cddr do
             (unless (and (memq key '(:region-id :cold)) (not (memq key seen)))
               (error "Scroll evaluator OPTIONS has an unknown or repeated key"))
             (push key seen)))
  (unless (and (memq (plist-get options :cold) '(nil t))
               (let ((id (plist-get options :region-id)))
                 (or (null id) (stringp id) (symbolp id) (integerp id))))
    (error "Scroll evaluator needs a semantic :region-id and boolean :cold"))
  (dolist (value (list width steps height))
    (unless (and (integerp value) (> value 0))
      (error "Scroll evaluator dimensions and steps must be positive integers")))
  (let ((selected-id (plist-get options :region-id))
        (cold (plist-get options :cold))
        (ebox-viewport-width width)
        (ebox-viewport-height height)
        (ebox-native-buffer-scroll nil)
        (ebox-runtime-idle-prewarm nil)
        (ebox-runtime-idle-reflow-cache-prewarm nil)
        (ebox-scroll-lazy-idle-prefetch-lines 0)
        ;; Isolate the GUI deferred-GC lease, including any timer it creates.
        (gc-cons-threshold gc-cons-threshold)
        (gc-cons-percentage gc-cons-percentage)
        (ebox--deferred-render-gc-state nil)
        (ebox--deferred-render-gc-timer nil)
        (ebox--deferred-render-gc-depth 0)
        (ebox--deferred-render-gc-generation 0)
        results)
    (unwind-protect
        (dolist (file files)
          (let ((buffer (generate-new-buffer " *ebox-scroll-evaluator*")))
            (unwind-protect
                (progn
                  (ebox-playground-open-file file (buffer-name buffer))
                  (with-current-buffer buffer
                    (let* ((runtime (ebox--buffer-render-state buffer))
                           (region-id
                            (if selected-id
                                (cdr (ebox-selector--region-target
                                      (ebox-region-resolve buffer selected-id)))
                              (plist-get (plist-get runtime :root-node) :region-id)))
                           (table (plist-get runtime :scroll-state-table))
                           (state (and region-id (gethash region-id table)))
                           max-offset)
                      (unless state
                        (error "Scroll evaluator requires a scrollable selected owner: %s"
                               file))
                      (unless cold
                        (setq state (ebox--scroll-state-materialize-lines
                                     region-id state))
                        (puthash region-id state table)
                        (setq max-offset
                              (ebox-playground-scroll-evaluator--max-offset state))
                        (unless max-offset
                          (error "Scroll evaluator could not materialize selected content"))
                        (unless (> max-offset 0)
                          (error "Scroll evaluator selected owner has no scroll capacity: %s"
                                 file))
                        ;; Publish warmed content before measuring cached motion.
                        (ebox--scroll-region-by region-id 1 1)
                        (ebox--scroll-region-by region-id -1 1))
                      (dolist (position (if cold '(cold) '(top middle)))
                        (unless cold
                          (ebox--surface-scroll-to-offset
                           buffer region-id
                           (if (eq position 'top) 0 (/ max-offset 2))))
                        (let* ((start-offset
                                (plist-get (ebox--scroll-get-state region-id)
                                           :scroll-offset))
                               (measurement
                                (ebox-playground-scroll-evaluator--measure
                                 region-id steps cold))
                               (final-state (ebox--scroll-get-state region-id))
                               (final-max-offset
                                (ebox-playground-scroll-evaluator--max-offset final-state))
                               (parity
                                (ebox-playground-scroll-evaluator--fresh-parity
                                 buffer file))
                               (result
                                (append
                                 (list :file (expand-file-name file)
                                       :width width :height height :steps steps
                                       :region-id selected-id :mode (if cold 'cold 'cached)
                                       :position position
                                       :start-offset start-offset
                                       :end-offset (plist-get final-state :scroll-offset)
                                       :content-complete-p (numberp final-max-offset)
                                       :max-offset final-max-offset
                                       :fresh-render-parity parity)
                                 measurement)))
                          (princ
                           (format
                            "%s scroll %s %s mean=%.3fms p95=%.3fms max=%.3fms gc=%d/%.3fms roots=%d document-preparations=%d surface-plans=%d node-styles=%d style-computations=%d prefix-renders=%d materializations=%d parity=%S\n"
                            (if parity "PASS" "FAIL")
                            (file-name-nondirectory file) position
                            (plist-get measurement :mean-ms)
                            (plist-get measurement :p95-ms)
                            (plist-get measurement :max-ms)
                            (plist-get measurement :gc-count)
                            (plist-get measurement :gc-ms)
                            (plist-get measurement :root-renders)
                            (plist-get measurement :document-preparations)
                            (plist-get measurement :surface-plans)
                            (plist-get measurement :node-styles)
                            (plist-get measurement :style-computations)
                            (plist-get measurement :prefix-renders)
                            (plist-get measurement :materializations) parity))
                          (push result results)
                          (unless parity
                            (error "Scroll evaluator fresh-render mismatch: %s %s"
                                   file position)))))))
              (when (buffer-live-p buffer)
                (kill-buffer buffer)))))
      (when (timerp ebox--deferred-render-gc-timer)
        (cancel-timer ebox--deferred-render-gc-timer)))
    (nreverse results)))

(defun ebox-playground-flex-resize-evaluator--settle-preview
    (preview preview-window)
  "Publish PREVIEW at its settled PREVIEW-WINDOW viewport before measuring.
The GUI frame can acquire its final pixel width after
`ebox-playground-render' has mounted the split.  This setup publication is
outside the measured splitter
action, so the action starts from a self-consistent runtime generation rather
than charging initial frame settling to resize."
  (let* ((width (ebox-playground--window-viewport-width preview-window))
         (report (ebox-buffer-update-report preview))
         (published-width (and report
                               (or (plist-get report :target-viewport-width)
                                   (plist-get report :viewport-width)))))
    (unless (numberp width)
      (error "flex preview has no settled viewport width"))
    (when (not (equal width published-width))
      (let ((report (ebox-rerender-buffer-with-context preview width)))
        (unless (plist-get report :runtime-published)
          (error "flex preview initial viewport was not published"))))
    width))

(defun ebox-playground-flex-resize-evaluator-run ()
  "Run the real GUI flex preview resize evaluator.

The function returns non-nil only when a sustained splitter resize burst uses
Ebox's immediate serialized viewport hook, publishes every intermediate and
final result through the retained path, and stays under the timing threshold.
It leaves the normal idle prewarm configuration untouched; the daemon evaluator
does not enable background prewarm, keeping the measured action free of
concurrent cache warming CPU work."
  (let ((ebox-render-gc-cons-threshold nil)
        (ebox-render-gc-cons-percentage nil)
        (source nil)
        (preview nil)
        (preview-window nil)
        (warmup-publications 0)
        (resize-count 0)
        (resize-finished nil)
        (action-start nil)
        (last-event-elapsed nil)
        (resize-publications nil)
        (publication-durations nil)
        (requested-widths nil)
        (accepted-widths nil)
        (observer nil)
        (native-report nil)
        (playground-library (symbol-file 'ebox-playground-open 'defun))
        (evaluator-library
         (symbol-file 'ebox-playground-flex-resize-evaluator-run 'defun))
        (completed-without-error nil)
        (ebox-playground-flex-resize-evaluator--output-lines nil)
        (checks nil))
    (condition-case-unless-debug error-data
        (progn
          (delete-other-windows)
          (setq native-report (ebox-native-reflow-runtime-report))
          (unless (plist-get native-report :layout-ready-p)
            (error "Flex evaluator requires the prepared native layout module"))
          (unless (file-readable-p
                   ebox-playground-flex-resize-evaluator-fixture)
            (error "Flex evaluator fixture is not readable: %s"
                   ebox-playground-flex-resize-evaluator-fixture))
          (setq source
                (find-file ebox-playground-flex-resize-evaluator-fixture))
          (ebox-playground-mode)
          (setq preview (ebox-playground-render)
                preview-window (get-buffer-window preview (selected-frame)))
          (unless (and (buffer-live-p preview)
                       (window-live-p preview-window))
            (error "flex preview was not mounted in a window"))
          (redisplay t)
          (sleep-for 0.2)
          (ebox-playground-flex-resize-evaluator--settle-preview
           preview preview-window)
          (redisplay t)
          (sleep-for 0.2)
          ;; Observe only accepted, completed Ebox publications.  TP emits its
          ;; paired report first; filtering by provider keeps this evaluator on
          ;; the public Ebox boundary and avoids timing/advising the rerender
          ;; implementation itself.
          (setq observer
                (lambda (_buffer report)
                  (when (and (eq (plist-get report :provider) 'ebox)
                             (eq (plist-get report :stage) 'viewport))
                    (setq resize-count (1+ resize-count)
                          resize-finished t)
                    (when action-start
                      (push (- (float-time) action-start)
                            resize-publications))
                    (push (/ (or (plist-get report :duration-ms) 0.0)
                             1000.0)
                          publication-durations)
                    (push (or (plist-get report :target-viewport-width)
                              (plist-get report :viewport-width))
                          accepted-widths))))
          (ebox-buffer-set-observer preview observer)
          (dotimes (index ebox-playground-flex-resize-evaluator-warmup-count)
            (window-resize preview-window (if (zerop (% index 2)) -1 1) t)
            (redisplay t)
            (sleep-for 0.01))
          (setq warmup-publications resize-count
                resize-count 0
                resize-finished nil
                resize-publications nil
                publication-durations nil
                requested-widths nil
                accepted-widths nil)
          (let* ((start (float-time))
                 (old-width
                  (ebox-playground--window-viewport-width preview-window)))
            (setq action-start start)
            (dotimes (index ebox-playground-flex-resize-evaluator-sample-count)
              (let ((delta
                     (if (< index 28)
                         (if (zerop (% index 2)) -1 1)
                       -1)))
                (setq last-event-elapsed (- (float-time) start))
                (window-resize preview-window delta t)
                (push (ebox-playground--window-viewport-width preview-window)
                      requested-widths)
                (redisplay t)
                (sleep-for 0.01)))
            (let* ((elapsed (- (float-time) start))
                   (publication-times
                    (sort (copy-sequence resize-publications) #'<))
                   (publication-gaps
                    (cl-loop for tail on publication-times
                             while (cdr tail)
                             collect (- (cadr tail) (car tail))))
                   (first-publication (car publication-times))
                   (last-publication (car (last publication-times)))
                   (max-publication
                    (if publication-durations
                        (apply #'max publication-durations)
                      0.0))
                   (p95-publication
                    (if publication-durations
                        (ebox-playground-flex-resize-evaluator--percentile
                         publication-durations 0.95)
                      0.0))
                   (max-gap
                    (if publication-gaps (apply #'max publication-gaps) 0.0))
                   (final-latency
                    (and last-publication
                         (- last-publication last-event-elapsed)))
                   (viewport-width
                    (ebox-playground--window-viewport-width preview-window))
                   (report (ebox-buffer-update-report preview))
                   (projection-kind (plist-get report :projection-kind))
                   (expected-widths (nreverse requested-widths))
                   (published-widths (nreverse accepted-widths))
                   (line-widths
                    (ebox-playground-flex-resize-evaluator--line-widths
                     preview))
                   (background
                    (with-current-buffer preview
                      face-remapping-alist))
                   (max-line-width (if line-widths
                                      (apply #'max line-widths)
                                    0))
                   (fresh-rendered
                    (and (numberp viewport-width)
                         (let ((ebox-viewport-width viewport-width)
                               ;; Compare the published visible scroll
                               ;; window with a fresh render at the same
                               ;; viewport height.  Omitting this binding
                               (ebox-viewport-height
                                (or (plist-get report
                                               :target-viewport-height)
                                    (plist-get report :viewport-height)
                                    36)))
                           (ebox-render
                            (ebox-playground-view
                             ebox-playground-flex-resize-evaluator-fixture
                             viewport-width)))))
                   (fresh-render-matches-p
                    (and (stringp fresh-rendered)
                         (with-current-buffer preview
                           (equal-including-properties
                            (ebox-playground-flex-resize-evaluator--visual-text
                             (buffer-string))
                            (ebox-playground-flex-resize-evaluator--visual-text
                             fresh-rendered)))))
                   (tp-operations (plist-get report :tp-operation-count))
                   (projection-retained-p
                    (and (memq projection-kind
                               '(viewport-reflow
                                 viewport-reflow-mixed-scroll))
                         (not (plist-get report :tp-full-root))
                         (not (plist-get report :tp-scope-fallback)))))
              (setq checks
                    (list
                     (ebox-playground-flex-resize-evaluator--check
                      "compiled evaluator artifacts"
                      (and (stringp playground-library)
                           (string-suffix-p ".elc" playground-library)
                           (stringp evaluator-library)
                           (string-suffix-p ".elc" evaluator-library))
                      (format "playground=%S evaluator=%S"
                              playground-library evaluator-library))
                     (ebox-playground-flex-resize-evaluator--check
                      "native module prepared"
                      (plist-get native-report :layout-ready-p)
                      (format "path=%S hash=%S"
                              (plist-get native-report :loaded-module-path)
                              (plist-get native-report :loaded-module-hash)))
                     (ebox-playground-flex-resize-evaluator--check
                      "preview mounted"
                      (and (buffer-live-p preview)
                           (window-live-p preview-window))
                      (format "source=%S preview=%S" source preview))
                     (ebox-playground-flex-resize-evaluator--check
                      "warmup publications"
                      (= warmup-publications
                         ebox-playground-flex-resize-evaluator-warmup-count)
                      (format "warmups=%d expected=%d"
                              warmup-publications
                              ebox-playground-flex-resize-evaluator-warmup-count))
                     (ebox-playground-flex-resize-evaluator--check
                      "intermediate resize updates"
                      (and (= resize-count
                              ebox-playground-flex-resize-evaluator-sample-count)
                           (= resize-count (length expected-widths))
                           first-publication
                           (<= first-publication
                               ebox-playground-flex-resize-evaluator-max-update-seconds)
                           (< first-publication last-event-elapsed))
                      (format "updates=%d samples=%d first=%.6fs last-event=%.6fs"
                              resize-count
                              ebox-playground-flex-resize-evaluator-sample-count
                              (or first-publication 0.0)
                              last-event-elapsed))
                     (ebox-playground-flex-resize-evaluator--check
                      "per-update p95 budget"
                      (<= p95-publication
                          ebox-playground-flex-resize-evaluator-max-update-seconds)
                      (format "p95=%.6fs threshold=%.6fs"
                              p95-publication
                              ebox-playground-flex-resize-evaluator-max-update-seconds))
                     (ebox-playground-flex-resize-evaluator--check
                      "per-update max budget"
                      (<= max-publication
                          ebox-playground-flex-resize-evaluator-max-update-seconds)
                      (format "max=%.6fs threshold=%.6fs"
                              max-publication
                              ebox-playground-flex-resize-evaluator-max-update-seconds))
                     (ebox-playground-flex-resize-evaluator--check
                      "continuous resize cadence"
                      (<= max-gap
                          ebox-playground-flex-resize-evaluator-max-gap-seconds)
                      (format "max-gap=%.6fs threshold=%.6fs"
                              max-gap
                              ebox-playground-flex-resize-evaluator-max-gap-seconds))
                     (ebox-playground-flex-resize-evaluator--check
                      "final resize latency"
                      (and final-latency
                           (>= final-latency 0)
                           (<= final-latency
                               ebox-playground-flex-resize-evaluator-max-update-seconds))
                      (format "final=%.6fs threshold=%.6fs"
                              (or final-latency -1.0)
                              ebox-playground-flex-resize-evaluator-max-update-seconds))
                     (ebox-playground-flex-resize-evaluator--check
                      "resize completed"
                      resize-finished
                      (format "elapsed=%.6fs" elapsed))
                     (ebox-playground-flex-resize-evaluator--check
                      "viewport was published"
                      (and (numberp viewport-width)
                           (not (equal old-width viewport-width))
                           (cl-every #'numberp published-widths)
                           (equal expected-widths published-widths)
                           (equal viewport-width (car (last published-widths)))
                           (eq (plist-get report :constraint-source)
                               'viewport)
                           (plist-get report :runtime-published))
                      (format "viewport=%S expected=%S accepted=%S strategy=%S"
                              viewport-width expected-widths published-widths
                              (plist-get report :strategy)))
                     (ebox-playground-flex-resize-evaluator--check
                      "retained viewport projection"
                      projection-retained-p
                      (format "projection=%S axes=%S reconciled=%S full-root=%S scope-fallback=%S"
                              projection-kind
                              (plist-get report :viewport-axes)
                              (plist-get report :reconciled-objects)
                              (plist-get report :tp-full-root)
                              (plist-get report :tp-scope-fallback)))
                     (ebox-playground-flex-resize-evaluator--check
                      "rendered output matches a fresh viewport render"
                      fresh-render-matches-p
                      (format "max-line-width=%d viewport=%S fresh-length=%S"
                              max-line-width viewport-width
                              (and fresh-rendered
                                   (length fresh-rendered))))
                     (ebox-playground-flex-resize-evaluator--check
                      "canvas background is preserved"
                      (equal background
                             '((default (:background "#FAF7F0"))) )
                      (format "face-remapping=%S" background))
                     (ebox-playground-flex-resize-evaluator--check
                      "bounded resize burst"
                      (<= elapsed
                          ebox-playground-flex-resize-evaluator-max-seconds)
                      (format "elapsed=%.6fs threshold=%.6fs"
                              elapsed
                              ebox-playground-flex-resize-evaluator-max-seconds))))
              (push (format
                     "RESIZE warmups=%d samples=%d old-viewport-px=%S new-viewport-px=%S total=%.6fs p95-update=%.6fs max-update=%.6fs first=%.6fs max-gap=%.6fs final=%.6fs strategy=%S projection=%S axes=%S reconciled=%S tp-ops=%S cache-hits=%S cache-misses=%S"
                     warmup-publications resize-count old-width viewport-width
                     elapsed p95-publication max-publication
                     (or first-publication 0.0) max-gap
                     (or final-latency -1.0)
                     (plist-get report :strategy) projection-kind
                     (plist-get report :viewport-axes)
                     (plist-get report :reconciled-objects)
                     tp-operations
                     (plist-get report :cache-hit-count)
                     (plist-get report :cache-miss-count))
                    ebox-playground-flex-resize-evaluator--output-lines)
              (setq completed-without-error t)
              (and resize-finished
                   (cl-every #'identity checks)))))
      (error
       (push (format "FAIL evaluator error -- %S" error-data)
             ebox-playground-flex-resize-evaluator--output-lines)
       nil)
      (quit
       (push "FAIL evaluator interrupted"
             ebox-playground-flex-resize-evaluator--output-lines)
       nil))
    (when (and (buffer-live-p preview) observer)
      (ebox-buffer-set-observer preview nil))
    (when (buffer-live-p preview)
      (kill-buffer preview))
    (when (buffer-live-p source)
      (kill-buffer source))
    (let ((passed (and completed-without-error
                       (not (null checks))
                       (cl-every #'identity checks))))
      (push (if passed
                "FLEX-RESIZE-EVALUATOR PASS"
              "FLEX-RESIZE-EVALUATOR FAIL")
            ebox-playground-flex-resize-evaluator--output-lines)
      (mapconcat #'identity
                 (nreverse ebox-playground-flex-resize-evaluator--output-lines)
                 "\n"))))

(provide 'ebox-playground-flex-resize-evaluator)

;;; ebox-playground-flex-resize-evaluator.el ends here
