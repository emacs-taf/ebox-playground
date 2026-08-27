;;; ebox-playground-flex-resize-evaluator.el --- Flex resize evaluator -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; This evaluator exercises the public playground path used by an interactive
;; `.ebox' preview: source buffer on the left, rendered buffer on the right,
;; and a sustained window-resize burst that reaches
;; `window-size-change-functions'.

;;; Code:

(require 'cl-lib)
(require 'ebox-playground)
(require 'ebox-native-reflow)

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
           '(ebox-content-idx ebox-content-owners ebox-scroll-window)))
  "Ebox identity properties omitted from fresh-render comparison.")

(defun ebox-playground-flex-resize-evaluator--line-widths (buffer)
  "Return pixel widths for every rendered line in BUFFER."
  (with-current-buffer buffer
    (mapcar #'ebox-string-pixel-width
            (ebox-string-lines (buffer-string)))))

(defun ebox-playground-flex-resize-evaluator--visual-text (text)
  "Return TEXT with fresh-render identity properties removed.
Fresh renders allocate different region ids by design.  Keep character,
face, display, and all non-runtime properties so the comparison still checks
the visible right-hand surface rather than merely checking that rendering
completed."
  (let ((copy (copy-sequence text)))
    (when (> (length copy) 0)
      (remove-list-of-text-properties
       0 (length copy)
       ebox-playground-flex-resize-evaluator--runtime-properties
       copy))
    copy))

(defun ebox-playground-flex-resize-evaluator--check (name condition detail)
  "Record a named check and return whether CONDITION passed."
  (push (format "%s %s -- %s"
                (if condition "PASS" "FAIL") name detail)
        ebox-playground-flex-resize-evaluator--output-lines)
  condition)

(defun ebox-playground-flex-resize-evaluator--settle-preview
    (preview preview-window)
  "Publish PREVIEW at its settled PREVIEW-WINDOW viewport before measuring.
The GUI frame can acquire its final pixel width after `ebox-dsl-render' has
mounted the split.  This setup publication is outside the measured splitter
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
          (ebox-dsl-mode)
          (setq preview (ebox-dsl-render)
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
