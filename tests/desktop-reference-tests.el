;;; desktop-reference-tests.el --- Public desktop drag workflow -*- lexical-binding: t; -*-

;;; Commentary:
;; Render the maintained example and operate its native title-bar binding.

;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'ebox-playground)

(ert-deftest ebox-playground-desktop-drag-publishes-motion-and-release ()
  "Dragging the shipped desktop updates the pane before release and at its endpoint."
  (let ((buffer (generate-new-buffer " *desktop-gesture*"))
        (ebox-viewport-width 104) (ebox-viewport-height 36))
    (unwind-protect
        (save-window-excursion
          (ebox-playground-open-file
           (expand-file-name "examples/desktop-reference.ebox" ebox-playground-directory)
           (buffer-name buffer))
          (set-window-buffer (selected-window) buffer)
          (with-current-buffer buffer
            (goto-char (point-min))
            (search-forward "STUDIO / 01")
            (let* ((window (selected-window)) (position (match-beginning 0))
                   (press (list 'down-mouse-1 (list window position '(1 . 1) 0)))
                   (last-input-event press)
                   (events (list (list 'mouse-movement (list window position '(4 . 1) 1))
                                 (list 'drag-mouse-1 (event-start press) (list window position '(7 . 1) 2))))
                   (command (key-binding (vector press) nil nil position)))
              (cl-letf (((symbol-function 'read-event)
                         (lambda (&rest _)
                           (when (= (length events) 1)
                             (should (string-match-p (regexp-quote "X +3") (buffer-string))))
                           (if events (pop events) ?q))))
                (funcall command press))
              (should (string-match-p (regexp-quote "X +6") (buffer-string)))
              (should (string-match-p "DRAG A TITLE BAR" (buffer-string))))))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(provide 'desktop-reference-tests)
;;; desktop-reference-tests.el ends here
