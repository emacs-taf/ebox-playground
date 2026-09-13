;;; ebox-playground-size-tests.el --- Size reference contracts -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep the Size reference executable and verify declarations, arithmetic,
;; and viewport updates instead of treating descriptive labels as coverage.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'ebox-playground)
(require 'ebox)
(require 'ebox-playground-flex-resize-evaluator
         (expand-file-name "benchmarks/ebox-playground-flex-resize-evaluator.el"
                           ebox-playground-directory))

(defconst ebox-playground-size-test--file
  (expand-file-name "examples/size-reference.ebox" ebox-playground-directory)
  "Size reference checked by this suite.")

(defun ebox-playground-size-test--form ()
  "Read the actual Size example through the ordinary file boundary."
  (ebox-playground--evaluate-form
   (ebox-playground--read-file ebox-playground-size-test--file)))

(defun ebox-playground-size-test--lists (form)
  "Return the nonempty lists recursively contained in FORM."
  (when (consp form)
    (cons form (cl-mapcan #'ebox-playground-size-test--lists form))))

(defun ebox-playground-size-test--nodes (form)
  "Return actual DSL nodes in FORM, excluding size expressions."
  (cl-remove-if-not
   (lambda (item) (memq (car item) '(box text row column flex grid)))
   (ebox-playground-size-test--lists form)))

(defun ebox-playground-size-test--node (id)
  "Return the actual demonstration node named ID."
  (or (cl-find-if
       (lambda (node) (equal (format "%s" (plist-get (cdr node) :id)) id))
       (ebox-playground-size-test--nodes (ebox-playground-size-test--form)))
      (ert-fail (format "Missing Size demonstration: %s" id))))

(defun ebox-playground-size-test--card (id)
  "Return the authored outer card containing demonstration ID."
  (or (cl-find-if
       (lambda (node)
         (and (eq (car node) 'column)
              (plist-get (cdr node) :border)
              (cl-some (lambda (child)
                         (equal (plist-get (cdr child) :id) id))
                       (ebox-playground-size-test--nodes node))))
       (ebox-playground-size-test--nodes (ebox-playground-size-test--form)))
      (ert-fail (format "Missing Size card: %s" id))))

(defun ebox-playground-size-test--color-widths (line color)
  "Return contiguous visible background COLOR widths in rendered LINE."
  (let ((line (ebox-playground-flex-resize-evaluator--visual-text line))
        (start 0) (run 0) widths)
    (while (< start (length line))
      (let ((end (next-single-property-change
                  start 'face line (length line))))
        (if (equal (plist-get (get-text-property start 'face line) :background)
                   color)
            (setq run (+ run (ebox-string-pixel-width
                             (substring line start end))))
          (when (> run 0) (push run widths))
          (setq run 0))
        (setq start end)))
    (when (> run 0) (push run widths))
    (nreverse widths)))

(ert-deftest ebox-playground-size-reference-covers-values-in-real-declarations ()
  "Every advertised unit, function, and keyword must occur as executable data."
  (let* ((form (ebox-playground-size-test--form))
         (nodes (ebox-playground-size-test--nodes form))
         (lists (ebox-playground-size-test--lists form)))
    (dolist (unit '(px % vw vh ch lh))
      (should (cl-some (lambda (item)
                         (and (eq (car item) unit)
                              (= (length item) 2)
                              (numberp (cadr item))))
                       lists)))
    (dolist (function '(calc min max clamp + - * /))
      (should (cl-some (lambda (item) (eq (car item) function)) lists)))
    (should (cl-some (lambda (item)
                       (and (memq (car item) '(px % vw vh ch lh))
                            (floatp (cadr item))))
                     lists))
    (dolist (property '(:width :height :min-width :min-height
                        :max-width :max-height))
      (dolist (value (append
                     (if (memq property '(:max-width :max-height))
                         '(none) '(auto))
                     '(min-content max-content fit-content stretch)))
        (ert-info ((format "Missing actual %S %S demonstration" property value))
          (should (cl-some (lambda (node)
                             (and (plist-member (cdr node) property)
                                  (eq (plist-get (cdr node) property) value)))
                           nodes)))))
    (should (ebox-canonical-input-p (ebox-build form)))))

(ert-deftest ebox-playground-size-reference-renders-full-document-at-three-widths ()
  "The complete reference remains readable beyond its initially visible page."
  (dolist (width '(320 720 1000))
    (let* ((text (ebox-playground-flex-resize-evaluator--example-text
                  ebox-playground-size-test--file width t))
           (lines (ebox-string-lines text)))
      (should (string-match-p "Ebox Size Reference" text))
      (should (> (length lines) 30))
      (dolist (line lines)
        (should (<= (ebox-string-pixel-width line) width))))))

(ert-deftest ebox-playground-size-reference-expressions-have-known-results ()
  "Check the example's actual expressions against independent reference values."
  (let ((context '(:percent-base 220 :viewport-width 800 :viewport-height 600
                   :ch 8 :lh 20)))
    (dolist (case '(("size-px" :width 180)
                    ("size-percent" :width 110)
                    ("size-vw" :width 160)
                    ("size-ch" :width 96)
                    ("size-lh" :height 40)
                    ("size-vh" :height 60)
                    ("size-calc" :width 196)
                    ("size-min" :width 100)
                    ("size-max" :width 110)
                    ("size-arithmetic" :width 60)
                    ("size-nested" :width 160)))
      (let* ((node (ebox-playground-size-test--node (car case)))
             (expression (plist-get (cdr node) (cadr case))))
        (ert-info ((format "Size demo %s: %S" (car case) expression))
          (should (= (ebox-size-resolve expression context) (nth 2 case))))))
    (should (= (ebox-size-resolve
                (plist-get (cdr (ebox-playground-size-test--node
                                "size-percent-parent")) :width)
                context)
               222))))

(ert-deftest ebox-playground-size-reference-labels-keep-a-common-font ()
  "Only the title is bold and only measured font samples change text size."
  (let ((nodes (ebox-playground-size-test--nodes
                (ebox-playground-size-test--form)))
        font-samples bold-nodes)
    (dolist (node nodes)
      (when (plist-member (cdr node) :font-size)
        (push (plist-get (cdr node) :id) font-samples))
      (when (eq (plist-get (cdr node) :font-weight) 'bold)
        (push node bold-nodes))
      (should-not (plist-member (cdr node) :padding-block)))
    (should (equal (sort font-samples #'string-lessp)
                   '("size-font-large" "size-font-small")))
    (should (= (length bold-nodes) 1))
    (should (equal (car (last (car bold-nodes))) "Ebox Size Reference"))))

(ert-deftest ebox-playground-size-reference-card-and-target-widths-match-copy ()
  "Actual borders and colored targets use the stated 220/112 px references."
  (dolist (case '(("size-percent" "#D97757" 222 110)
                  ("size-calc" "#AFA3D1" 222 196)
                  ("size-max" "#AFA3D1" 222 110)
                  ("size-width-auto" "#7DB8CE" 114 112)
                  ("size-width-stretch" "#7DB8CE" 114 112)
                  ("size-max-width-none" "#7DB8CE" 114 112)))
    (let* ((text (ebox-render
                  (ebox-build (ebox-playground-size-test--card (car case)))))
           (lines (ebox-string-lines text))
           (target-widths
            (cl-mapcan (lambda (line)
                         (ebox-playground-size-test--color-widths
                          line (nth 1 case)))
                       lines)))
      (ert-info ((format "Card %s" (car case)))
        (should (cl-every (lambda (line)
                            (= (ebox-string-pixel-width line) (nth 2 case)))
                          lines))
        (should (equal target-widths (make-list 2 (nth 3 case))))))))

(ert-deftest ebox-playground-size-reference-clipping-and-box-model-match-copy ()
  "Descriptions must agree with real clipping and visible box-model content."
  (dolist (id '("size-fractional-height" "size-whole-height"))
    (let ((text (ebox-render
                 (ebox-build (ebox-playground-size-test--node id)))))
      (should (= (ebox-string-height text) 2))
      (should (string-match-p "line one" text))
      (should (string-match-p "line two" text))
      (should-not (string-match-p "line three" text))))
  (let ((text (ebox-render
               (ebox-build (ebox-playground-size-test--node "size-box-model")))))
    (should (string-match-p "padding" text))
    (should (string-match-p "inside the border" text)))
  (let ((width (plist-get
                (cdr (ebox-playground-size-test--node "size-fractional-width"))
                :width)))
    (should (= (ebox-size-resolve width '(:viewport-width 853)) 102.36))))

(ert-deftest ebox-playground-size-reference-height-equivalence-is-intentional ()
  "Content height keywords agree, while lower bounds and stretch differ."
  (dolist (property '("height" "min-height" "max-height"))
    (dolist (keyword (cons (if (equal property "max-height") "none" "auto")
                          '("min-content" "max-content" "fit-content" "stretch")))
      (let* ((id (format "size-%s-%s" property keyword))
             (text (ebox-render
                    (ebox-build (ebox-playground-size-test--card id))))
             (colored-lines
              (cl-count-if
               (lambda (line)
                 (ebox-playground-size-test--color-widths line "#D9C46D"))
               (ebox-string-lines text)))
             (expected (cond ((member keyword '("stretch" "none")) 5)
                             ((and (equal property "min-height")
                                   (equal keyword "auto")) 1)
                             (t 3))))
        (ert-info ((format "%s visible height" id))
          (should (= colored-lines expected)))))))

(ert-deftest ebox-playground-size-reference-long-content-shows-three-widths ()
  "The same constrained text visibly separates all three intrinsic widths."
  (let ((widths
         (mapcar
          (lambda (keyword)
            (let* ((id (concat "size-width-long-" keyword))
                   (text (ebox-render
                          (ebox-build (ebox-playground-size-test--card id))))
                   (runs (cl-mapcan
                          (lambda (line)
                            (ebox-playground-size-test--color-widths
                             line "#7DB8CE"))
                          (ebox-string-lines text))))
              ;; Width, minimum, and maximum samples share one card.
              (should (= (length runs) 12))
              (should (cl-every (lambda (width) (= width (car runs))) runs))
              ;; All words survive all three constraints without being split
              ;; using the obsolete preferred width or clipped from the box.
              (dolist (word '("red" "ink" "blue"))
                (should (= (length (split-string text word)) 4)))
              (car runs)))
          '("min-content" "fit-content" "max-content"))))
    (should (< (nth 0 widths) (nth 1 widths) (nth 2 widths)))
    (should (= (nth 0 widths) (ebox-string-pixel-width "blue")))
    (should (= (nth 1 widths) (* 8 (ebox-string-pixel-width "0"))))
    (should (= (nth 2 widths) (ebox-string-pixel-width "red ink on blue")))))

(ert-deftest ebox-playground-size-reference-row-distinguishes-auto-and-stretch ()
  "Row context makes automatic content sizing visibly shorter than stretch."
  (let ((widths
         (mapcar
          (lambda (keyword)
            (let* ((text (ebox-render
                          (ebox-build
                           (ebox-playground-size-test--card
                            (concat "size-width-row-" keyword)))))
                   (runs (cl-mapcan
                          (lambda (line)
                            (ebox-playground-size-test--color-widths
                             line "#7DB8CE"))
                          (ebox-string-lines text))))
              (should runs)
              (should (cl-every (lambda (width) (= width (car runs))) runs))
              (car runs)))
          '("auto" "stretch"))))
    (should (< (car widths) (cadr widths)))
    (should (= (car widths) (ebox-string-pixel-width "red ink")))
    (should (= (cadr widths) 112))))

(ert-deftest ebox-playground-size-reference-functions-show-boundary-transitions ()
  "Actual rendered bars distinguish capping, flooring, and both constraints."
  (dolist (case '(("min" 24 96 144) ("max" 48 96 192)
                  ("clamp" 48 96 144)))
    (cl-mapc
     (lambda (regime expected)
       (let* ((id (format "size-function-%s-%s" (car case) regime))
              (text (ebox-render
                     (ebox-build (ebox-playground-size-test--node id)))))
         (ert-info ((format "%s rendered extent" id))
           (should (= (apply #'max (mapcar #'ebox-string-pixel-width
                                          (ebox-string-lines text)))
                      expected)))))
     '("low" "mid" "high") (cdr case))))

(ert-deftest ebox-playground-size-reference-units-reach-painted-sizes ()
  "Verify units and percentages in actual parent and viewport contexts."
  (let ((ebox-viewport-width 800) (ebox-viewport-height 40))
    (dolist (case '(("size-percent" "#D97757" 110 2)
                    ("size-vw" "#D97757" 160 2)
                    ("size-ch" "#D97757" 12 2)
                    ("size-lh" "#D97757" 220 2)
                    ("size-vh" "#D97757" 220 4)
                    ("size-percent-height" "#8FAF95" 220 3)))
      (let* ((text (ebox-render
                    (ebox-build (ebox-playground-size-test--card (car case)))))
             (runs (cl-mapcan
                    (lambda (line)
                      (ebox-playground-size-test--color-widths line (nth 1 case)))
                    (ebox-string-lines text)))
             (width (if (equal (car case) "size-ch")
                        (min 220 (* 12 (ebox-string-pixel-width "0")))
                      (nth 2 case))))
        (ert-info ((format "%s painted size" (car case)))
          (should (equal runs (make-list (nth 3 case) width))))))))

(ert-deftest ebox-playground-size-reference-flex-growth-has-visible-shares ()
  "Equal bases expose spare-space growth without font-dependent wrapping."
  (let* ((ebox-viewport-width 220)
         (text (ebox-render
                (ebox-build (ebox-playground-size-test--node "size-flex-grow"))))
         (lines (ebox-string-lines text)))
    (should (= (length lines) 2))
    (dolist (line lines)
      (should (= (ebox-string-pixel-width line) 220))
      (should (equal (ebox-playground-size-test--color-widths line "#9FD5CB")
                     '(80)))
      (should (equal (ebox-playground-size-test--color-widths line "#71BDB0")
                     '(130))))))

(ert-deftest ebox-playground-size-reference-grid-paint-shows-complete-tracks ()
  "Cell backgrounds expose both lines of each track and leave the gap clear."
  (let* ((ebox-viewport-width 220)
         (text (ebox-render
                (ebox-build (ebox-playground-size-test--node "size-grid"))))
         (lines (ebox-string-lines text))
         (ch (ebox-string-pixel-width "0")))
    (should (= (length lines) 5))
    (cl-loop for line in lines for index from 0 do
             (should (= (ebox-string-pixel-width line) 220))
             (dolist (case `(("#9FD5CB" . ,(* 8 ch))
                             ("#71BDB0" . ,(- 220 (* 9 ch)))))
               (should (equal
                        (ebox-playground-size-test--color-widths line (car case))
                        (unless (= index 2) (list (cdr case)))))))))

(ert-deftest ebox-playground-size-reference-clamp-reaches-all-three-regimes ()
  "The responsive clamp demo must exercise its minimum, fluid value, and cap."
  (let ((expression (plist-get
                     (cdr (ebox-playground-size-test--node "size-clamp"))
                     :width)))
    (dolist (case '((300 . 48) (800 . 96) (2000 . 200)))
      (should (= (ebox-size-resolve expression
                                  (list :viewport-width (car case)))
                 (cdr case))))))

(ert-deftest ebox-playground-size-reference-fixed-demos-render-their-extents ()
  "Fixed pixel and line demonstrations must reach the public renderer intact."
  (dolist (case '(("size-px" . 180) ("size-arithmetic" . 60)))
    (let ((text (ebox-render
                 (ebox-build (ebox-playground-size-test--node (car case))))))
      (should (= (apply #'max (mapcar #'ebox-string-pixel-width
                                      (ebox-string-lines text)))
                 (cdr case)))))
  (should (= (ebox-string-height
              (ebox-render (ebox-build
                            (ebox-playground-size-test--node "size-lh"))))
             2)))

(ert-deftest ebox-playground-size-reference-retained-resize-matches-fresh-render ()
  "Changing both viewport axes must update responsive sizes without stale output."
  (let ((buffer (generate-new-buffer " *ebox-size-reference-test*"))
        (ebox-runtime-idle-prewarm nil)
        (ebox-runtime-idle-reflow-cache-prewarm nil))
    (unwind-protect
        (let ((ebox-viewport-width 720) (ebox-viewport-height 36))
          (ebox-render-to-buffer
           buffer (ebox-playground-view ebox-playground-size-test--file 720))
          (dolist (size '((1000 48) (480 24) (720 36)))
            (let* ((ebox-viewport-width (car size))
                   (ebox-viewport-height (cadr size))
                   (fresh (ebox-render
                           (ebox-playground-view
                            ebox-playground-size-test--file (car size)))))
              (ebox-rerender-buffer-with-context buffer (car size) (cadr size))
              (should
               (equal-including-properties
                (ebox-playground-flex-resize-evaluator--visual-text fresh)
                (ebox-playground-flex-resize-evaluator--visual-text
                 (with-current-buffer buffer (buffer-string))))))))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(provide 'ebox-playground-size-tests)
;;; ebox-playground-size-tests.el ends here
