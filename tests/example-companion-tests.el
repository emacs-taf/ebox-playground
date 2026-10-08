;;; example-companion-tests.el --- Interaction and layer example commands -*- lexical-binding: t; -*-

;;; Commentary:
;; Render the maintained examples and run their native control bindings.

;;; Code:
(require 'ert)
(require 'ebox-playground)

(defun example-companion-test--press (buffer label &optional key)
  "Run KEY (default RET) on the first LABEL in BUFFER."
  (with-current-buffer buffer
    (goto-char (point-min))
    (search-forward label)
    (goto-char (match-beginning 0))
    (let* ((keys (kbd (or key "RET")))
           (last-input-event (aref keys 0)))
      (call-interactively (key-binding keys)))))

(defun example-companion-test--text (buffer)
  "Return BUFFER's plain text."
  (with-current-buffer buffer (buffer-substring-no-properties (point-min) (point-max))))

(defmacro example-companion-test--with-example (spec &rest body)
  "Open the example named by SPEC (VAR FILE) in VAR and run BODY."
  (declare (indent 1))
  `(let ((,(car spec) (generate-new-buffer " *example-companion*"))
         (ebox-viewport-width 900) (ebox-viewport-height 200))
     (unwind-protect
         (progn
           (ebox-playground-open-file
            (expand-file-name (concat "examples/" ,(cadr spec)) ebox-playground-directory)
            (buffer-name ,(car spec)))
           ,@body)
       (when (buffer-live-p ,(car spec)) (kill-buffer ,(car spec))))))

(ert-deftest ebox-playground-interaction-example-updates-count-log-and-group ()
  "The interaction lab's actions update the counter, event log and status group."
  (example-companion-test--with-example (buffer "interaction-reference.ebox")
    (example-companion-test--press buffer "ADD 1")
    (example-companion-test--press buffer "ADD 1" "+")
    (let ((text (example-companion-test--text buffer)))
      (should (string-match-p "COUNT  02" text))
      (should (string-match-p "02  \\+1 → count 2" text)))
    (example-companion-test--press buffer "UPDATE STATUS GROUP")
    (let ((text (example-companion-test--text buffer)))
      (should-not (string-match-p "WAIT [ABC]" text))
      (should (= 3 (with-current-buffer buffer (how-many "READY" (point-min) (point-max)))))
      (should (string-match-p "Updated three .demo-status" text)))
    (example-companion-test--press buffer "REMOVE")
    (should (string-match-p "BINDING REMOVED" (example-companion-test--text buffer)))))

(ert-deftest ebox-playground-layer-example-updates-covered-note-and-cards ()
  "The layer lab updates covered content, panel visibility and card layout."
  (example-companion-test--with-example (buffer "layer-reference.ebox")
    (example-companion-test--press buffer "UPDATE COVERED NOTE")
    (example-companion-test--press buffer "UPDATE COVERED NOTE")
    (should (string-match-p "lower rev=02" (example-companion-test--text buffer)))
    (should-not (string-match-p "LOWER REV 02" (example-companion-test--text buffer)))
    (example-companion-test--press buffer "TOGGLE PANEL A")
    (should (string-match-p "LOWER REV 02" (example-companion-test--text buffer)))
    (example-companion-test--press buffer "EXPLODE STACK")
    (should (string-match-p "EXPANDED" (example-companion-test--text buffer)))
    (example-companion-test--press buffer "EXPLODE STACK")
    (should (string-match-p "STACKED" (example-companion-test--text buffer)))))

(provide 'example-companion-tests)
;;; example-companion-tests.el ends here
