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

(defconst ebox-playground-flex-resize-evaluator--fixture
  (expand-file-name "examples/flex-reference.ebox"
                    ebox-playground-directory)
  "Flex fixture used by the performance evaluator.")

(defcustom ebox-playground-flex-resize-evaluator-max-seconds 0.5
  "Maximum allowed end-to-end time for one settled preview resize."
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

(defconst ebox-playground-flex-resize-evaluator--runtime-properties
  (delete-dups
   (append (mapcar #'cdr ebox-region-types)
           '(ebox-content-idx ebox-content-owners ebox-scroll-window)))
  "Ebox identity properties omitted from fresh-render comparison.")

(defun ebox-playground-flex-resize-evaluator--preview-buffer ()
  "Return the preview buffer for the fixed flex fixture."
  (get-buffer
   (format "*Ebox Preview: %s*"
           ebox-playground-flex-resize-evaluator--fixture)))

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
         (state (and (buffer-live-p preview)
                     (ebox--buffer-render-state preview)))
         (published-width (and state (plist-get state :viewport-width))))
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
        (resize-advice nil)
        (resize-count 0)
        (resize-elapsed 0.0)
        (resize-finished nil)
        (action-start nil)
        (last-event-elapsed nil)
        (resize-publications nil)
        (resize-durations nil)
        (completed-without-error nil)
        (ebox-playground-flex-resize-evaluator--output-lines nil)
        (checks nil))
    (condition-case error-data
        (progn
          (delete-other-windows)
          (setq source
                (find-file ebox-playground-flex-resize-evaluator--fixture))
          (ebox-dsl-mode)
          (ebox-dsl-render)
          (setq preview
                (ebox-playground-flex-resize-evaluator--preview-buffer)
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
          (setq resize-advice
                (lambda (original &rest arguments)
                  (setq resize-count (1+ resize-count))
                  (let ((start (float-time)))
                    (unwind-protect
                        (apply original arguments)
                      (let ((duration (- (float-time) start)))
                        (setq resize-elapsed (+ resize-elapsed duration))
                        (push duration resize-durations))
                      (when action-start
                        (push (- (float-time) action-start)
                              resize-publications))
                      (setq resize-finished t)))))
          (advice-add 'ebox-rerender-buffer-with-context
                      :around resize-advice)
          (let* ((start (float-time))
                 (old-width
                  (ebox-playground--window-viewport-width preview-window)))
            (setq action-start start)
            (dolist (delta '(-4 2 -4 2 -4 2))
              (setq last-event-elapsed (- (float-time) start))
              (window-resize preview-window delta t)
              (redisplay t)
              (sleep-for 0.02))
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
                    (if resize-durations (apply #'max resize-durations) 0.0))
                   (max-gap
                    (if publication-gaps (apply #'max publication-gaps) 0.0))
                   (final-latency
                    (and last-publication
                         (- last-publication last-event-elapsed)))
                   (viewport-width
                    (ebox-playground--window-viewport-width preview-window))
                   (report (ebox-buffer-update-report preview))
                   (projection-kind (plist-get report :projection-kind))
                   (native-flex-calls
                    (and (boundp
                          'ebox-native-reflow--flex-geometry-call-count)
                         ebox-native-reflow--flex-geometry-call-count))
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
                               ;; rendered the entire lazy document and made
                               ;; every correct retained resize look unequal.
                               (ebox-viewport-height
                                (or (plist-get
                                     (ebox--buffer-render-state preview)
                                     :viewport-height)
                                    36)))
                           (ebox-render
                            (ebox-playground-view
                             ebox-playground-flex-resize-evaluator--fixture
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
                      "preview mounted"
                      (and (buffer-live-p preview)
                           (window-live-p preview-window))
                      (format "source=%S preview=%S" source preview))
                     (ebox-playground-flex-resize-evaluator--check
                      "intermediate resize updates"
                      (and (>= resize-count 4)
                           first-publication
                           (<= first-publication
                               ebox-playground-flex-resize-evaluator-max-update-seconds)
                           (< first-publication last-event-elapsed))
                      (format "updates=%d first=%.6fs last-event=%.6fs"
                              resize-count
                              (or first-publication 0.0)
                              last-event-elapsed))
                     (ebox-playground-flex-resize-evaluator--check
                      "per-update resize budget"
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
                           (eq (plist-get report :constraint-source)
                               'viewport)
                           (plist-get report :runtime-published))
                      (format "viewport=%S strategy=%S"
                              viewport-width (plist-get report :strategy)))
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
                      "resize is millisecond-scale"
                      (<= elapsed
                          ebox-playground-flex-resize-evaluator-max-seconds)
                      (format "elapsed=%.6fs threshold=%.6fs"
                              elapsed
                              ebox-playground-flex-resize-evaluator-max-seconds))))
              (push (format
                     "RESIZE old-viewport-px=%S new-viewport-px=%S total=%.6fs rerender=%.6fs first=%.6fs max-update=%.6fs max-gap=%.6fs final=%.6fs strategy=%S projection=%S axes=%S reconciled=%S native-flex=%S tp-ops=%S cache-hits=%S cache-misses=%S"
                     old-width viewport-width elapsed resize-elapsed
                     (or first-publication 0.0) max-publication max-gap
                     (or final-latency -1.0)
                     (plist-get report :strategy) projection-kind
                     (plist-get report :viewport-axes)
                     (plist-get report :reconciled-objects)
                     native-flex-calls tp-operations
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
    (when resize-advice
      (advice-remove 'ebox-rerender-buffer-with-context resize-advice))
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
