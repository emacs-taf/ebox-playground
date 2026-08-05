;;; ebox-playground-tests.el --- Public Ebox example tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'ebox-playground)

(ert-deftest ebox-playground-uses-only-public-layout-apis ()
  "The example should build and render through the public Ebox entry point."
  (let* ((node (ebox-playground-view))
         (rendered (substring-no-properties (ebox-render node))))
    (should (eq (plist-get node :ebox-type) 'stack))
    (dolist (label '("Ebox Playground" "FIXED + FRACTIONAL"
                     "EXPLICIT PLACEMENT" "PUBLIC COMPOSITION"))
      (should (string-match-p (regexp-quote label) rendered)))))

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

(provide 'ebox-playground-tests)

;;; ebox-playground-tests.el ends here
