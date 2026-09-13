;;; ebox-playground-tests.el --- Public Ebox example tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'ebox-playground)
(require 'ebox-playground-flex-resize-evaluator
         (expand-file-name "benchmarks/ebox-playground-flex-resize-evaluator.el"
                           ebox-playground-directory))

(defconst ebox-playground-test--fixtures
  '("flex-reference.ebox" "grid-reference.ebox" "size-reference.ebox")
  "Migrated and maintained `.ebox' fixtures in the playground package.")

(defun ebox-playground-test--dynamic-width ()
  "Return a list-valued width from an ordinary Elisp expression."
  '(px 240))

(defun ebox-playground-test--dynamic-color ()
  "Return a color from an ordinary Elisp expression."
  "#123456")

(defun ebox-playground-test--read-layout (file)
  "Read and evaluate the layout expression in FILE."
  (ebox-playground--evaluate-form (ebox-playground--read-file file) file))

(defun ebox-playground-test--face-value (face attribute)
  "Resolve ATTRIBUTE from FACE in Emacs face precedence order."
  (cond ((null face) nil)
        ((symbolp face)
         (let ((value (face-attribute face attribute nil t)))
           (unless (eq value 'unspecified) value)))
        ((keywordp (car face)) (plist-get face attribute))
        (t (cl-some (lambda (entry)
                      (ebox-playground-test--face-value entry attribute)) face))))

(ert-deftest ebox-playground-selector-cascade-colors ()
  "Verify actual glyph paint for every annotated cascade example row."
  (let* ((file (expand-file-name "examples/selector-cascade-reference.ebox"
                                 ebox-playground-directory))
         (rendered (ebox-render (ebox-build (ebox-playground-test--read-layout file)))))
    (dolist (row '(("CASCADE LAB" "#FFFFFF" "#000000")
                   ("ROOT item" "#0000FF" "#00FFFF")
                   ("SCOPE A" "#000000" "#FFFF00")
                   ("A item" "#FF0000" "#FFA500")
                   ("A active" "#800080" "#00FF00")
                   ("A strong" "#FF00FF" "#000000")
                   ("SCOPE B" "#FFFFFF" "#800080")
                   ("B item" "#FFFFFF" "#000080")
                   ("B active" "#800080" "#00FF00")
                   ("B late" "#000000" "#FFFF00")
                   ("B inline" "#000000" "#FF69B4")
                   ("SIBLING SCOPE C" "#FFFFFF" "#006400")
                   ("C item" "#FFFFFF" "#FF0000")
                   ("OUTSIDE A/B/C" "#0000FF" "#00FFFF")))
      (let ((position (string-match (regexp-quote (car row)) rendered)))
        (should position)
        (let ((face (get-text-property position 'face rendered)))
          (ert-info ((format "Row %s: %S" (car row) face))
            (should (equal (ebox-playground-test--face-value face :foreground)
                           (nth 1 row)))
            (should (equal (ebox-playground-test--face-value face :background)
                           (nth 2 row)))))))))

(defun ebox-playground-test--boxes (form)
  "Return every nested BOX form in FORM."
  (when (consp form)
    (append (when (eq (car form) 'box)
              (list form))
            (cl-mapcan #'ebox-playground-test--boxes form))))

(defun ebox-playground-test--forms-named (name form)
  "Return every nested DSL form in FORM whose head is NAME."
  (when (consp form)
    (append (when (eq (car form) name)
              (list form))
            (cl-mapcan (lambda (child)
                         (ebox-playground-test--forms-named name child))
                       form))))

(defun ebox-playground-test--form-children (form)
  "Return canonical author children from DSL FORM."
  (let ((items (cdr form)))
    (while (keywordp (car items))
      (setq items (cddr items)))
    items))

(defun ebox-playground-test--separator-form-p (form)
  "Return non-nil for an empty gallery separator FORM, regardless of defaults."
  (and (eq (car-safe form) 'box)
       (null (ebox-playground-test--form-children form))
       (equal (plist-get (cdr form) :bgcolor) "#FAF7F0")))

(defun ebox-playground-test--line-widths (text)
  "Return rendered pixel widths for every line in TEXT."
  (mapcar #'ebox-string-pixel-width
          (ebox-string-lines text)))

(defun ebox-playground-test--max-line-width (text)
  "Return the widest rendered pixel line in TEXT."
  (apply #'max (ebox-playground-test--line-widths text)))

(defun ebox-playground-test--absolute-space-width (line)
  "Return LINE's explicit pixel space width, preserving fractional precision."
  (pcase (get-text-property 0 'display line)
    (`(space :width (,width)) (and (numberp width) width))))

(defconst ebox-playground-test--grid-value-forms
  '(":grid-template-columns (auto auto)"
    ":grid-template-columns (min-content max-content)"
    ":grid-template-columns ((px 120) (px 74))"
    ":padding-inline (px 2)"
    ":grid-template-columns ((px 192))"
    ":grid-template-columns ((px 88) (px 88))"
	":grid-template-columns ((fr 1) (fr 2))"
    ":grid-template-columns ((minmax"
    ":grid-template-columns ((repeat"
    ":grid-template-rows (auto auto)"
	":grid-template-rows ((fr 1) (fr 2))"
    ":grid-auto-columns ((px 64))"
    ":grid-auto-columns auto"
	":grid-auto-columns (fr 1)"
    ":grid-auto-columns ((minmax"
    ":grid-auto-rows (lh 2)"
    ":grid-auto-rows auto"
	":grid-auto-rows (fr 1)"
    ":grid-auto-rows ((minmax"
    ":grid-auto-flow row"
    ":grid-auto-flow column"
    ":gap ((lh 1) (ch 1))"
    ":gap ((lh 1) (px 14))"
    ":row-gap (lh 2)"
    ":column-gap (px 28)"
    ":grid-column 2"
    ":grid-row 2"
    ":grid-column (1 :span 2)"
    ":grid-row (1 :span 2)"
    ":grid-column (1 3)"
    ":grid-row (1 3)"
    ":grid-column-span 2"
    ":grid-row-span 2"
    ":justify-items start"
    ":justify-items center"
    ":justify-items end"
    ":justify-items stretch"
    ":align-items start"
    ":align-items center"
    ":align-items end"
    ":align-items stretch"
    ":align-items normal"
    ":justify-content start"
    ":justify-content center"
    ":justify-content end"
    ":justify-content space-between"
    ":justify-content space-around"
    ":justify-content space-evenly"
    ":justify-content stretch"
    ":justify-content normal"
    ":align-content start"
    ":align-content center"
    ":align-content end"
    ":align-content space-between"
    ":align-content space-around"
    ":align-content space-evenly"
    ":align-content stretch"
    ":align-content normal")
  "Public Grid property/value fragments required in the reference fixture.")

(ert-deftest ebox-playground-tinted-content-has-effective-ink ()
  "Tinted fixture text should have effective ink, including inherited colors."
  (dolist (file ebox-playground-test--fixtures)
    (let* ((text (ebox-playground-flex-resize-evaluator--example-text
                  (expand-file-name (concat "examples/" file)
                                    ebox-playground-directory)
                  720 t))
           (normalized (ebox-playground-flex-resize-evaluator--visual-text text)))
      (dotimes (index (length normalized))
        (when (string-match-p "[^[:space:]]" (substring normalized index (1+ index)))
          (let ((face (get-text-property index 'face normalized)))
            (when (plist-get face :background)
              (should (stringp (plist-get face :foreground))))))))))

(ert-deftest ebox-playground-visual-comparison-merges-effective-faces ()
  "Equivalent face grouping and runtime identities should not create differences."
  (let ((before (propertize "text" 'face
                            '((:foreground "red" :height 1.5)
                              (:foreground "blue" :background "white" :height 120))
                            'ebox-content-idx 1))
        (after (propertize "text" 'face
                           '(:height 180 :background "white" :foreground "red")
                           'ebox-content-idx 9)))
    (should (equal-including-properties
             (ebox-playground-flex-resize-evaluator--visual-text before)
             (ebox-playground-flex-resize-evaluator--visual-text after)))))

(ert-deftest ebox-playground-visual-comparison-preserves-visible-and-interactive-changes ()
  "Face, geometry, text, and interaction differences must survive normalization."
  (dolist (values '((face (:foreground "red") (:foreground "blue"))
                    (face (:height 120) (:height 180))
                    (display (space :width (80)) (space :width (81)))
                    (help-echo "first action" "second action")
                    (keymap (keymap (13 . first-command))
                            (keymap (13 . second-command)))
                    (mouse-face (:foreground "red") (:foreground "blue"))))
    (should-not
     (equal-including-properties
      (ebox-playground-flex-resize-evaluator--visual-text
       (propertize "text" (nth 0 values) (nth 1 values)))
      (ebox-playground-flex-resize-evaluator--visual-text
       (propertize "text" (nth 0 values) (nth 2 values))))))
  (should-not
   (equal-including-properties
    (ebox-playground-flex-resize-evaluator--visual-text "text")
    (ebox-playground-flex-resize-evaluator--visual-text "changed"))))

(ert-deftest ebox-playground-spacer-auto-width-and-inherited-color-render-equally ()
  "Explicit spacer height and inherited ink retain geometry and local overrides."
  (let* ((ebox-viewport-width 720)
         (explicit
          '(column :width (px 240)
                   (box :width stretch :height (lh 1) :bgcolor "#FAF7F0")
                   (box :color "#123456" :bgcolor "#FFFFFF" "Inherited ink")
                   (box :color "#654321" :bgcolor "#FFFFFF" "Local ink")))
         (inherited
          '(column :width (px 240) :color "#123456"
                   (box :height (lh 1) :bgcolor "#FAF7F0")
                   (box :bgcolor "#FFFFFF" "Inherited ink")
                   (box :color "#654321" :bgcolor "#FFFFFF" "Local ink")))
         (before (ebox-playground-flex-resize-evaluator--visual-text
                  (ebox-render (ebox-build explicit))))
         (after (ebox-playground-flex-resize-evaluator--visual-text
                 (ebox-render (ebox-build inherited)))))
    (should (equal-including-properties before after))
    (should (equal (plist-get
                    (get-text-property (string-match "Local ink" after) 'face after)
                    :foreground)
                   "#654321"))))

(ert-deftest ebox-playground-uses-only-public-layout-apis ()
  "The example should build and render through the public Ebox entry point."
  (let* ((source (ebox-playground-test--read-layout
                  ebox-playground-default-file))
         (node (ebox-playground-view))
         (rendered (substring-no-properties (ebox-render node))))
    (should (eq (car source) 'column))
    (dolist (label '("Ebox CSS Grid Reference" "Container property:"
                     "120 PX"))
      (should (string-match-p (regexp-quote label) rendered)))))

(ert-deftest ebox-playground-flex-evaluator-uses-public-observation ()
  "Keep the Flex resize gate on public Ebox reports without advice."
  (let* ((source (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name
                    "benchmarks/ebox-playground-flex-resize-evaluator.el"
                    ebox-playground-directory))
                  (buffer-string)))
        (resize-source
         (with-temp-buffer
           (insert source)
           (goto-char (point-min))
           ;; The shared file also contains private scroll diagnostics and
           ;; declarative property-name metadata.  Guard every resize function
           ;; and helper body, rather than unrelated top-level forms.
           (let (functions)
             (condition-case nil
                 (while t
                   (let ((form (read (current-buffer))))
                     (when (and (eq (car-safe form) 'defun)
                                (string-prefix-p
                                 "ebox-playground-flex-resize-evaluator-"
                                 (symbol-name (cadr form))))
                       (push form functions))))
               (end-of-file nil))
             ;; Inspect API use, allowing this quoted render metadata name.
             ;; The oracle canonicalizes its ids; it does not call an Ebox
             ;; private function or read mutable runtime state through it.
             (prin1-to-string
              (cl-subst '(quote hover-owner-metadata)
                        '(quote ebox--hover-style)
                        (nreverse functions) :test #'equal)))))
        (runner (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "benchmarks/flex-resize-evaluator.sh"
                                     ebox-playground-directory))
                  (buffer-string)))
        (makefile (with-temp-buffer
                    (insert-file-contents
                     (expand-file-name "Makefile" ebox-playground-directory))
                    (buffer-string))))
    (should (string-match-p "ebox-playground-flex-resize-evaluator-run"
                            resize-source))
    (should (string-match-p "ebox-buffer-set-observer" resize-source))
    (should (string-match-p "evaluator-warmup-count 5" source))
    (should (string-match-p "evaluator-sample-count 30" source))
    (should (string-match-p "per-update p95 budget" source))
    (should (string-match-p "EBOX_PLAYGROUND_FLEX_FIXTURE" runner))
    (should (string-match-p "show HEAD:examples/flex-reference.ebox" runner))
    (should (string-match-p "performance-prepare:" makefile))
    (should (string-match-p "native-build" makefile))
    (should-not (string-match-p "-l \"\$root/ebox-playground.el\"" runner))
    (dolist (private '("ebox--" "advice-add" "advice-remove"
                       "ebox-native-reflow--"))
      (should-not (string-match-p (regexp-quote private) resize-source)))))

(ert-deftest ebox-playground-keeps-layout-in-ebox-source ()
  "Keep concrete gallery content out of the generic Elisp runner."
  (let ((runner (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "ebox-playground.el"
                                     ebox-playground-directory))
                  (buffer-string))))
    (should (file-readable-p ebox-playground-default-file))
    (should (string-suffix-p ".ebox" ebox-playground-default-file))
    (should-not (string-match-p "FIXED TRACK" runner))
    (should-not (string-match-p "PUBLIC COMPOSITION" runner))
    (should-not (string-match-p "GRID TOOLKIT" runner))))

(ert-deftest ebox-playground-migrated-fixtures-render-at-the-canvas-width ()
  "Every migrated fixture should render through the generic file boundary."
  (let ((ebox-viewport-width 720))
    (dolist (file ebox-playground-test--fixtures)
      (let* ((path (expand-file-name (concat "examples/" file)
                                     ebox-playground-directory))
             (text (substring-no-properties
                    (ebox-render (ebox-playground-view path))))
             (widths (mapcar #'ebox-string-pixel-width
                             (ebox-string-lines text))))
        (should (file-readable-p path))
        (should (stringp text))
        (should (cl-every (lambda (width) (<= width 720)) widths))))))

(ert-deftest ebox-playground-flex-reference-uses-a-compact-default-viewport ()
  "The public Flex file entry point should use the compact default viewport."
  (let ((path (expand-file-name "examples/flex-reference.ebox"
                               ebox-playground-directory))
        (name " *ebox-playground-flex-viewport-test*"))
    (unwind-protect
        (progn
          (ebox-playground-open-file path name)
          (with-current-buffer name
            (let ((widths (mapcar #'ebox-string-pixel-width
                                  (ebox-string-lines (buffer-string)))))
              (should (cl-every (lambda (width) (<= width 720)) widths)))))
      (ebox-playground-close name))))

(ert-deftest ebox-playground-flex-reference-owns-document-scrolling ()
  "The Flex reference root must expose one line-oriented Ebox scroll owner."
  (let ((path (expand-file-name "examples/flex-reference.ebox"
                               ebox-playground-directory))
        (name " *ebox-playground-flex-scroll-owner-test*"))
    (unwind-protect
        (let ((ebox-viewport-width 720)
              (ebox-viewport-height 36))
          (ebox-playground-open-file path name)
          (with-current-buffer name
            (let* ((state (ebox--buffer-render-state (current-buffer)))
                   (table (plist-get state :scroll-state-table))
                   (region-id
                    (car
                     (sort (copy-sequence
                            (plist-get state :scroll-region-ids))
                           (lambda (left right)
                             (> (- (length (plist-get
                                           (gethash left table)
                                           :content-lines))
                                   (plist-get (gethash left table)
                                              :content-height))
                                (- (length (plist-get
                                           (gethash right table)
                                           :content-lines))
                                   (plist-get (gethash right table)
                                              :content-height))))))))
              (should region-id)
              (should (= (ebox--scroll-region-by region-id 1 1) 1))
              (setq table
                    (plist-get (ebox--buffer-render-state (current-buffer))
                               :scroll-state-table))
              (should (= (plist-get (gethash region-id table) :scroll-offset)
                         1)))))
      (ebox-playground-close name))))

(ert-deftest ebox-playground-evaluator-normalizes-hover-owner-identities ()
  "Fresh ids compare equally without discarding paint or owner partitions."
  (let* ((normalize #'ebox-playground-flex-resize-evaluator--visual-text)
         (left (propertize "AB" 'ebox--hover-style
                           '(:owner 22 :face (:background "red")
                             :base (:foreground "white"))))
         (fresh (propertize "AB" 'ebox--hover-style
                            '(:owner 96 :face (:background "red")
                              :base (:foreground "white")))))
    (should (equal-including-properties
             (funcall normalize left) (funcall normalize fresh)))
    (should (= (plist-get (get-text-property 0 'ebox--hover-style left) :owner) 22))
    (dolist (declaration '((:owner 96 :face (:background "blue")
                           :base (:foreground "white"))
                          (:owner 96 :face (:background "red")
                           :base (:foreground "black"))
                          (:owner 97 :face (:background "red")
                           :base (:foreground "white"))))
      (let ((changed (copy-sequence fresh)))
        (put-text-property 1 2 'ebox--hover-style declaration changed)
        (should-not (equal-including-properties
                     (funcall normalize left) (funcall normalize changed)))))))

(ert-deftest ebox-playground-interaction-evaluator-measures-and-cleans ()
  "Native repeated commands report their work and release temporary state."
  (let ((file (make-temp-file "ebox-interaction-evaluator-" nil ".ebox"))
        (buffers (buffer-list))
        (windows (window-state-get))
        (functions
         (mapcar (lambda (symbol) (cons symbol (symbol-function symbol)))
                 '(ebox--render-layout ebox-surface--surface-plan
                   ebox-surface--rendered-fragments ebox-surface--ensure-node-tree))))
    (unwind-protect
        (progn
          (with-temp-file file
            (prin1
             '(let ((count 0))
                (list 'column :width '(px 120)
                      (list 'text :id "count" "00")
                      (list 'text :keymap
                            (ebox-keymap-create
                             :activate
                             (lambda ()
                               (ebox-region-update
                                "count" :content (format "%02d" (cl-incf count)))))
                            "Add")))
             (current-buffer)))
          (let ((report (ebox-playground-interaction-evaluator-run
                         file "Add" "RET" 3 120 8)))
            (should (plist-get report :fresh-parity))
            (should (string-match-p "03" (plist-get report :text)))
            (should (= (plist-get report :publications) 3))
            (dolist (key '(:mean-ms :p95-ms :max-ms :gc-count :gc-ms :cons-cells
                           :layout-calls :surface-plans :full-surface-renders
                           :fragment-scans
                           :fragment-characters :node-registrations))
              (should (>= (plist-get report key) 0))))
          (cl-letf (((symbol-function 'ebox-region-update)
                     (lambda (&rest _) (error "Injected command failure"))))
            (should-error (ebox-playground-interaction-evaluator-run
                           file "Add" "RET" 3 120 8)))
          (should-error (ebox-playground-interaction-evaluator-run
                         file "Missing" "RET" 3 120 8))
          (should (equal buffers (buffer-list)))
          (should (equal windows (window-state-get)))
          (dolist (entry functions)
            (should (eq (cdr entry) (symbol-function (car entry))))))
      (delete-file file))))

(defvar ebox-playground-test--evaluator-command nil
  "Optional callback used by the interaction evaluator's temporary fixture.")

(defun ebox-playground-test--interaction-fixture (file)
  "Write a native two-key counter fixture to FILE."
  (with-temp-file file
    (prin1
     '(let* ((count 0)
             (move (lambda (delta)
                     (when ebox-playground-test--evaluator-command
                       (funcall ebox-playground-test--evaluator-command))
                     (ebox-region-update
                      "count" :content (format "%02d" (cl-incf count delta))))))
        (list 'column :width '(px 120)
              (list 'text :id "count" "00")
              (list 'text :keymap
                    (ebox-keymap-create
                     :bindings `(("a" . ,(lambda () (funcall move 1)))
                                 ("b" . ,(lambda () (funcall move -1)))))
                    "Move")))
     (current-buffer))))

(ert-deftest ebox-playground-interaction-evaluator-alternates-and-excludes-warmup ()
  "Odd warmup continues the key sequence and stays outside every work metric."
  (let ((file (make-temp-file "ebox-interaction-options-" nil ".ebox"))
        (gc-cons-threshold most-positive-fixnum)
        (gc-cons-percentage 1.0)
        (gcs-done 0) (gc-elapsed 0.0)
        (cons-count 0) events)
    (unwind-protect
        (progn
          (ebox-playground-test--interaction-fixture file)
          (let ((ebox-playground-test--evaluator-command
                 (lambda ()
                   (push last-input-event events)
                   (cl-incf gcs-done 2)
                   (cl-incf gc-elapsed 0.001)
                   (cl-incf cons-count 11))))
            (cl-letf (((symbol-function 'memory-use-counts)
                       (lambda () (list cons-count))))
              (let ((report (ebox-playground-interaction-evaluator-run
                             file "Move" "a" 3 120 8
                             '(:alternate-key [98] :warmup 3))))
                (should (equal (reverse events) '(97 98 97 98 97 98)))
                (should (string-match-p "00" (plist-get report :text)))
                (should (= (plist-get report :publications) 3))
                (should (= (plist-get report :gc-count) 6))
                (should (< (abs (- (plist-get report :gc-ms) 3.0)) 0.001))
                (should (= (plist-get report :cons-cells) 33))
                (should (equal (plist-get report :alternate-key) "b"))
                (should (= (plist-get report :warmup) 3))
                (should (= (plist-get report :steps) 3))
                (should (plist-get report :fresh-parity))
                (should-not (plist-member report :cpu-profile))
                (let ((reference (ebox-playground-interaction-evaluator-run
                                  file "Move" "a" 3 120 8
                                  '(:alternate-key "b" :warmup 1))))
                  (dolist (key '(:layout-calls :surface-plans :full-surface-renders
                                 :fragment-scans :fragment-characters
                                 :node-registrations))
                    (should (= (plist-get report key) (plist-get reference key)))))))))
      (delete-file file))))

(ert-deftest ebox-playground-interaction-evaluator-validates-options ()
  "Malformed options and empty or unbound alternate keys fail cleanly."
  (let ((file (make-temp-file "ebox-interaction-invalid-" nil ".ebox"))
        (buffers (buffer-list)))
    (unwind-protect
        (progn
          (ebox-playground-test--interaction-fixture file)
          (dolist (options '((:warmup) (:unknown t) (:warmup 0 :warmup 1)
                             (:warmup -1) (:warmup 0.5) (:warmup nil)
                             (:profile 1) (:alternate-key 2)
                             (:alternate-key "") (:alternate-key [])
                             (:alternate-key "z")))
            (should-error (ebox-playground-interaction-evaluator-run
                           file "Move" "a" 1 120 8 options)))
          (should (equal buffers (buffer-list))))
      (delete-file file))))

(ert-deftest ebox-playground-interaction-evaluator-bounds-cpu-summary ()
  "Recursive inclusive counts and anonymous closures cannot leak runtime data."
  (let ((log (make-hash-table :test #'equal))
        (secret (list "captured runtime must not be printed")))
    (puthash [sample-leaf sample-parent sample-parent nil] 6 log)
    (puthash (vector (lambda () secret) 'sample-parent nil) 4 log)
    (let* ((report (ebox-playground-interaction-evaluator--cpu-summary log))
           (inclusive (plist-get report :inclusive))
           (exclusive (plist-get report :exclusive)))
      (should (= (plist-get report :total-samples) 10))
      (should (equal (car inclusive)
                     '(:function "sample-parent" :samples 10 :percent 100.0)))
      (should (equal (car exclusive)
                     '(:function "sample-leaf" :samples 6 :percent 60.0)))
      (should-not (string-match-p "captured runtime" (prin1-to-string report))))
    (dotimes (index 30)
      (puthash (vector (intern (format "sample-extra-%d" index))) 1 log))
    (let ((report (ebox-playground-interaction-evaluator--cpu-summary log)))
      (should (= (length (plist-get report :inclusive)) 15))
      (should (= (length (plist-get report :exclusive)) 15)))
    (should (equal (ebox-playground-interaction-evaluator--cpu-summary nil)
                   '(:total-samples 0 :inclusive nil :exclusive nil)))))

(ert-deftest ebox-playground-interaction-evaluator-profile-isolates-and-cleans ()
  "Sampling excludes warmup and always releases advice, profiler and timers."
  (let ((file (make-temp-file "ebox-interaction-profile-" nil ".ebox"))
        (buffers (buffer-list))
        (windows (window-state-get))
        (live-timer (run-at-time 3600 nil #'ignore))
        (functions (mapcar (lambda (symbol) (cons symbol (symbol-function symbol)))
                           '(ebox--render-layout ebox-surface--surface-plan
                             ebox-surface--render-candidate
                             ebox-surface--rendered-fragments
                             ebox-surface--ensure-node-tree))))
    (unwind-protect
        (progn
          (ebox-playground-test--interaction-fixture file)
          (dolist (failure '(nil error quit timeout warmup start-error start-quit))
            (let* ((saved (make-hash-table :test #'equal))
                   (profiler-cpu-log saved) (profiler-memory-log saved)
                   (ebox--deferred-render-gc-timer live-timer)
                   (clock 0.0) (active nil) (starts 0) (stops 0)
                   (calls 0) owned-timer
                   (snapshot-function (symbol-function 'ebox-surface-buffer-snapshot))
                   (normalize-function
                    (symbol-function 'ebox-playground-scroll-evaluator--visual-text))
                   (ebox-playground-test--evaluator-command
                    (lambda ()
                      (cl-incf calls)
                      (should (eq (and active t) (> calls 1)))
                      (when (or (and (eq failure 'warmup) (= calls 1))
                                (= calls 2))
                        (setq owned-timer (run-at-time 3600 nil #'ignore)
                              ebox--deferred-render-gc-timer owned-timer)
                        (pcase failure
                          ((or 'error 'warmup) (error "Injected command failure"))
                          ('quit (signal 'quit nil))
                          ('timeout (setq clock 31.0)))))))
              (cl-letf (((symbol-function 'profiler-running-p) (lambda (&rest _) active))
                        ((symbol-function 'profiler-cpu-start)
                         (lambda (_)
                           (cl-incf starts)
                           (setq active t)
                           (pcase failure
                             ('start-error (error "Injected profiler start failure"))
                             ('start-quit (signal 'quit nil)))))
                        ((symbol-function 'profiler-cpu-stop)
                         (lambda () (cl-incf stops) (setq active nil)))
                        ((symbol-function 'profiler-cpu-log)
                         (lambda () nil))
                        ((symbol-function 'float-time) (lambda (&rest _) clock))
                        ((symbol-function 'ebox-surface-buffer-snapshot)
                         (lambda (&rest args)
                           (should-not active)
                           (apply snapshot-function args)))
                        ((symbol-function 'ebox-playground-scroll-evaluator--visual-text)
                         (lambda (&rest args)
                           (should-not active)
                           (apply normalize-function args))))
                (let ((outcome
                       (condition-case condition
                           (ebox-playground-interaction-evaluator-run
                            file "Move" "a" 3 120 8
                            '(:alternate-key "b" :warmup 1 :profile t))
                         (error (car condition)) (quit (car condition)))))
                  (if failure
                      (should (eq outcome (if (memq failure '(quit start-quit))
                                             'quit 'error)))
                    (should (plist-get outcome :fresh-parity))
                    (should (equal (plist-get (plist-get outcome :cpu-profile)
                                             :total-samples) 0))))
                (should-not active)
                (should (= starts (if (eq failure 'warmup) 0 1)))
                (should (= stops starts)))
              (should (eq profiler-cpu-log saved))
              (should (eq profiler-memory-log saved))
              (should (eq ebox--deferred-render-gc-timer live-timer))
              (should (memq live-timer timer-list))
              (should-not (memq owned-timer timer-list))
              (should (equal buffers (buffer-list)))
              (should (equal windows (window-state-get)))
              (dolist (entry functions)
                (should (eq (cdr entry) (symbol-function (car entry))))))))
      (cancel-timer live-timer)
      (delete-file file))))

(ert-deftest ebox-playground-interaction-evaluator-preserves-profiler-logs ()
  "A running profiler is untouched; stopped low-level samples remain available."
  (let ((file (make-temp-file "ebox-interaction-logs-" nil ".ebox"))
        (buffers (buffer-list)) (stops 0))
    (unwind-protect
        (progn
          (ebox-playground-test--interaction-fixture file)
          (dolist (mode '(cpu mem))
            (cl-letf (((symbol-function 'profiler-running-p) (lambda (&rest _) mode))
                      ((symbol-function 'profiler-cpu-stop)
                       (lambda () (cl-incf stops))))
              (should-error (ebox-playground-interaction-evaluator-run
                             file "Move" "a" 2 120 8 '(:profile t)))))
          (should (= stops 0))
          (let* ((saved (make-hash-table :test #'equal))
                 (pending (make-hash-table :test #'equal))
                 (measured (make-hash-table :test #'equal))
                 (profiler-cpu-log saved) (profiler-memory-log saved)
                 (logs (list pending measured)))
            (puthash [prior] 7 saved)
            (puthash [pending] 11 pending)
            (puthash [measured] 3 measured)
            (cl-letf (((symbol-function 'profiler-running-p) (lambda (&rest _) nil))
                      ((symbol-function 'profiler-cpu-start) #'ignore)
                      ((symbol-function 'profiler-cpu-stop) #'ignore)
                      ((symbol-function 'profiler-cpu-log) (lambda () (pop logs))))
              (let ((report (ebox-playground-interaction-evaluator-run
                             file "Move" "a" 2 120 8 '(:profile t))))
                (should (= (plist-get (plist-get report :cpu-profile) :total-samples) 3))))
            (should (= (gethash [prior] profiler-cpu-log) 7))
            (should (= (gethash [pending] profiler-cpu-log) 11))
            (should-not (gethash [measured] profiler-cpu-log))
            (should (eq profiler-memory-log saved)))
          (should (equal buffers (buffer-list))))
      (delete-file file))))

(ert-deftest ebox-playground-scroll-evaluator-preserves-live-runtime ()
  "Profiling multiple files preserves existing mounts, windows, and timers."
  (let ((file (make-temp-file "ebox-scroll-evaluator-" nil ".ebox"))
        (live (generate-new-buffer " *ebox-scroll-evaluator-live-test*"))
        (ebox-runtime-idle-prewarm nil)
        (ebox-runtime-idle-reflow-cache-prewarm nil)
        (ebox-scroll-lazy-idle-prefetch-lines 0)
        (layout '(column :width (px 120) :height (lh 4) :overflow scroll
                  (box "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11"))))
    (unwind-protect
        (progn
          (with-temp-file file (prin1 (list 'quote layout) (current-buffer)))
          (ebox-render-to-buffer live (ebox-build layout))
          (let* ((runtime (ebox--buffer-render-state live))
                 (region-id
                  (plist-get (plist-get runtime :root-node) :region-id))
                 (scroll-state (ebox--scroll-get-state region-id))
                 (contents (with-current-buffer live (buffer-string)))
                 (windows (window-state-get))
                 (buffers (buffer-list))
                 (timer (run-at-time 3600 nil #'ignore))
                 (ebox--deferred-render-gc-timer timer))
            (unwind-protect
                (let* ((standard-output (lambda (_character)))
                       ;; Exercise the GUI GC lease without displaying a buffer.
                       (noninteractive nil)
                       (reports (ebox-playground-scroll-evaluator-run
                                 (list file file) 121 3 8)))
                  (should (= (length reports) 4))
                  (should (equal (mapcar (lambda (report)
                                           (plist-get report :position))
                                         reports)
                                 '(top middle top middle)))
                  (dolist (report reports)
                    (should (plist-get report :fresh-render-parity))
                    (should (= (plist-get report :steps) 3))
                    (dolist (key '(:mean-ms :p95-ms :max-ms :root-renders
                                   :document-preparations :surface-plans
                                   :node-styles :style-computations
                                   :prefix-renders :materializations))
                      (should (>= (plist-get report key) 0))))
                  (should (eq runtime (ebox--buffer-render-state live)))
                  (should (eq scroll-state (ebox--scroll-get-state region-id)))
                  (should (equal-including-properties
                           contents (with-current-buffer live (buffer-string))))
                  (should (equal windows (window-state-get)))
                  (should (equal buffers (buffer-list)))
                  (should (eq ebox--deferred-render-gc-timer timer))
                  (should (memq timer timer-list)))
              (cancel-timer timer))))
      (when (buffer-live-p live) (kill-buffer live))
      (delete-file file))))

(ert-deftest ebox-playground-scroll-evaluator-cleans-after-scroll-error ()
  "A measured scroll failure removes advice and the evaluator's mount."
  (let ((file (make-temp-file "ebox-scroll-evaluator-error-" nil ".ebox"))
        (calls 0)
        (original-scroll (symbol-function 'ebox--scroll-region-by))
        (functions
         (mapcar (lambda (symbol) (cons symbol (symbol-function symbol)))
                 '(ebox-surface--render-candidate
                   ebox-incremental-prepare-scoped-commit
                   ebox-surface--surface-plan
                   ebox-surface--apply-node-style
                   ebox-surface--compute-node-style
                   ebox--render-scroll-window-source
                   ebox--scroll-state-materialize-lines)))
        (buffers (buffer-list)))
    (unwind-protect
        (progn
          (with-temp-file file
            (prin1
             ''(column :width (px 120) :height (lh 2) :overflow scroll
                (box "0\n1\n2\n3\n4\n5\n6"))
             (current-buffer)))
          (cl-letf (((symbol-function 'ebox--scroll-region-by)
                     (lambda (&rest arguments)
                       (when (= (cl-incf calls) 3)
                         (error "Injected measured scroll failure"))
                       (apply original-scroll arguments))))
            (should-error
             (ebox-playground-scroll-evaluator-run file 121 3 8)))
          (should (= calls 3))
          (should (equal buffers (buffer-list)))
          (dolist (entry functions)
            (should (eq (cdr entry) (symbol-function (car entry))))))
      (delete-file file))))

(ert-deftest ebox-playground-scroll-evaluator-normalizes-only-invisible-spacers ()
  "The visual oracle tolerates empty padding but retains visible differences."
  (let* ((text (propertize "A" 'face '(:foreground "#123456")))
         (normalize #'ebox-playground-scroll-evaluator--visual-text))
    (should (equal-including-properties
             (funcall normalize text)
             (funcall normalize
                      (concat (propertize " " 'display '(space :width (0))
                                          'face '(:foreground "#123456"))
                              text))))
    (dolist (changed
             (list (concat (propertize " " 'display '(space :width (1))) text)
                   (propertize "A" 'face '(:foreground "#654321"))
                   (propertize "B" 'face '(:foreground "#123456"))))
      (should-not (equal-including-properties
                   (funcall normalize text)
                   (funcall normalize changed)))))
  (dolist (carrier
           (list (propertize " " 'display '(space :width (0)))
                 (propertize " " 'display '(space :width (0) :height 2))
                 (propertize " " 'display '(space :width (0) :ascent 90))
                 (propertize " " 'display '(space :width (0))
                             'face '(:height 2.0))))
    (should (> (length (ebox-playground-scroll-evaluator--visual-text
                       (concat carrier "\nA")))
               2))))

(ert-deftest ebox-playground-scroll-evaluator-selects-nested-owner-in-both-modes ()
  "Semantic selection profiles only the nested owner, including cold forward work."
  (let ((file (make-temp-file "ebox-scroll-evaluator-nested-" nil ".ebox"))
        (buffers (buffer-list)))
    (unwind-protect
        (progn
          (with-temp-file file
            (prin1
             ''(column :width (px 120)
                (box "Before")
                (row
                  (box :id "selected" :width (px 60) :height (lh 3) :overflow scroll
                    "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11")
                  (box :width (px 40) :height (lh 3) :overflow scroll
                    "a\nb\nc\nd\ne\nf\ng"))
                (box "After"))
             (current-buffer)))
          (dolist (cold '(nil t))
            (let* ((standard-output (lambda (_character)))
                   (scroll (symbol-function 'ebox--scroll-region-by))
                   (materialize (symbol-function 'ebox--scroll-state-materialize-lines))
                   (measure (symbol-function 'ebox-playground-scroll-evaluator--measure))
                   (open (symbol-function 'ebox-playground-open-file))
                   mounted measuring calls reports)
              (cl-letf (((symbol-function 'ebox-playground-open-file)
                         (lambda (&rest arguments)
                           (prog1 (apply open arguments) (setq mounted t))))
                        ((symbol-function 'ebox-playground-scroll-evaluator--measure)
                         (lambda (&rest arguments)
                           (setq measuring t)
                           (unwind-protect (apply measure arguments)
                             (setq measuring nil))))
                        ((symbol-function 'ebox--scroll-state-materialize-lines)
                         (lambda (&rest arguments)
                           (when (and cold mounted (not measuring))
                             (ert-fail "Cold evaluator eagerly materialized content"))
                           (apply materialize arguments)))
                        ((symbol-function 'ebox--scroll-region-by)
                         (lambda (region delta &optional budget)
                           (when cold (should measuring))
                           (push delta calls)
                           (funcall scroll region delta budget))))
                (setq reports (ebox-playground-scroll-evaluator-run
                               file 121 3 8 (list :region-id "selected" :cold cold))))
              (should (= (length reports) (if cold 1 2)))
              (when cold (should (equal calls '(1 1 1))))
              (dolist (report reports)
                (should (plist-get report :fresh-render-parity))
                (should (equal (plist-get report :region-id) "selected"))
                (should (eq (plist-get report :mode) (if cold 'cold 'cached)))
                (should (= (- (plist-get report :end-offset)
                              (plist-get report :start-offset))
                           (if cold 3 1)))
                (when cold
                  (should (eq (plist-get report :position) 'cold))
                  (should (= (plist-get report :start-offset) 0)))
                (when (plist-get report :content-complete-p)
                  (should (= (plist-get report :max-offset) 9))))))
          (should (equal buffers (buffer-list))))
      (delete-file file))))

(ert-deftest ebox-playground-scroll-evaluator-cold-extends-initial-prefix ()
  "Cold samples cross the mounted cache boundary without full materialization."
  (let ((file (make-temp-file "ebox-scroll-evaluator-prefix-" nil ".ebox"))
        (ebox-scroll-lazy-prefix-lookahead-lines 8)
        (ebox-wheel-scroll-step 16)
        (measure (symbol-function 'ebox-playground-scroll-evaluator--measure))
        (buffers (buffer-list))
        initial-capacity reports)
    (unwind-protect
        (progn
          (with-temp-file file
            (prin1
             (list 'quote
                   `(column :width (px 120) :height (vh 100) :overflow scroll
                      ,@(cl-loop for row below 100
                                 collect `(box ,(format "row-%02d" row)))))
             (current-buffer)))
          (let ((standard-output (lambda (_character))))
            (cl-letf (((symbol-function 'ebox-playground-scroll-evaluator--measure)
                       (lambda (region steps &optional cold)
                         (let ((state (ebox--scroll-get-state region)))
                           (should-not (plist-get state :content-lines-complete-p))
                           (should (plist-get state :render-content-prefix))
                           (setq initial-capacity
                                 (- (length (plist-get state :content-lines))
                                    (plist-get state :content-height)))
                           (should (> steps initial-capacity)))
                         (funcall measure region steps cold))))
              (setq reports (ebox-playground-scroll-evaluator-run
                             file 121 40 8 '(:cold t)))))
          (should (= (length reports) 1))
          (let ((report (car reports)))
            (should (= (plist-get report :start-offset) 0))
            (should (= (plist-get report :end-offset) 40))
            (should (> (plist-get report :end-offset) initial-capacity))
            (should (> (plist-get report :prefix-renders) 0))
            (should (= (plist-get report :materializations) 0))
            (should (= (plist-get report :root-renders) 0))
            (should-not (plist-get report :content-complete-p))
            (should-not (plist-get report :max-offset))
            (should (plist-get report :fresh-render-parity)))
          (should (equal buffers (buffer-list))))
      (delete-file file))))

(ert-deftest ebox-playground-scroll-evaluator-counts-materialization-producers ()
  "A full-content producer is counted once, and its completed-state no-op is not."
  (let ((state (list :materialize-content-lines
                     (lambda (&rest _)
                       (list :content-lines '("0" "1" "2") :content-height 1))))
        (ebox--scroll-global-state (make-hash-table :test 'eql)))
    (cl-letf (((symbol-function 'ebox--scroll-region-by)
               (lambda (region delta &optional _budget)
                 (setq state (ebox--scroll-state-materialize-lines region state))
                 delta)))
      (let ((report (ebox-playground-scroll-evaluator--measure -1 2 t)))
        (should (= (plist-get report :materializations) 1))
        (should (= (plist-get report :prefix-renders) 0))
        (should (plist-get state :content-lines-complete-p))))))

(ert-deftest ebox-playground-scroll-oracle-replays-named-and-anonymous-offsets ()
  "Fresh input restores root and nested offsets without depending on author IDs."
  (let ((buffer (generate-new-buffer " *ebox-scroll-oracle-nested*")))
    (unwind-protect
        (progn
          (ebox-render-to-buffer
           buffer
           (ebox-build
            '(column :width (px 120) :height (lh 7) :overflow scroll
               (box "before\nbefore")
               (row
                 (box :id "selected" :width (px 60) :height (lh 3) :overflow scroll
                   "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11")
                 (box :width (px 40) :height (lh 3) :overflow scroll
                   "a\nb\nc\nd\ne\nf\ng"))
               (box "after\nafter\nafter\nafter\nafter\nafter\nafter"))))
          (let* ((state (ebox--buffer-render-state buffer))
                 (root-region (plist-get (plist-get state :root-node) :region-id))
                 (selected (cdr (ebox-selector--region-target
                                 (ebox-region-resolve buffer "selected"))))
                 (regions (hash-table-keys (plist-get state :scroll-state-table))))
            (should (= (length regions) 3))
            (dolist (region regions)
              (unless (= region root-region)
                (should (= (ebox--scroll-region-by region (if (= region selected) 2 1) 2)
                           (if (= region selected) 2 1)))))
            (should (= (ebox--scroll-region-by root-region 1 1) 1))
            (should (ebox-playground-scroll-evaluator--fresh-parity buffer nil))
            (let* ((state (ebox--buffer-render-state buffer))
                   (node (ebox-runtime-index-get
                          (ebox-runtime-index-get selected (plist-get state :region-node-table))
                          (plist-get state :node-table)))
                   (offset (ebox-get node :scroll-offset)))
              (unwind-protect
                  (progn
                    (ebox-put node :scroll-offset 0)
                    (should-error
                     (ebox-playground-scroll-evaluator--fresh-parity buffer nil)))
                (ebox-put node :scroll-offset offset)))
            (should (ebox-playground-scroll-evaluator--fresh-parity buffer nil))))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest ebox-playground-scroll-evaluator-cold-capacity-error-and-options ()
  "Cold exhaustion reports the exact incomplete sample and releases resources."
  (let ((file (make-temp-file "ebox-scroll-evaluator-capacity-" nil ".ebox"))
        (buffers (buffer-list))
        (render (symbol-function 'ebox--render-layout)))
    (unwind-protect
        (progn
          (with-temp-file file
            (prin1 ''(column :width (px 120) :height (lh 2) :overflow scroll
                       (box "0\n1\n2\n3"))
                   (current-buffer)))
          (let ((failure (should-error
                          (ebox-playground-scroll-evaluator-run file 121 4 8 '(:cold t)))))
            (should (string-match-p "sample 3/4 after 2 completed steps"
                                    (error-message-string failure))))
          (dolist (options '((:cold yes) (:cold) (:unknown t)
                             (:region-id (invalid)) (:cold t :cold nil)))
            (should-error (ebox-playground-scroll-evaluator-run file 121 3 8 options)))
          (should-error (ebox-playground-scroll-evaluator-run
                         file 121 3 8 '(:region-id "missing")))
          (should (equal buffers (buffer-list)))
          (should (eq render (symbol-function 'ebox--render-layout))))
      (delete-file file))))

(ert-deftest ebox-playground-scroll-evaluator-timeout-restores-instrumentation ()
  "A deadline between motions fails explicitly and removes temporary counters."
  (let ((clock 0)
        (motions 0)
        (functions
         (mapcar (lambda (symbol) (cons symbol (symbol-function symbol)))
                 '(ebox-surface--render-candidate ebox-surface--apply-node-style
                   ebox-surface--compute-node-style
                   ebox--render-scroll-window-source
                   ebox--scroll-state-materialize-lines))))
    (cl-letf (((symbol-function 'float-time)
               (lambda (&optional _) (cl-incf clock 11)))
              ((symbol-function 'ebox--scroll-region-by)
               (lambda (_region delta &optional _budget)
                 (cl-incf motions)
                 delta)))
      (let ((failure (should-error
                      (ebox-playground-scroll-evaluator--measure 0 3 t))))
        (should (string-match-p "exceeded 30 seconds after 1/3 samples"
                                (error-message-string failure)))))
    (should (= motions 1))
    (dolist (entry functions)
      (should (eq (cdr entry) (symbol-function (car entry)))))))

(ert-deftest ebox-playground-effective-viewport-prefers-window-text-width ()
  "Interactive viewport resolution should prefer the window text width."
  (let ((ebox-viewport-width nil))
    (cl-letf (((symbol-function 'window-body-width)
               (lambda (&optional _window _pixelwise) 987))
              ((symbol-function 'frame-char-width)
               (lambda (&optional _frame) 8)))
      (should (= (ebox-playground--effective-viewport-width
                  (selected-window))
                 971)))))

(ert-deftest ebox-playground-window-viewport-uses-ebox-sampler ()
  "A preview and the Ebox resize controller share one viewport sample."
  (cl-letf (((symbol-function 'ebox-viewport-window-width)
             (lambda (_window) 979)))
    (should (= (ebox-playground--window-viewport-width (selected-window))
               979))))

(ert-deftest ebox-playground-dsl-render-uses-window-width-for-viewport ()
  "C-c C-c should build viewport-dependent roots at the preview width."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-viewport-render.ebox*")
        (window-width 987))
    (unwind-protect
        (cl-letf (((symbol-function 'window-body-width)
                   (lambda (&optional _window _pixelwise) window-width))
                  ((symbol-function 'frame-char-width)
                   (lambda (&optional _frame) 8)))
          (with-temp-buffer
            (setq buffer-file-name "/tmp/ebox-playground-viewport-render.ebox")
            (insert "'(box :width (vw 100) :height (lh 1) \"viewport\")")
            (ebox-dsl-mode)
            (ebox-dsl-render)
            (with-current-buffer preview
              (should (= (ebox-playground-test--max-line-width
                          (buffer-string))
                         (- window-width 16))))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-dsl-render-grid-reference-fits-preview-viewport ()
  "C-c C-c should render the real Grid reference inside the preview viewport."
  (let* ((path (expand-file-name "examples/grid-reference.ebox"
                                 ebox-playground-directory))
         (preview (format "*Ebox Preview: %s*" path))
         (window-width 699)
         (viewport 683))
    (unwind-protect
        (cl-letf (((symbol-function 'window-body-width)
                   (lambda (&optional _window _pixelwise) window-width))
                  ((symbol-function 'frame-char-width)
                   (lambda (&optional _frame) 8)))
          (delete-other-windows)
          (with-temp-buffer
            (setq buffer-file-name path)
            (insert-file-contents path)
            (ebox-dsl-mode)
            (ebox-dsl-render)
            (with-current-buffer preview
              (should (cl-every
                       (lambda (width) (<= width viewport))
                       (ebox-playground-test--line-widths
                        (buffer-string)))))))
      (delete-other-windows)
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-dsl-render-keeps-source-left-of-preview ()
  "C-c C-c should keep the source left of its rendered preview."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-two-window.ebox*")
        source)
    (unwind-protect
        (progn
          (delete-other-windows)
          (with-temp-buffer
            (setq source (current-buffer)
                  buffer-file-name "/tmp/ebox-playground-two-window.ebox")
            (insert "'(box :width (vw 100) :height (lh 1) \"two windows\")")
            (ebox-dsl-mode)
            (cl-letf (((symbol-function 'window-body-width)
                       (lambda (&optional _window _pixelwise) 987))
                      ((symbol-function 'frame-char-width)
                       (lambda (&optional _frame) 8)))
              (ebox-dsl-render))
            (let* ((windows
                    (sort (copy-sequence (window-list nil 'no-minibuf))
                          (lambda (left right)
                            (< (window-left-column left)
                               (window-left-column right)))))
                   (left (car windows))
                   (right (cadr windows)))
              (should (= (length windows) 2))
              (should (eq (window-buffer left) source))
              (should (eq (window-buffer right) (get-buffer preview))))))
      (delete-other-windows)
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-preview-resizes-through-ebox-viewport-update ()
  "A queued preview resize should publish an incremental viewport update."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-viewport-resize.ebox*")
        (window-width 987)
        (ebox--window-size-change-pending-frames nil)
        (ebox--window-size-change-timer nil)
        scheduled)
    (unwind-protect
        (cl-letf (((symbol-function 'window-body-width)
                   (lambda (&optional _window _pixelwise) window-width))
                  ((symbol-function 'frame-char-width)
                   (lambda (&optional _frame) 8))
                  ((symbol-function 'run-at-time)
                   (lambda (_time _repeat function &rest args)
                     (setq scheduled (cons function args))
                     'queued-viewport)))
          (with-temp-buffer
            (setq buffer-file-name "/tmp/ebox-playground-viewport-resize.ebox")
            (insert "'(box :width (vw 100) :height (lh 1) \"viewport\")")
            (ebox-dsl-mode)
            (ebox-dsl-render)
            (setq window-width 1234)
            (with-current-buffer preview
              (let ((window (get-buffer-window (current-buffer))))
                (should (memq #'ebox--window-size-change
                              window-size-change-functions))
                (let ((noninteractive nil))
                  (ebox--window-size-change (window-frame window))))
              (should (= (ebox-playground-test--max-line-width
                          (buffer-string))
                         (- 987 16))))
            (should scheduled)
            (apply (car scheduled) (cdr scheduled))
            (with-current-buffer preview
              (should (= (ebox-playground-test--max-line-width
                          (buffer-string))
                         (- window-width 16)))
              (let ((report (ebox-buffer-update-report (current-buffer))))
                (should (eq (plist-get report :constraint-source) 'viewport))
                (should (eq (plist-get report :strategy) 'owner-rerender))))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-flex-reference-retains-stable-scroll-reflow ()
  "The Flex reference should retain scroll state when its subtree is stable."
  (let* ((ebox-runtime-idle-prewarm nil)
         (ebox-runtime-idle-reflow-cache-prewarm nil)
         (path (expand-file-name "examples/flex-reference.ebox"
                                ebox-playground-directory))
         (name " *ebox-playground-flex-scroll-reflow-test*"))
    (unwind-protect
        (let* ((buffer (ebox-render-to-buffer
                        name (ebox-playground-view path 720)))
               (old-state (ebox--buffer-render-state buffer))
               (old-root-object
                (plist-get (plist-get old-state :root-node)
                           :surface-object))
               (old-scroll-ids (copy-sequence
                                (plist-get old-state :scroll-region-ids)))
               (old-scroll-offsets
                (mapcar
                 (lambda (region-id)
                   (plist-get
                    (gethash region-id
                             (plist-get old-state :scroll-state-table))
                    :scroll-offset))
                 old-scroll-ids))
               (report (ebox-rerender-buffer-with-context buffer 326 36))
               (new-state (ebox--buffer-render-state buffer))
               (new-root-object
                (plist-get (plist-get new-state :root-node)
                           :surface-object))
               (widths
                (ebox-playground-test--line-widths
                 (with-current-buffer buffer
                   (buffer-string)))))
          (should (eq (plist-get report :projection-kind)
                      'viewport-reflow))
          (should (plist-get report :runtime-published))
          (should (eq old-root-object new-root-object))
          (should (cl-every
                   (lambda (region-id)
                     (member region-id
                             (plist-get new-state :scroll-region-ids)))
                   old-scroll-ids))
          (should (equal old-scroll-offsets
                         (mapcar
                          (lambda (region-id)
                            (plist-get
                             (gethash region-id
                                      (plist-get new-state
                                                 :scroll-state-table))
                             :scroll-offset))
                          old-scroll-ids)))
          (should (cl-every (lambda (width) (<= width 326)) widths)))
      (when (get-buffer name)
        (kill-buffer name)))))

(ert-deftest ebox-playground-preview-uses-canvas-redisplay-settings ()
  "A preview should suppress text-editor redisplay artifacts."
  (let ((preview " *ebox-playground-preview-settings-test*"))
    (unwind-protect
        (progn
          (ebox-playground--render-input-to-buffer
           preview (ebox-build '(box "preview")) 240)
          (with-current-buffer preview
            (should truncate-lines)
            (should-not (assq 'truncation fringe-indicator-alist))
            (should-not (assq 'continuation fringe-indicator-alist))
            (should-not bidi-display-reordering)
            (should (eq bidi-paragraph-direction 'left-to-right))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-preview-display-settings-roll-back-on-render-error ()
  "A failed preview render should restore its prior display settings."
  (let ((preview " *ebox-playground-preview-settings-rollback-test*"))
    (unwind-protect
        (progn
          (with-current-buffer (get-buffer-create preview)
            (setq-local truncate-lines nil)
            (setq-local face-remapping-alist
                        '((default (:background "#111111")))))
          (cl-letf (((symbol-function 'ebox-render-to-buffer)
                     (lambda (&rest _)
                       (error "Injected preview render failure"))))
            (should-error
             (ebox-playground--render-to-preview-buffer
              preview (ebox-build '(box "rollback")))))
          (with-current-buffer preview
            (should-not truncate-lines)
            (should (equal face-remapping-alist
                           '((default (:background "#111111")))))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-flex-reference-preserves-buffer-chrome ()
  "Root canvas paint should preserve the ordinary buffer face and mode line."
  (let ((preview " *ebox-playground-flex-canvas-test*")
        (path (expand-file-name "examples/flex-reference.ebox"
                               ebox-playground-directory)))
    (unwind-protect
        (progn
          (ebox-playground--render-input-to-buffer
           preview (ebox-playground-view path 720) 720)
          (with-current-buffer preview
            (should-not face-remapping-alist)
            (should (equal mode-line-format (default-value 'mode-line-format)))
            (let ((display-signature (ebox--current-display-signature))
                  (matching-cache-entry-p nil)
                  (render-cache
                   (plist-get (ebox--buffer-render-state (current-buffer))
                              :render-cache)))
              (maphash
               (lambda (effective-key _entry)
                 (let ((signature (cadr effective-key)))
                   (when (and (consp signature)
                              (equal display-signature (car signature)))
                     (setq matching-cache-entry-p t))))
               render-cache)
              (should matching-cache-entry-p))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-grid-reference-fits-preview-widths ()
  "The Grid reference should stay inside split-preview width."
  (let* ((viewport 691)
         (path (expand-file-name "examples/grid-reference.ebox"
                                 ebox-playground-directory))
         (text (substring-no-properties
                (ebox-render (ebox-playground-view path viewport)))))
    (should (cl-every (lambda (width) (<= width viewport))
                      (ebox-playground-test--line-widths text)))))

(ert-deftest ebox-playground-grid-reference-separators-paint-the-viewport ()
  "Grid reference separator Boxes should fill the active viewport canvas."
  (let ((path (expand-file-name "examples/grid-reference.ebox"
                                ebox-playground-directory)))
    (let ((separators
           (cl-remove-if-not
            #'ebox-playground-test--separator-form-p
            (ebox-playground-test--forms-named
             'box (ebox-playground-test--read-layout path)))))
      (should (= (length separators) 11)))
    (dolist (viewport '(691 720))
      (let* ((ebox-viewport-width viewport)
             (form (ebox-playground-test--read-layout path))
             ;; Pin this canvas contract without changing the author's root.
             (_ (setcdr form (plist-put (cdr form) :width '(vw 100))))
             (lines (ebox-string-lines
                     (ebox-render (ebox-build form))))
             (separator-lines
              (cl-remove-if-not
               (lambda (line)
                 (let ((width (ebox-playground-test--absolute-space-width line)))
                   (and width (= width viewport))))
               lines)))
        (should (= (length separator-lines) 11))
        (dolist (line separator-lines)
          (should (= (ebox-playground-test--absolute-space-width line)
                     viewport))
          (should (= (ebox-string-pixel-width line) viewport))
          (should (equal (get-text-property 0 'face line)
                         '(:background "#FAF7F0"))))))))

(ert-deftest ebox-playground-default-fixture-separators-paint-the-canvas ()
  "The default fixture separators should cover the preview canvas."
  (let* ((ebox-viewport-width 720)
         (form (ebox-playground-test--read-layout ebox-playground-default-file))
         (_ (setcdr form (plist-put (cdr form) :width '(vw 100))))
         (lines (ebox-string-lines
                 (ebox-render (ebox-build form))))
         (separators 0))
    (dolist (line lines)
      (when (let ((width (ebox-playground-test--absolute-space-width line)))
              (and width (= width 720)))
        (setq separators (1+ separators))
        (should (equal (get-text-property 0 'face line)
                       '(:background "#FAF7F0")))))
    (should (> separators 0))))

(ert-deftest ebox-playground-separators-follow-a-narrower-root ()
  "Explicit and auto gallery separators fill a root narrower than the viewport."
  (dolist (fixture '(("flex-reference.ebox" . 12)
                     ("grid-reference.ebox" . 11)))
    (dolist (omit-width '(nil t))
      (let* ((ebox-viewport-width 1000)
             (path (expand-file-name (concat "examples/" (car fixture))
                                     ebox-playground-directory))
             (form (ebox-playground-test--read-layout path))
             (parent-width 900))
        ;; Inspect the entire gallery independently of the author's height.
        (setcdr form (plist-put (cdr form) :width '(vw 90)))
        (setcdr form (plist-put (cdr form) :height 'auto))
        (cl-remf (cdr form) :overflow)
        (setcdr form (append '(:overflow visible) (cdr form)))
        (dolist (box (ebox-playground-test--form-children form))
          (when (and (eq (car-safe box) 'box)
                     (null (ebox-playground-test--form-children box)))
            (should (equal (plist-get (cdr box) :height) '(lh 1)))
            (if omit-width
                (cl-remf (cdr box) :width)
              (setcdr box (plist-put (cdr box) :width 'stretch)))))
        (let* ((lines (ebox-string-lines (ebox-render (ebox-build form))))
               (separators
                (cl-remove-if-not
                 (lambda (line)
                   (let ((face (get-text-property 0 'face line)))
                     (and (ebox-playground-test--absolute-space-width line)
                          (or (equal face '(:background "#FAF7F0"))
                              (equal (car-safe face)
                                     '(:background "#FAF7F0"))))))
                 lines)))
          (should (= (length separators) (cdr fixture)))
          (dolist (line separators)
            (should (= (ebox-playground-test--absolute-space-width line)
                       parent-width))))))))

(ert-deftest ebox-playground-grid-reference-covers-public-properties ()
  "The Grid reference should cover every public property and supported value form."
  (let ((source
         (prin1-to-string
          (ebox-playground-test--read-layout
           (expand-file-name "examples/grid-reference.ebox"
                             ebox-playground-directory)))))
    (dolist (property '(:grid-template-columns :grid-template-rows
                        :grid-auto-columns :grid-auto-rows :grid-auto-flow
                        :gap :row-gap :column-gap
                        :justify-items :align-items :justify-content
                        :align-content :grid-column :grid-row
                        :grid-column-span :grid-row-span))
      (should (string-match-p (regexp-quote (symbol-name property)) source)))
    (dolist (fragment ebox-playground-test--grid-value-forms)
      (should (string-match-p (regexp-quote fragment) source)))))

(ert-deftest ebox-playground-opens-and-closes-buffer ()
  "The public open and close commands should own their buffer lifecycle."
  (let ((name " *ebox-playground-test*"))
    (unwind-protect
        (progn
          (ebox-playground-open name)
          (should (buffer-live-p (get-buffer name)))
          (with-current-buffer name
            (should (string-match-p "Ebox CSS Grid Reference"
                                    (buffer-string)))))
      (ebox-playground-close name))))

(ert-deftest ebox-playground-fits-a-compact-gui-window ()
  "Keep the default gallery inside a compact 720 px preview canvas."
  (let* ((viewport 720)
         (ebox-viewport-width viewport)
         (form (ebox-playground-test--read-layout ebox-playground-default-file))
         (_ (setcdr form (plist-put (cdr form) :width '(vw 100))))
         (input (ebox-build form))
         (rendered (ebox-render input))
         (widths (mapcar #'ebox-string-pixel-width
                         (ebox-string-lines rendered)))
         (maximum (apply #'max widths)))
    (should (= maximum viewport))))

(ert-deftest ebox-playground-registers-ebox-file-mode ()
  "Open Ebox DSL files in the package-owned major mode."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/ebox-playground-mode-test.ebox")
    (set-auto-mode)
    (should (eq major-mode 'ebox-dsl-mode))
    (should (eq (key-binding (kbd "C-c C-c")) #'ebox-dsl-render))
    (should (string-match-p "C-c C-c" header-line-format))))

(ert-deftest ebox-playground-renders-ebox-file-mode-source ()
  "Render a file-mode buffer through the public Ebox build path."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-render-test.ebox*"))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name "/tmp/ebox-playground-render-test.ebox")
          (insert "'(box :width (px 240) \"Rendered from .ebox\")")
          (ebox-dsl-mode)
          (ebox-dsl-render)
          (should (eq (window-buffer (selected-window)) (current-buffer)))
          (should (get-buffer-window (get-buffer preview)))
          (with-current-buffer preview
            (should (string-match-p "Rendered from .ebox" (buffer-string)))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-evaluates-quoted-layout-as-data ()
  "Quoted layout lists and symbols reach Ebox without extra evaluation."
  (let* ((expected '(box :width (px 240) :padding ((lh 0) (px 4))
                        :text-align center "Literal values"))
         (form (ebox-playground--evaluate-form
                (ebox-playground--read-form
                 "'(box :width (px 240) :padding ((lh 0) (px 4))
                        :text-align center \"Literal values\")")))
         (node (ebox-build form)))
    (should (equal form expected))
    (should (equal (ebox-style-node-specified-value node :width) '(px 240)))
    (should (equal (ebox-style-node-specified-value node :padding-inline-start)
                   '(px 4)))
    (should (eq (ebox-style-node-specified-value node :text-align) 'center))))

(ert-deftest ebox-playground-evaluates-backquoted-property-expressions ()
  "Use ordinary unquote expressions to calculate property values."
  (let* ((form (ebox-playground--evaluate-form
                '(let ((width (ebox-playground-test--dynamic-width))
                       (color (ebox-playground-test--dynamic-color)))
                   `(box :width ,width :color ,color
                         :padding ((lh 0) (px 4)) :text-align center
                         "Dynamic property values"))))
         (node (ebox-build form)))
    (should (equal (ebox-style-node-specified-value node :width) '(px 240)))
    (should (equal (ebox-style-node-specified-value node :color) "#123456"))
    (should (equal
             (ebox-style-node-specified-value node :padding-inline-start)
             '(px 4)))
    (should (eq (ebox-style-node-specified-value node :text-align)
                'center))))

(ert-deftest ebox-playground-evaluates-lexical-children-and-text ()
  "Lexical closures can produce spliced child lists and dynamic text."
  (let* ((source
          "(let ((labels '(\"one\" \"two\"))
                 (make-child (let ((prefix \"Item: \"))
                               (lambda (label)
                                 `(box ,(concat prefix label))))))
             `(column :padding ((lh 0) (ch ,(length labels)))
                      ,@(mapcar make-child labels)))")
         (form (ebox-playground--evaluate-form
                (ebox-playground--read-form source)))
         (rendered (substring-no-properties (ebox-render (ebox-build form)))))
    (should (equal form '(column :padding ((lh 0) (ch 2))
                                (box "Item: one") (box "Item: two"))))
    (should (string-match-p "Item: one" rendered))
    (should (string-match-p "Item: two" rendered))))

(ert-deftest ebox-playground-does-not-evaluate-quoted-property-data ()
  "A property that resembles executable code remains literal data."
  (let ((form (ebox-playground--evaluate-form
               '(quote (box :width (error "Must remain data") "Text")))))
    (should (equal form
                   '(box :width (error "Must remain data") "Text")))))

(ert-deftest ebox-playground-rejects-multiple-or-incomplete-trailing-forms ()
  "Exactly one complete Elisp expression is allowed in a source file."
  (dolist (source '("'(box \"one\")\n'(box \"two\")"
                    "'(box \"one\")\n("
                    "'(box \"one\")\n\"unfinished"))
    (should-error (ebox-playground--read-form source) :type 'user-error))
  (should (equal (ebox-playground--read-form
                  "; Header\n'(box \"one\") ; Trailing comment\n")
                 '(quote (box "one")))))

(ert-deftest ebox-playground-file-and-buffer-share-elisp-evaluation ()
  "File previews and editor buffers build the same computed layout."
  (let* ((source "(let ((body \"Computed body\"))
                   `(box :width (px 240) ,body))")
         (file (make-temp-file "ebox-playground-evaluation-" nil ".ebox" source)))
    (unwind-protect
        (with-temp-buffer
          (insert source)
          (ebox-dsl-mode)
          (let ((buffer-form (ebox-playground--source-form)))
            (should (equal buffer-form '(box :width (px 240) "Computed body")))
            (should (equal (ebox-render (ebox-playground-view file 720))
                           (ebox-render (ebox-build buffer-form))))))
      (delete-file file))))

(defvar ebox-playground-test--companion-value nil
  "Dynamically isolated value written by temporary companion fixtures.")

(defvar ebox-playground-test--companion-loads 0
  "Number of source loads performed by a temporary companion fixture.")

(defun ebox-playground-test--call-with-companion-files (function)
  "Call FUNCTION with temporary DSL, companion, and preview names; clean up."
  (let* ((directory (make-temp-file "ebox-playground-companion-" t))
         (file (expand-file-name "example.ebox" directory))
         (companion (expand-file-name "example.el" directory))
         (preview (generate-new-buffer-name " *ebox-companion-test*"))
         (ebox-playground-test--companion-value nil)
         (ebox-playground-test--companion-loads 0)
         (load-history load-history))
    (unwind-protect
        (funcall function file companion preview)
      (ebox-playground-close preview)
      (ebox-playground-close (format "*Ebox Preview: %s*" file))
      (delete-directory directory t))))

(ert-deftest ebox-playground-scroll-oracle-retains-committed-business-capabilities ()
  "A scroll oracle keeps mutable callback identity and detects real property drift."
  (ebox-playground-test--call-with-companion-files
   (lambda (file companion preview)
     (with-temp-file companion
       (insert ";;; -*- lexical-binding: t; -*-\n")
       (prin1
        '(progn
           (cl-incf ebox-playground-test--companion-loads)
           (setq ebox-playground-test--companion-value
                 (let ((business (list 0 (make-symbol "fresh-business-state"))))
                   (list 'column :width '(px 120) :height '(lh 4) :overflow 'scroll
                         :help-echo (ebox-help-create
                                     (lambda () (format "state=%d" (car business))))
                         :keymap (ebox-keymap-create
                                  :activate (lambda () (cl-incf (car business))))
                         (list 'box :id "message"
                               "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11")))))
        (current-buffer)))
     (with-temp-file file (insert "ebox-playground-test--companion-value"))
     (let* ((standard-output (lambda (_character)))
            (reports (ebox-playground-scroll-evaluator-run file 121 3 8)))
       (should (= ebox-playground-test--companion-loads 1))
       (should (= (length reports) 2))
       (dolist (report reports) (should (plist-get report :fresh-render-parity))))
     (let* ((standard-output (lambda (_character)))
            (reports (ebox-playground-scroll-evaluator-run file 121 3 8 '(:cold t))))
       (should (= ebox-playground-test--companion-loads 2))
       (should (= (length reports) 1))
       (should (plist-get (car reports) :fresh-render-parity))
       (should (= (plist-get (car reports) :end-offset) 3)))
     (ebox-playground-open-file file preview)
     (with-current-buffer preview
       (let ((command (lookup-key (get-text-property (point-min) 'keymap)
                                  (kbd "RET"))))
         (call-interactively command)
         (should (equal (funcall (get-text-property (point-min) 'help-echo)
                                nil (current-buffer) (point-min))
                        "state=1")))
       (ebox-region-update "message" :color "#123456")
       (let* ((state (ebox--buffer-render-state (current-buffer)))
              (region (plist-get (plist-get state :root-node) :region-id)))
         (should (= (ebox--scroll-region-by region 1 1) 1)))
       (let* ((buffer (current-buffer))
              (revision (ebox-surface-buffer-revision buffer))
              (state (ebox--buffer-render-state buffer))
              (root (plist-get state :root-node))
              (offset (ebox-get root :scroll-offset))
              (render (symbol-function 'ebox--render-layout))
              (properties (copy-sequence (text-properties-at (point-min)))))
         (cl-letf (((symbol-function 'ebox-playground-view)
                    (lambda (&rest _) (ert-fail "Oracle reloaded source"))))
           (should (ebox-playground-scroll-evaluator--fresh-parity buffer file)))
         (should (= ebox-playground-test--companion-loads 3))
         (should (eq state (ebox--buffer-render-state buffer)))
         (should (= revision (ebox-surface-buffer-revision buffer)))
         (should (= offset (ebox-get root :scroll-offset)))
         (should (eq render (symbol-function 'ebox--render-layout)))
         (dolist (change
                  (list (cons 'keymap '(keymap (13 . ignore)))
                        ;; This callback returns the same help as the committed
                        ;; one.  Its different identity must still be detected.
                        (cons 'help-echo (lambda (&rest _) "state=1"))
                        (cons 'pointer 'hand)
                        (cons 'face '(:foreground "#654321"))
                        (cons 'display '(space :width (99)))))
           (unwind-protect
               (let ((inhibit-read-only t))
                 (put-text-property (point-min) (1+ (point-min))
                                    (car change) (cdr change))
                 (let ((output
                        (with-output-to-string
                          (should-not
                           (ebox-playground-scroll-evaluator--fresh-parity
                            buffer file)))))
                   (should (< (length output) 1000))
                   (should (string-match-p "char-codes=" output))
                   (should (string-match-p (symbol-name (car change)) output))
                   (should (string-match-p "line-widths=" output))
                   (should-not (string-match-p "closure\\|byte-code\\|fresh-business-state"
                                               output))))
             (let ((inhibit-read-only t))
               (set-text-properties (point-min) (1+ (point-min)) properties))))
         (should (ebox-playground-scroll-evaluator--fresh-parity buffer file)))))))

(ert-deftest ebox-playground-scroll-oracle-offset-and-error-cleanup ()
  "Reject inconsistent offsets and remove temporary advice after render errors."
  (let ((buffer (generate-new-buffer " *ebox-scroll-oracle-error*"))
        (render (symbol-function 'ebox--render-layout)))
    (unwind-protect
        (progn
          (ebox-render-to-buffer
           buffer (ebox-build '(column :width (px 120) :height (lh 2)
                                :overflow scroll (box "0\n1\n2\n3\n4"))))
          (let* ((state (ebox--buffer-render-state buffer))
                 (root (plist-get state :root-node))
                 (offset (ebox-get root :scroll-offset)))
            (unwind-protect
                (progn
                  (ebox-put root :scroll-offset (1+ offset))
                  (should-error
                   (ebox-playground-scroll-evaluator--fresh-parity buffer nil)))
              (ebox-put root :scroll-offset offset)))
          (cl-letf (((symbol-function 'ebox-render)
                     (lambda (_input) (error "Injected fresh render failure"))))
            (should-error
             (ebox-playground-scroll-evaluator--fresh-parity buffer nil)))
          (should (eq render (symbol-function 'ebox--render-layout)))
          (should (ebox-playground-scroll-evaluator--fresh-parity buffer nil)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest ebox-playground-scroll-oracle-mismatch-output-is-bounded ()
  "Mismatch output omits opaque capability bodies and handles a missing suffix."
  (let* ((payload (make-string 5000 ?x))
         (callback (lambda () payload))
         (actual (propertize "A" 'keymap (list 'keymap (cons 13 callback))
                             'help-echo callback))
         (fresh (propertize "A" 'keymap '(keymap (13 . ignore))
                            'help-echo "different"))
         (output (with-output-to-string
                   (ebox-playground-scroll-evaluator--report-mismatch actual fresh)
                   (ebox-playground-scroll-evaluator--report-mismatch "A" "AB"))))
    (should (< (length output) 1000))
    (should (string-match-p "changed-properties=.*keymap" output))
    (should (string-match-p "help-echo" output))
    (should (string-match-p "char-codes=nil/66" output))
    (should-not (string-match-p "closure\\|byte-code\\|xxxxx" output))))

(ert-deftest ebox-playground-companion-reloads-exact-source-before-file-evaluation ()
  "Reload an edited sibling source, regardless of bytecode or current directory."
  (ebox-playground-test--call-with-companion-files
   (lambda (file companion _preview)
     (with-temp-file file
       (insert "(list 'box ebox-playground-test--companion-value)"))
     (with-temp-file companion
       (insert ";;; -*- lexical-binding: t; -*-\n")
       (insert "(setq ebox-playground-test--companion-value \"stale bytecode\")"))
     (should (byte-compile-file companion))
     (let ((default-directory temporary-file-directory)
           (load-prefer-newer nil))
       (dolist (value '("first source" "edited source"))
         (with-temp-file companion
           (insert ";;; -*- lexical-binding: t; -*-\n")
           (prin1 `(progn
                     (cl-incf ebox-playground-test--companion-loads)
                     (setq ebox-playground-test--companion-value ,value))
                  (current-buffer)))
         ;; An ordinary suffix-selecting load would choose the newer .elc.
         (set-file-times companion
                         (time-subtract (current-time) (seconds-to-time 60)))
         (should (string-match-p
                  value (ebox-render (ebox-playground-view file 240))))
         (should-not (equal ebox-playground-test--companion-value
                            "stale bytecode"))))
     (should (= ebox-playground-test--companion-loads 2)))))

(ert-deftest ebox-playground-companion-source-command-reloads-and-preserves-preview ()
  "C-c C-c loads the sibling before unsaved DSL and preserves a failed preview."
  (ebox-playground-test--call-with-companion-files
   (lambda (file companion _preview)
     (with-temp-file file (insert "'(box \"Saved disk layout\")"))
     (save-window-excursion
       (with-temp-buffer
         (setq buffer-file-name file)
         (insert "(list 'box ebox-playground-test--companion-value)")
         (ebox-dsl-mode)
         (let ((default-directory temporary-file-directory)
               (preview (format "*Ebox Preview: %s*" file))
               (ebox-viewport-width 240))
           (dolist (value '("first buffer preview" "edited buffer preview"))
             (with-temp-file companion
               (insert ";;; -*- lexical-binding: t; -*-\n")
               (prin1 `(progn
                         (cl-incf ebox-playground-test--companion-loads)
                         (setq ebox-playground-test--companion-value ,value))
                      (current-buffer)))
             (call-interactively (key-binding (kbd "C-c C-c")))
             (with-current-buffer preview
               (should (string-match-p value (buffer-string)))
               (should-not (string-match-p "Saved disk layout" (buffer-string)))))
           (should (= ebox-playground-test--companion-loads 2))
           (let ((before (with-current-buffer preview (buffer-string)))
                 (existing (get-buffer preview)))
             (with-temp-file companion
               (insert ";;; -*- lexical-binding: t; -*-\n")
               (insert "(error \"Companion source failed\")"))
             (should-error
              (call-interactively (key-binding (kbd "C-c C-c"))))
             (should (eq existing (get-buffer preview)))
             (with-current-buffer preview
               (should (equal-including-properties before (buffer-string)))))))))))

(ert-deftest ebox-playground-companion-file-load-error-preserves-mounted-preview ()
  "A failed companion leaves existing preview contents and region handles live."
  (ebox-playground-test--call-with-companion-files
   (lambda (file companion preview)
     (with-temp-file file
       (insert "(list 'box :id \"kept\" ebox-playground-test--companion-value)"))
     (with-temp-file companion
       (insert ";;; -*- lexical-binding: t; -*-\n")
       (insert "(setq ebox-playground-test--companion-value \"Before failure\")"))
     (let* ((buffer (ebox-playground-open-file file preview))
            (handle (ebox-region-resolve buffer "kept"))
            (before (with-current-buffer buffer (buffer-string))))
       (with-temp-file companion
         (insert ";;; -*- lexical-binding: t; -*-\n")
         (insert "(error \"Companion load failed\")"))
       (should-error (ebox-playground-open-file file preview))
       (should (eq buffer (get-buffer preview)))
       (with-current-buffer buffer
         (should (equal-including-properties before (buffer-string))))
       (ebox-region-update handle :content "Still mounted")
       (with-current-buffer buffer
         (should (string-match-p "Still mounted" (buffer-string))))))))

(ert-deftest ebox-playground-companion-is-optional-and-bytecode-alone-is-ignored ()
  "Unpaired files and editor buffers keep working without loading stray bytecode."
  (ebox-playground-test--call-with-companion-files
   (lambda (file companion preview)
     (with-temp-file file (insert "'(box \"Standalone example\")"))
     (with-temp-file (concat companion "c")
       (insert "(error \"A bytecode-only companion must not load\")"))
     (let ((buffer (ebox-playground-open-file file preview)))
       (with-current-buffer buffer
         (should (string-match-p "Standalone example" (buffer-string)))))
     (with-temp-buffer
       (setq buffer-file-name file)
       (insert-file-contents file)
       (ebox-dsl-mode)
       (should (equal (ebox-playground--source-form)
                      '(box "Standalone example")))))))

(provide 'ebox-playground-tests)

;;; ebox-playground-tests.el ends here
