;;; ebox-playground-tests.el --- Public Ebox example tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'ebox-playground)

(ert-deftest ebox-playground-uses-only-public-layout-apis ()
  "The example should build and render through the public Ebox entry point."
  (let ((node (ebox-playground-view)))
    (should (eq (plist-get node :ebox-type) 'grid))
    (should (string-match-p "Ebox Playground"
                            (substring-no-properties (ebox-render node))))))

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

(provide 'ebox-playground-tests)

;;; ebox-playground-tests.el ends here
