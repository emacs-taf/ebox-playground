;;; ebox-playground-tests.el --- Public Ebox example tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'ebox-playground)

(defconst ebox-playground-test--fixtures
  '("basic.ebox" "comprehensive.ebox" "flex-reference.ebox"
    "responsive-reference.ebox" "grid-reference.ebox")
  "Migrated and maintained `.ebox' fixtures in the playground package.")

(defun ebox-playground-test--dynamic-width ()
  "Return a list-valued width from executable DSL property code."
  '(240))

(defun ebox-playground-test--dynamic-color ()
  "Return a color from executable DSL property code."
  "#123456")

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

(defun ebox-playground-test--line-widths (text)
  "Return rendered pixel widths for every line in TEXT."
  (mapcar #'ebox-string-pixel-width
          (ebox-string-lines text)))

(defun ebox-playground-test--max-line-width (text)
  "Return the widest rendered pixel line in TEXT."
  (apply #'max (ebox-playground-test--line-widths text)))

(defconst ebox-playground-test--grid-value-forms
  '(":grid-template-columns '(auto auto)"
    ":grid-template-columns '((120) (74))"
    ":padding '(0 (2))"
    ":grid-template-columns '((192))"
    ":grid-template-columns '((88) (88))"
    ":grid-template-columns '(1fr 2fr)"
    ":grid-template-columns '((fr 1) (fr 2))"
    ":grid-template-columns '((minmax"
    ":grid-template-columns '((repeat"
    ":grid-template-rows '(auto auto)"
    ":grid-template-rows '(1fr 2fr)"
    ":grid-auto-columns '((64))"
    ":grid-auto-columns 'auto"
    ":grid-auto-columns '1fr"
    ":grid-auto-columns '((minmax"
    ":grid-auto-rows 2"
    ":grid-auto-rows 'auto"
    ":grid-auto-rows '1fr"
    ":grid-auto-rows '((minmax"
    ":grid-auto-flow 'row"
    ":grid-auto-flow 'column"
    ":gap 1"
    ":gap '(1 (14))"
    ":row-gap 2"
    ":column-gap '(28)"
    ":grid-row-gap 2"
    ":grid-column-gap '(28)"
    ":grid-column 2"
    ":grid-row 2"
    ":grid-column '(1 :span 2)"
    ":grid-row '(1 :span 2)"
    ":grid-column '(1 3)"
    ":grid-row '(1 3)"
    ":grid-column-span 2"
    ":grid-row-span 2"
    ":justify-items 'start"
    ":justify-items 'center"
    ":justify-items 'end"
    ":justify-items 'stretch"
    ":justify-items 'normal"
    ":align-items 'start"
    ":align-items 'center"
    ":align-items 'end"
    ":align-items 'stretch"
    ":align-items 'normal"
    ":justify-content 'start"
    ":justify-content 'center"
    ":justify-content 'end"
    ":justify-content 'space-between"
    ":justify-content 'space-around"
    ":justify-content 'space-evenly"
    ":justify-content 'stretch"
    ":justify-content 'normal"
    ":align-content 'start"
    ":align-content 'center"
    ":align-content 'end"
    ":align-content 'space-between"
    ":align-content 'space-around"
    ":align-content 'space-evenly"
    ":align-content 'stretch"
    ":align-content 'normal")
  "Public Grid property/value fragments required in the reference fixture.")

(ert-deftest ebox-playground-tinted-content-has-explicit-ink ()
  "Every tinted content box in the public fixtures should set its text color."
  (dolist (file (append ebox-playground-test--fixtures
                        '("public-layout-gallery.ebox")))
    (let ((form (ebox-playground--read-file
                 (expand-file-name (concat "examples/" file)
                                   ebox-playground-directory))))
      (dolist (box (ebox-playground-test--boxes form))
        (let ((properties (cdr box)))
          (when (and (memq :content properties)
                     (memq :bgcolor properties))
            (should (memq :color properties))))))))

(ert-deftest ebox-playground-uses-only-public-layout-apis ()
  "The example should build and render through the public Ebox entry point."
  (let* ((node (ebox-playground-view))
         (rendered (substring-no-properties (ebox-render node))))
    (should (eq (plist-get node :ebox-type) 'stack))
    (dolist (label '("Ebox Playground" "FIXED + FRACTIONAL"
                     "EXPLICIT PLACEMENT" "PUBLIC COMPOSITION"))
      (should (string-match-p (regexp-quote label) rendered)))))

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

(ert-deftest ebox-playground-effective-viewport-prefers-window-text-width ()
  "Interactive viewport resolution should prefer the window text width."
  (let ((ebox-viewport-width nil))
    (cl-letf (((symbol-function 'window-body-width)
               (lambda (&optional _window _pixelwise) 987))
              ((symbol-function 'frame-char-width)
               (lambda (&optional _frame) 8)))
      (should (= (ebox-playground--effective-viewport-width
                  (selected-window))
                 979)))))

(ert-deftest ebox-playground-window-viewport-leaves-display-reserve ()
  "A preview viewport should leave one character column for redisplay."
  (cl-letf (((symbol-function 'window-body-width)
             (lambda (&optional _window _pixelwise) 987))
            ((symbol-function 'frame-char-width)
             (lambda (&optional _frame) 8)))
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
            (insert "(box :content \"viewport\" :width '(viewport) :height 1)")
            (ebox-dsl-mode)
            (ebox-dsl-render)
            (with-current-buffer preview
              (should (= (ebox-playground-test--max-line-width
                          (buffer-string))
                         (- window-width 8))))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-dsl-render-grid-reference-fits-preview-viewport ()
  "C-c C-c should render the real Grid reference inside the preview viewport."
  (let* ((path (expand-file-name "examples/grid-reference.ebox"
                                 ebox-playground-directory))
         (preview (format "*Ebox Preview: %s*" path))
         (window-width 699)
         (viewport 691))
    (unwind-protect
        (cl-letf (((symbol-function 'window-body-width)
                   (lambda (&optional _window _pixelwise) window-width))
                  ((symbol-function 'frame-char-width)
                   (lambda (&optional _frame) (- window-width viewport))))
          (delete-other-windows)
          (with-temp-buffer
            (setq buffer-file-name path)
            (insert-file-contents path)
            (ebox-dsl-mode)
            (ebox-dsl-render)
            (with-current-buffer preview
              (should (= ebox-playground--preview-viewport-width viewport))
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
            (insert "(box :content \"two windows\" :width '(viewport) :height 1)")
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
  "A preview resize should publish an incremental Ebox viewport update."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-viewport-resize.ebox*")
        (window-width 987)
        (ebox-playground-resize-idle-delay 0))
    (unwind-protect
        (cl-letf (((symbol-function 'window-body-width)
                   (lambda (&optional _window _pixelwise) window-width))
                  ((symbol-function 'frame-char-width)
                   (lambda (&optional _frame) 8)))
          (with-temp-buffer
            (setq buffer-file-name "/tmp/ebox-playground-viewport-resize.ebox")
            (insert "(box :content \"viewport\" :width '(viewport) :height 1)")
            (ebox-dsl-mode)
            (ebox-dsl-render)
            (setq window-width 1234)
            (with-current-buffer preview
              (let ((window (get-buffer-window (current-buffer))))
                (should (memq #'ebox-playground--window-size-change
                              window-size-change-functions))
                (ebox-playground--window-size-change (window-frame window))
                (should (timerp ebox-playground--resize-timer))
                ;; Batch Emacs does not service idle timers from `sit-for'.
                (ebox-playground--resize-preview (current-buffer) window)))
            (with-current-buffer preview
              (should (= (ebox-playground-test--max-line-width
                          (buffer-string))
                         (- window-width 8)))
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
          (ebox-playground--render-node-to-buffer preview "preview" 240)
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
              preview (ebox-create :content "rollback"))))
          (with-current-buffer preview
            (should-not truncate-lines)
            (should (equal face-remapping-alist
                           '((default (:background "#111111")))))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-flex-reference-paints-root-canvas ()
  "The Flex reference should carry its canvas color into the preview face."
  (let ((preview " *ebox-playground-flex-canvas-test*")
        (path (expand-file-name "examples/flex-reference.ebox"
                               ebox-playground-directory)))
    (unwind-protect
        (progn
          (ebox-playground--render-node-to-buffer
           preview (ebox-playground-view path 720) 720)
          (with-current-buffer preview
            (should (equal face-remapping-alist
                           '((default (:background "#FAF7F0")))))
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

(ert-deftest ebox-playground-grid-reference-spacers-paint-the-viewport ()
  "Grid reference separators should fill the active viewport canvas."
  (let ((path (expand-file-name "examples/grid-reference.ebox"
                                ebox-playground-directory)))
    (let ((spacers (ebox-playground-test--forms-named
                    'spacer (ebox-playground--read-file path))))
      (should (= (length spacers) 11))
      (dolist (spacer spacers)
        (should (equal (plist-get (cdr spacer) :width)
                       '(quote (viewport))))
        (should (equal (plist-get (cdr spacer) :bgcolor) "#FAF7F0"))))
    (dolist (viewport '(691 720))
      (let* ((ebox-viewport-width viewport)
             (lines (ebox-string-lines
                     (ebox-render (ebox-playground-view path viewport))))
             (spacer-lines
              (cl-remove-if-not
               (lambda (line)
                 (equal (get-text-property 0 'display line)
                        `(space :width (,viewport))))
               lines)))
        (should (= (length spacer-lines) 11))
        (dolist (line spacer-lines)
          (should (equal (get-text-property 0 'display line)
                         `(space :width (,viewport))))
          (should (= (ebox-string-pixel-width line) viewport))
          (should (equal (get-text-property 0 'face line)
                         '(:background "#FAF7F0"))))))))

(ert-deftest ebox-playground-public-layout-gallery-fixed-spacers-paint-the-canvas ()
  "The default public gallery fixed separators should keep canvas coverage."
  (let* ((path (expand-file-name "examples/public-layout-gallery.ebox"
                                 ebox-playground-directory))
         (lines (ebox-string-lines
                 (ebox-render (ebox-playground-view path))))
         (separators 0))
    (dolist (line lines)
      (when (equal (get-text-property 0 'display line)
                   '(space :width (720)))
        (setq separators (1+ separators))
        (should (equal (get-text-property 0 'face line)
                       '(:background "#FAF7F0")))))
    (should (> separators 0))))

(ert-deftest ebox-playground-grid-reference-covers-public-properties ()
  "The Grid reference should cover every public property and supported value form."
  (let ((source (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "examples/grid-reference.ebox"
                                     ebox-playground-directory))
                  (buffer-string))))
    (dolist (property '(:grid-template-columns :grid-template-rows
                        :grid-auto-columns :grid-auto-rows :grid-auto-flow
                        :grid-row-gap :grid-column-gap :gap :row-gap
                        :column-gap
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
            (should (string-match-p "Ebox Playground" (buffer-string)))))
      (ebox-playground-close name))))

(ert-deftest ebox-playground-fits-a-compact-gui-window ()
  "Keep the gallery wide enough to teach Grid without crossing 800 px frames."
  (let* ((node (ebox-playground-view))
         (gallery-width (plist-get (car (plist-get node :children)) :width))
         (rendered (ebox-render node))
         (widths (mapcar #'ebox-string-pixel-width
                         (ebox-string-lines rendered)))
         (maximum (apply #'max widths)))
    (should (= maximum gallery-width))
    (should (<= gallery-width 760))))

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
          (insert "(box :content \"Rendered from .ebox\" :width '(240))")
          (ebox-dsl-mode)
          (ebox-dsl-render)
          (should (eq (window-buffer (selected-window)) (current-buffer)))
          (should (get-buffer-window (get-buffer preview)))
          (with-current-buffer preview
            (should (string-match-p "Rendered from .ebox" (buffer-string)))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(ert-deftest ebox-playground-evaluates-property-expressions ()
  "Evaluate executable property values while preserving quoted constants."
  (let* ((form (ebox-playground--evaluate-form
                '(box :content "Dynamic property values"
                      :width (ebox-playground-test--dynamic-width)
                      :color (ebox-playground-test--dynamic-color)
                      :padding '(0 (4))
                      :text-align 'center)))
         (node (ebox-build form)))
    (should (equal (plist-get node :width) 240))
    (should (equal (plist-get node :color) "#123456"))
    (should (equal (plist-get node :padding-left-pixel) 4))
    (should (eq (plist-get node :text-align) 'center))))

(provide 'ebox-playground-tests)

;;; ebox-playground-tests.el ends here
