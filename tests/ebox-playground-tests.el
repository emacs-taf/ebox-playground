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

(ert-deftest ebox-playground-fixed-reference-spacers-paint-the-canvas ()
  "Fixed-width reference separators should keep a continuous canvas surface."
  (dolist (file '("grid-reference.ebox" "public-layout-gallery.ebox"))
    (let* ((path (expand-file-name (concat "examples/" file)
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
      (should (> separators 0)))))

(ert-deftest ebox-playground-grid-reference-covers-public-properties ()
  "The Grid reference should name every public Grid property in the fixture."
  (let ((source (with-temp-buffer
                  (insert-file-contents
                   (expand-file-name "examples/grid-reference.ebox"
                                     ebox-playground-directory))
                  (buffer-string))))
    (dolist (property '(:grid-template-columns :grid-template-rows
                        :grid-auto-columns :grid-auto-rows :grid-auto-flow
                        :grid-row-gap :grid-column-gap :gap
                        :justify-items :align-items :justify-content
                        :align-content :grid-column :grid-row
                        :grid-column-span :grid-row-span))
      (should (string-match-p (regexp-quote (symbol-name property)) source)))))

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
          (should (eq (window-buffer (selected-window))
                      (get-buffer preview)))
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
