;;; ebox-playground-interaction-tests.el --- Native interaction example tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Exercise the actual example through the generic public file runner.  Native
;; properties and commands are observed on rendered text; lexical closures and
;; keymap graphs are intentionally treated as opaque application values.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'ebox-playground)
(require 'ebox-playground-flex-resize-evaluator
         (expand-file-name "benchmarks/ebox-playground-flex-resize-evaluator.el"
                           ebox-playground-directory))

(defconst ebox-playground-interaction-test--file
  (expand-file-name "examples/interaction-reference.ebox"
                    ebox-playground-directory)
  "Interaction example checked through the ordinary file runner.")

(cl-defmacro ebox-playground-interaction-test--with-preview
    ((buffer &optional (width 720) (height 200)) &rest body)
  "Run BODY in a fresh BUFFER preview at WIDTH and HEIGHT, then close it."
  (declare (indent 1) (debug ((symbolp &optional form form) body)))
  `(let ((,buffer (generate-new-buffer " *ebox-interaction-test*"))
         (ebox-viewport-width ,width)
         (ebox-viewport-height ,height)
         (ebox-runtime-idle-prewarm nil)
         (ebox-runtime-idle-reflow-cache-prewarm nil))
     (unwind-protect
         (progn
           (ebox-playground-open-file
            ebox-playground-interaction-test--file (buffer-name ,buffer))
           (with-current-buffer ,buffer ,@body))
       (when (buffer-live-p ,buffer)
         (ebox-playground-close (buffer-name ,buffer))))))

(defun ebox-playground-interaction-test--position (label)
  "Return the first rendered character position of LABEL in this preview."
  (save-excursion
    (goto-char (point-min))
    (unless (search-forward label nil t)
      (ert-fail (format "Missing rendered interaction label: %s" label)))
    (- (point) (length label))))

(defun ebox-playground-interaction-test--property (label property)
  "Return native PROPERTY at the rendered LABEL."
  (get-text-property
   (ebox-playground-interaction-test--position label) property))

(defun ebox-playground-interaction-test--activate (label &optional key)
  "Look up KEY at rendered LABEL and invoke its native interactive command."
  (let* ((keys (or key (kbd "RET")))
         (position (ebox-playground-interaction-test--position label))
         (map (get-text-property position 'keymap)))
    (goto-char position)
    (should (keymapp map))
    (let ((command (key-binding keys))
          (last-input-event (aref (vconcat keys) (1- (length keys)))))
      (should (commandp command))
      (should (eq command (lookup-key map keys)))
      (call-interactively command)
      command)))

(defun ebox-playground-interaction-test--click (label &optional offset)
  "Click rendered LABEL at OFFSET through native event lookup in another buffer."
  (let* ((buffer (current-buffer))
         (position (+ (ebox-playground-interaction-test--position label)
                      (or offset 0)))
         (map (get-text-property position 'keymap))
         command)
    (should (keymapp map))
    (save-window-excursion
      (set-window-buffer (selected-window) buffer)
      (let* ((event (list 'mouse-1 (list (selected-window) position '(0 . 0) 0)))
             (keys (vector event))
             (last-input-event event))
        (setq command (key-binding [mouse-1] nil nil position))
        (should (commandp command))
        (should (eq command (lookup-key map [mouse-1])))
        (with-temp-buffer
          (call-interactively command nil keys)
          (should (zerop (buffer-size))))))
    command))

(defun ebox-playground-interaction-test--count (expected)
  "Assert that the preview displays the independent count EXPECTED."
  (should (integerp
           (ebox-playground-interaction-test--position
            (format "COUNT  %02d" expected)))))

(defun ebox-playground-interaction-test--help ()
  "Invoke the live action's native help callback with Emacs's arguments."
  (let* ((position (ebox-playground-interaction-test--position "ADD "))
         (callback (get-text-property position 'help-echo)))
    (should (functionp callback))
    (funcall callback (selected-window) (current-buffer) position)))

(defun ebox-playground-interaction-test--padding-position (label)
  "Find LABEL's command on the otherwise blank Box padding line above it."
  (let* ((position (ebox-playground-interaction-test--position label))
         (command (lookup-key (get-text-property position 'keymap) (kbd "RET")))
         (background
          (plist-get (ebox-playground-flex-resize-evaluator--effective-face
                      (get-text-property position 'face))
                     :background)))
    (save-excursion
      (goto-char position)
      (forward-line -1)
      (should (string-match-p
               "\\`[[:space:]]*\\'"
               (buffer-substring-no-properties
                (line-beginning-position) (line-end-position))))
      (or (cl-loop for at from (line-beginning-position)
                   below (line-end-position)
                   for map = (get-text-property at 'keymap)
                   when (and (keymapp map)
                             (eq (lookup-key map (kbd "RET")) command)
                             ;; Border glyphs share the Box map but retain
                             ;; their stroke color when the interior hovers.
                             (equal
                              (plist-get
                               (ebox-playground-flex-resize-evaluator--effective-face
                                (get-text-property at 'face))
                               :background)
                              background))
                   return at)
          (ert-fail (format "Box padding lost the command for %s" label))))))

(ert-deftest ebox-playground-interaction-static-help-pointer-and-hover-samples ()
  "The isolated examples publish native properties on the intended content."
  (ebox-playground-interaction-test--with-preview (buffer)
    (dolist (sample '(("ARROW" arrow) ("Text-only hint" text)
                      ("HORIZONTAL DRAG" hdrag)))
      (should (eq (ebox-playground-interaction-test--property
                   (car sample) 'pointer)
                  (cadr sample)))
      (should (stringp (ebox-playground-interaction-test--property
                       (car sample) 'help-echo)))
      (should-not (ebox-playground-interaction-test--property
                   (car sample) 'keymap)))
    (should-not (ebox-playground-interaction-test--property
                 "TEXT POINTER" 'pointer))
    (should-not (ebox-playground-interaction-test--property
                 "TEXT POINTER" 'help-echo))
    (let ((cool (ebox-playground-flex-resize-evaluator--effective-face
                 (ebox-playground-interaction-test--property
                  "COOL FILL" 'mouse-face)))
          (warm (ebox-playground-flex-resize-evaluator--effective-face
                 (ebox-playground-interaction-test--property
                  "WARM + UNDERLINE" 'mouse-face))))
      (should (equal (plist-get cool :foreground) "#FFFFFF"))
      (should (equal (plist-get cool :background) "#286477"))
      (should (equal (plist-get warm :foreground) "#683D16"))
      (should (equal (plist-get warm :background) "#F6D6AB"))
      (should (plist-get warm :underline)))
    (should-not (ebox-playground-interaction-test--property
                 "NO HOVER STYLE" 'mouse-face))))

(ert-deftest ebox-playground-interaction-native-keys-replace-step-and-read-live-help ()
  "Real key lookup uses a replaced +5 map and callbacks see current state."
  (ebox-playground-interaction-test--with-preview (buffer)
    (ebox-playground-interaction-test--count 0)
    (should (string-match-p "count = 0; this action adds 1"
                            (ebox-playground-interaction-test--help)))
    (let ((first-command
           (ebox-playground-interaction-test--activate "ADD 1")))
      (ebox-playground-interaction-test--count 1)
      (should (string-match-p "count = 1; this action adds 1"
                              (ebox-playground-interaction-test--help)))
      (ebox-playground-interaction-test--activate "SWITCH STEP" (kbd "SPC"))
      (should (string-match-p "count = 1; this action adds 5"
                              (ebox-playground-interaction-test--help)))
      (should-not
       (eq first-command
           (ebox-playground-interaction-test--activate "ADD 5" [return])))
      (ebox-playground-interaction-test--count 6))
    (ebox-playground-interaction-test--activate "ADD 5" (kbd "+"))
    (ebox-playground-interaction-test--count 11)
    (ebox-playground-interaction-test--activate "ADD 5" (kbd "-"))
    (ebox-playground-interaction-test--count 6)
    (should (string-match-p "count = 6; this action adds 5"
                            (ebox-playground-interaction-test--help)))
    (should (integerp (ebox-playground-interaction-test--position
                       "-5 → count 6")))
    (should (ebox-buffer-update-report buffer))))

(ert-deftest ebox-playground-interaction-minus-click-captures-step-and-restores ()
  "Clicking the minus glyph subtracts, while the enclosing ADD surface adds."
  (ebox-playground-interaction-test--with-preview (buffer)
    (let ((minus-one (ebox-playground-interaction-test--click "[-]" 1)))
      (ebox-playground-interaction-test--count -1)
      (let ((add-one (ebox-playground-interaction-test--click "ADD 1")))
        (should-not (eq minus-one add-one))
        (should (eq add-one
                    (lookup-key
                     (get-text-property
                      (ebox-playground-interaction-test--padding-position "ADD 1")
                      'keymap)
                     [mouse-1]))))
      (ebox-playground-interaction-test--count 0)
      (ebox-playground-interaction-test--activate "[-]" (kbd "+"))
      (ebox-playground-interaction-test--count 1)
      (ebox-playground-interaction-test--activate "[-]" (kbd "-"))
      (ebox-playground-interaction-test--count 0)
      (ebox-playground-interaction-test--activate "SWITCH STEP")
      (should (integerp (ebox-playground-interaction-test--position
                         "ADD 5   [+] [-]")))
      (let ((minus-five (ebox-playground-interaction-test--click "[-]" 1)))
        (should-not (eq minus-one minus-five))
        (ebox-playground-interaction-test--count -5)
        (let ((position (1+ (ebox-playground-interaction-test--position "[-]"))))
          (should (string-match-p
                   "count = -5; this action subtracts 5"
                   (funcall (get-text-property position 'help-echo)
                            (selected-window) buffer position))))
        (let ((add-five (ebox-playground-interaction-test--click "ADD 5")))
          (should-not (eq add-five minus-five))
          (ebox-playground-interaction-test--count 0)
          (ebox-playground-interaction-test--activate "[-]" (kbd "+"))
          (ebox-playground-interaction-test--count 5)
          (ebox-playground-interaction-test--activate "[-]" (kbd "-"))
          (ebox-playground-interaction-test--count 0)
          (ebox-playground-interaction-test--activate "REMOVE / RESTORE")
          (should (integerp (ebox-playground-interaction-test--position
                             "BINDING REMOVED [-]")))
          (let ((position (1+ (ebox-playground-interaction-test--position "[-]"))))
            (dolist (property '(keymap help-echo mouse-face pointer))
              (should-not (get-text-property position property)))
            (save-window-excursion
              (set-window-buffer (selected-window) buffer)
              (let* ((event (list 'mouse-1
                                  (list (selected-window) position '(0 . 0) 0)))
                     (binding (key-binding [mouse-1] nil nil
                                           (posn-point (event-start event)))))
                (should-not (memq binding (list minus-five add-five))))))
          (ebox-playground-interaction-test--count 0)
          (ebox-playground-interaction-test--activate "REMOVE / RESTORE")
          (should (integerp (ebox-playground-interaction-test--position
                             "ADD 5   [+] [-]")))
          (dolist (property '(keymap help-echo mouse-face pointer))
            (should (ebox-playground-interaction-test--property "[-]" property)))
          (ebox-playground-interaction-test--click "[-]" 1)
          (ebox-playground-interaction-test--count -5)
          (ebox-playground-interaction-test--click "ADD 5")
          (ebox-playground-interaction-test--count 0))))))

(ert-deftest ebox-playground-interaction-class-control-updates-all-statuses-in-one-batch ()
  "One native command updates three class targets and preserves other controls."
  (ebox-playground-interaction-test--with-preview (buffer)
    (should (= (length (ebox-selector-query-buffer buffer ".demo-status")) 3))
    (dolist (label '("WAIT A" "WAIT B" "WAIT C"))
      (should (equal
               (plist-get
                (ebox-playground-flex-resize-evaluator--effective-face
                 (ebox-playground-interaction-test--property label 'face))
                :foreground)
               "#85652F"))
      (should-not (ebox-playground-interaction-test--property label 'help-echo)))
    (let* ((count-command
            (ebox-playground-interaction-test--activate "ADD 1"))
           (revision (plist-get (ebox-buffer-update-report buffer)
                                :runtime-revision)))
      (should (integerp revision))
      (ebox-playground-interaction-test--activate "UPDATE STATUS GROUP" (kbd "SPC"))
      ;; The selector batch publishes once; recording the event publishes once.
      (should (= (plist-get (ebox-buffer-update-report buffer) :runtime-revision)
                 (+ revision 2)))
      (save-excursion
        (goto-char (point-min))
        (let ((ready-count 0))
          (while (search-forward "READY" nil t)
            (cl-incf ready-count)
            (let ((position (- (point) (length "READY"))))
              (should (equal (get-text-property position 'help-echo)
                             "This status was updated with its class group."))
              (should (equal
                       (plist-get
                        (ebox-playground-flex-resize-evaluator--effective-face
                         (get-text-property position 'face))
                        :foreground)
                       "#287A52"))))
          (should (= ready-count 3)))
        (goto-char (point-min))
        (should-not (re-search-forward "WAIT [ABC]" nil t)))
      (should (integerp (ebox-playground-interaction-test--position
                         "Updated three .demo-status regions in one batch")))
      (ebox-playground-interaction-test--count 1)
      (should (eq count-command
                  (ebox-playground-interaction-test--activate "ADD 1")))
      (ebox-playground-interaction-test--count 2)
      (ebox-playground-interaction-test--activate "[ RESET COUNT ]")
      (ebox-playground-interaction-test--count 0))))

(ert-deftest ebox-playground-interaction-removes-and-restores-all-four-properties ()
  "Removing bindings clears every native property on content and padding."
  (ebox-playground-interaction-test--with-preview (buffer)
    (ebox-playground-interaction-test--activate "SWITCH STEP")
    (let ((before (mapcar
                   (lambda (property)
                     (cons property
                           (ebox-playground-interaction-test--property
                            "ADD 5" property)))
                   '(help-echo pointer mouse-face keymap)))
          (padding (ebox-playground-interaction-test--padding-position "ADD 5")))
      (dolist (property '(help-echo pointer mouse-face keymap))
        (should (get-text-property padding property)))
      (let ((padding-offset (save-excursion
                              (goto-char padding)
                              (- padding (line-beginning-position)))))
        (ebox-playground-interaction-test--activate "REMOVE / RESTORE")
        ;; The status above this row changes length, so find the new padding
        ;; position instead of accidentally testing an old buffer offset.
        (setq padding
              (save-excursion
                (goto-char (ebox-playground-interaction-test--position
                            "BINDING REMOVED"))
                (forward-line -1)
                (+ (line-beginning-position) padding-offset))))
      (let ((position (ebox-playground-interaction-test--position
                       "BINDING REMOVED")))
        (goto-char position)
        (dolist (property '(help-echo pointer mouse-face keymap))
          (should-not (get-text-property position property))
          (should-not (get-text-property padding property)))
        (should-not
         (eq (key-binding (kbd "RET"))
             (lookup-key (cdr (assq 'keymap before)) (kbd "RET")))))
      (ebox-playground-interaction-test--count 0)
      (ebox-playground-interaction-test--activate "REMOVE / RESTORE")
      (dolist (property '(help-echo pointer mouse-face keymap))
        (should (ebox-playground-interaction-test--property "ADD 5" property)))
      (should (string-match-p "count = 0; this action adds 5"
                              (ebox-playground-interaction-test--help)))
      (should (equal (ebox-playground-interaction-test--property
                      "ADD 5" 'mouse-face)
                     (cdr (assq 'mouse-face before))))
      (ebox-playground-interaction-test--activate "ADD 5")
      (ebox-playground-interaction-test--count 5))))

(ert-deftest ebox-playground-interaction-palette-update-preserves-geometry-and-command ()
  "Hover replacement publishes native faces without moving the live control."
  (ebox-playground-interaction-test--with-preview (buffer)
    (let* ((position (ebox-playground-interaction-test--position "ADD 1"))
           (padding (ebox-playground-interaction-test--padding-position "ADD 1"))
           (map (get-text-property position 'keymap))
           (command (lookup-key map (kbd "RET")))
           (line-width (save-excursion
                         (goto-char position)
                         (ebox-string-pixel-width
                          (buffer-substring (line-beginning-position)
                                            (line-end-position))))))
      (should (equal (plist-get
                      (ebox-playground-flex-resize-evaluator--effective-face
                       (get-text-property position 'mouse-face))
                      :background)
                     "#BCDDE5"))
      (ebox-playground-interaction-test--activate "SWITCH HOVER")
      (should (= position (ebox-playground-interaction-test--position "ADD 1")))
      (dolist (at (list position padding))
        (let ((face (ebox-playground-flex-resize-evaluator--effective-face
                     (get-text-property at 'mouse-face))))
          (should (equal (plist-get face :background) "#F6D6AB"))
          (should (equal (plist-get face :foreground) "#683D16"))
          (should (plist-get face :underline))))
      (save-excursion
        (goto-char position)
        (should (= line-width
                   (ebox-string-pixel-width
                    (buffer-substring (line-beginning-position)
                                      (line-end-position))))))
      (should (eq command
                  (ebox-playground-interaction-test--activate "ADD 1")))
      (ebox-playground-interaction-test--count 1)
      (ebox-playground-interaction-test--activate "SWITCH HOVER")
      (should (equal
               (plist-get
                (ebox-playground-flex-resize-evaluator--effective-face
                 (ebox-playground-interaction-test--property "ADD 1" 'mouse-face))
                :background)
               "#BCDDE5")))))

(ert-deftest ebox-playground-interaction-text-keymap-resets-count ()
  "A Text node dispatches its own native command inside ordinary prose."
  (ebox-playground-interaction-test--with-preview (buffer)
    (ebox-playground-interaction-test--activate "ADD 1")
    (ebox-playground-interaction-test--activate "ADD 1" (kbd "SPC"))
    (ebox-playground-interaction-test--count 2)
    (should-not (ebox-playground-interaction-test--property
                 "Text can be interactive too:" 'keymap))
    (should (eq (ebox-playground-interaction-test--property
                 "[ RESET COUNT ]" 'pointer) 'hand))
    (ebox-playground-interaction-test--activate "[ RESET COUNT ]" (kbd "SPC"))
    (ebox-playground-interaction-test--count 0)
    (should (integerp (ebox-playground-interaction-test--position "Reset count")))
    (should (string-match-p "count = 0; this action adds 1"
                            (ebox-playground-interaction-test--help)))))

(ert-deftest ebox-playground-interaction-nested-owner-and-explicit-nil ()
  "Parent padding works, child bindings win, and explicit nil blocks all four."
  (ebox-playground-interaction-test--with-preview (buffer)
    (let ((parent-command
           (ebox-playground-interaction-test--activate "PARENT SURFACE —")))
      (should (integerp (ebox-playground-interaction-test--position
                         "01  PARENT surface activated")))
      (let* ((padding (ebox-playground-interaction-test--padding-position
                       "PARENT SURFACE —"))
             (last-input-event ?\r))
        (goto-char padding)
        (should (eq (key-binding (kbd "RET")) parent-command))
        (call-interactively (key-binding (kbd "RET"))))
      (should (integerp (ebox-playground-interaction-test--position
                         "02  PARENT surface activated")))
      (let ((child-command
             (ebox-playground-interaction-test--activate "[ CHILD ACTION ]")))
        ;; Activation starts on the child's first character, including the
        ;; key-binding check against its own map in the shared helper.
        (should-not (eq parent-command child-command))
        (should (integerp (ebox-playground-interaction-test--position
                           "03  CHILD text activated")))
        (goto-char (+ (ebox-playground-interaction-test--position
                       "[ CHILD ACTION ]")
                      (length "[ CHILD ACTION ]")))
        (should (eq (key-binding (kbd "RET")) parent-command))
        (let* ((label "[ EXPLICIT NIL: no inherited interaction ]")
               (quiet (ebox-playground-interaction-test--position label)))
          (dolist (at (list quiet (1+ quiet) (+ quiet (1- (length label)))))
            (dolist (property '(help-echo pointer mouse-face keymap))
              (should-not (get-text-property at property)))
            (goto-char at)
            (should-not (eq (key-binding (kbd "RET")) parent-command))
            (should-not (eq (key-binding (kbd "RET")) child-command)))
          (goto-char (+ quiet (length label)))
          (should (eq (key-binding (kbd "RET")) parent-command)))))))

(ert-deftest ebox-playground-interaction-box-end-boundaries-exclude-margins ()
  "A real example's Box command stops before both outside margin characters."
  (ebox-playground-interaction-test--with-preview (buffer)
    (ebox-region-update (ebox-region-resolve buffer "parent-surface")
                        :margin-inline '(ch 2))
    (let* ((position (ebox-playground-interaction-test--position
                      "PARENT SURFACE —"))
           (command (lookup-key (get-text-property position 'keymap)
                                (kbd "RET")))
           (start (previous-single-property-change
                   (1+ position) 'keymap nil
                   (save-excursion (goto-char position)
                                   (line-beginning-position))))
           (end (next-single-property-change
                 position 'keymap nil
                 (save-excursion (goto-char position) (line-end-position)))))
      (should (> start (save-excursion
                         (goto-char position) (line-beginning-position))))
      (dolist (at (list start (1- end)))
        (goto-char at)
        (should (eq (key-binding (kbd "RET")) command)))
      (dolist (at (list (1- start) end))
        (goto-char at)
        (dolist (property '(help-echo pointer mouse-face keymap))
          (should-not (get-text-property at property)))
        (should-not (eq (key-binding (kbd "RET")) command))))))

(ert-deftest ebox-playground-interaction-mouse-command-uses-event-buffer ()
  "A native click targets its window even when another buffer is current."
  (ebox-playground-interaction-test--with-preview (buffer)
    (ebox-playground-interaction-test--click "ADD 1")
    (ebox-playground-interaction-test--count 1)))

(ert-deftest ebox-playground-interaction-previews-have-independent-state ()
  "Separate evaluations own independent counts, maps, help, and event logs."
  (ebox-playground-interaction-test--with-preview (first)
    (ebox-playground-interaction-test--with-preview (second)
      (with-current-buffer first
        (ebox-playground-interaction-test--activate "SWITCH STEP")
        (ebox-playground-interaction-test--activate "ADD 5")
        (ebox-playground-interaction-test--count 5))
      (ebox-playground-interaction-test--count 0)
      (should (string-match-p "count = 0; this action adds 1"
                              (ebox-playground-interaction-test--help)))
      (should (integerp (ebox-playground-interaction-test--position
                         "No actions yet.")))
      (ebox-playground-interaction-test--activate "ADD 1")
      (ebox-playground-interaction-test--count 1)
      (with-current-buffer first
        (ebox-playground-interaction-test--count 5)
        (should (string-match-p "count = 5; this action adds 5"
                                (ebox-playground-interaction-test--help)))
        (ebox-playground-interaction-test--activate "[ RESET COUNT ]")
        (ebox-playground-interaction-test--count 0))
      (ebox-playground-interaction-test--count 1))))

(ert-deftest ebox-playground-interaction-viewport-resize-retains-updated-binding ()
  "Both viewport axes change while retained command state remains usable."
  (ebox-playground-interaction-test--with-preview (buffer)
    (ebox-playground-interaction-test--activate "SWITCH STEP")
    (ebox-playground-interaction-test--activate "SWITCH HOVER")
    (let ((command (ebox-playground-interaction-test--activate "ADD 5"))
          (expected 5)
          (original-lines (count-lines (point-min) (point-max))))
      (dolist (size '((480 220) (1000 180) (720 200)))
        (ebox-rerender-buffer-with-context buffer (car size) (cadr size))
        (let ((widths (mapcar #'ebox-string-pixel-width
                              (ebox-string-lines (buffer-string)))))
          (should (= (apply #'max widths) (car size))))
        (if (= (cadr size) 200)
            (should (= (count-lines (point-min) (point-max)) original-lines))
          (should-not (= (count-lines (point-min) (point-max)) original-lines)))
        (should (eq command
                    (ebox-playground-interaction-test--activate "ADD 5")))
        (cl-incf expected 5)
        (ebox-playground-interaction-test--count expected)
        (should (string-match-p
                 (format "count = %d; this action adds 5" expected)
                 (ebox-playground-interaction-test--help)))
        (should (equal
                 (plist-get
                  (ebox-playground-flex-resize-evaluator--effective-face
                   (ebox-playground-interaction-test--property "ADD 5" 'mouse-face))
                  :background)
                 "#F6D6AB"))
        (should (ebox-buffer-update-report buffer))))))

(provide 'ebox-playground-interaction-tests)
;;; ebox-playground-interaction-tests.el ends here
