;;; ebox-playground-tests.el --- Public API acceptance -*- lexical-binding: t; -*-

;;; Commentary:
;; Test supported package inputs, outputs, errors and lifecycle.
;; Internal implementation details are outside this contract.

;;; Code:
(require 'cl-lib)
(require 'ert)
(require 'ebox-playground)

(defun ebox-playground-test--line-widths (text)
  "Return rendered pixel widths for every line in TEXT."
  (mapcar #'ebox-string-pixel-width
          (split-string text "\n")))

(defun ebox-playground-test--max-line-width (text)
  "Return the widest rendered pixel line in TEXT."
  (apply #'max (ebox-playground-test--line-widths text)))

(ert-deftest ebox-playground-dsl-render-uses-window-width-for-viewport ()
  "C-c C-c should build viewport-dependent roots at the preview width.
The viewport is Ebox's display-safe width for the preview window, so the
root fills exactly the width `ebox-viewport-window-width' reports."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-viewport-render.ebox*"))
    (unwind-protect
        (progn
          (with-temp-buffer
            (setq buffer-file-name "/tmp/ebox-playground-viewport-render.ebox")
            (insert "'(box :width (vw 100) :height (lh 1) \"viewport\")")
            (ebox-playground-mode)
            (ebox-playground-render))
          (let ((window (get-buffer-window preview)))
            (should window)
            (with-current-buffer preview
              (should (= (ebox-playground-test--max-line-width
                          (buffer-string))
                         (ebox-viewport-window-width window))))))
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
            (ebox-playground-mode)
            (ebox-playground-render)
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
            (ebox-playground-mode)
            (cl-letf (((symbol-function 'window-body-width)
                       (lambda (&optional _window _pixelwise) 987))
                      ((symbol-function 'frame-char-width)
                       (lambda (&optional _frame) 8)))
              (ebox-playground-render))
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

(ert-deftest ebox-playground-registers-ebox-file-mode ()
  "Open Ebox DSL files in the package-owned major mode."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/ebox-playground-mode-test.ebox")
    (set-auto-mode)
    (should (eq major-mode 'ebox-playground-mode))
    (should (eq (key-binding (kbd "C-c C-c")) #'ebox-playground-render))
    (should (string-match-p "C-c C-c" header-line-format))))

(ert-deftest ebox-playground-renders-ebox-file-mode-source ()
  "Render a file-mode buffer through the public Ebox build path."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-render-test.ebox*"))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name "/tmp/ebox-playground-render-test.ebox")
          (insert "'(box :width (px 240) \"Rendered from .ebox\")")
          (ebox-playground-mode)
          (ebox-playground-render)
          (should (eq (window-buffer (selected-window)) (current-buffer)))
          (should (get-buffer-window (get-buffer preview)))
          (with-current-buffer preview
            (should (string-match-p "Rendered from .ebox" (buffer-string)))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(provide 'ebox-playground-tests)
;;; ebox-playground-tests.el ends here
