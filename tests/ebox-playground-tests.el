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
    (should-not (string-match-p "PUBLIC COMPOSITION" runner))))

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
    (should (eq major-mode 'ebox-dsl-mode))))

(ert-deftest ebox-playground-renders-ebox-file-mode-source ()
  "Render a file-mode buffer through the public Ebox build path."
  (let ((preview "*Ebox Preview: /tmp/ebox-playground-render-test.ebox*"))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name "/tmp/ebox-playground-render-test.ebox")
          (insert "(box :content \"Rendered from .ebox\" :width (240))")
          (ebox-dsl-mode)
          (ebox-dsl-render)
          (with-current-buffer preview
            (should (string-match-p "Rendered from .ebox" (buffer-string)))))
      (when (get-buffer preview)
        (kill-buffer preview)))))

(provide 'ebox-playground-tests)

;;; ebox-playground-tests.el ends here
