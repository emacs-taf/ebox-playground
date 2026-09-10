;;; ebox-playground-desktop-tests.el --- Desktop interaction regressions -*- lexical-binding: t; -*-

;;; Commentary:
;; Drive the real example through rendered native commands.  Drag streams are
;; deterministic Emacs events; every visible intermediate position is checked
;; with the existing committed-snapshot render oracle.

;;; Code:

(require 'ebox-playground)
(require 'ebox-playground-layer-tests
         (expand-file-name "tests/ebox-playground-layer-tests.el"
                           ebox-playground-directory))

(defconst ebox-playground-desktop-test--file
  (expand-file-name "examples/desktop-reference.ebox" ebox-playground-directory)
  "Desktop example exercised through the ordinary file runner.")

(defvar ebox-playground-desktop-test--demo nil
  "Business state captured from this test's real preview construction.")

(defvar ebox-playground-desktop-test--redisplays 0
  "Redisplay requests issued during the current synthetic drag.")

(cl-defmacro ebox-playground-desktop-test--with-preview
    ((buffer &optional (width 120) (height 36)) &rest body)
  "Evaluate BODY in an independent BUFFER preview of WIDTH and HEIGHT pixels."
  (declare (indent 1) (debug ((symbolp &optional form form) body)))
  `(let* ((,buffer (generate-new-buffer " *ebox-desktop-test*"))
          (ebox-viewport-width ,width) (ebox-viewport-height ,height)
          (ebox-runtime-idle-prewarm nil)
          (ebox-runtime-idle-reflow-cache-prewarm nil)
          (ebox-playground-desktop-test--demo nil)
          (capture (lambda (demo)
                     (setq ebox-playground-desktop-test--demo demo))))
     (unwind-protect
         (progn
           (advice-add 'desktop-demo-create :filter-return capture)
           (ebox-playground-open-file
            ebox-playground-desktop-test--file (buffer-name ,buffer))
           (with-current-buffer ,buffer
             (should ebox-playground-desktop-test--demo)
             ,@body))
       (advice-remove 'desktop-demo-create capture)
       (when (buffer-live-p ,buffer)
         (ebox-playground-close (buffer-name ,buffer))))))

(defun ebox-playground-desktop-test--window (id)
  "Return the captured business window identified by ID."
  (cl-find id (desktop-demo-windows ebox-playground-desktop-test--demo)
           :key #'desktop-demo-window-id :test #'equal))

(defun ebox-playground-desktop-test--offset (id)
  "Return ID's committed pixel displacement."
  (let ((window (ebox-playground-desktop-test--window id)))
    (cons (desktop-demo-window-x window) (desktop-demo-window-y window))))

(defun ebox-playground-desktop-test--revision ()
  "Return the current preview's committed publication revision."
  (plist-get (ebox-surface-buffer-snapshot (current-buffer)) :revision))

(defun ebox-playground-desktop-test--state ()
  "Copy the business values which must advance only after publication."
  (let ((demo ebox-playground-desktop-test--demo))
    (list (copy-sequence (desktop-demo-order demo))
          (desktop-demo-active demo) (desktop-demo-serial demo)
          (desktop-demo-dragging demo)
          (desktop-demo-theme demo)
          (mapcar (lambda (window)
                    (list (desktop-demo-window-id window)
                          (desktop-demo-window-x window)
                          (desktop-demo-window-y window)))
                  (desktop-demo-windows demo)))))

(defun ebox-playground-desktop-test--event (type window position xy &optional end)
  "Create native TYPE at WINDOW POSITION XY, optionally ending at END."
  (let ((start (list window position xy 0)))
    (if end (list type start (list window position end 1))
      (list type start))))

(defun ebox-playground-desktop-test--drag (label start events &optional type)
  "Drag LABEL from START, reading EVENTS produced for its window and position.
EVENTS is called with the window and position.  Each returned item is an event
or a function run before reading the next event, to inspect live publication.
TYPE defaults to `down-mouse-1'; repeated presses use their native event type."
  (let* ((buffer (current-buffer))
         (position (ebox-playground-layer-test--position label))
         (map (get-text-property position 'keymap)))
    (save-window-excursion
      (set-window-buffer (selected-window) buffer)
      (let* ((window (selected-window))
             (down (ebox-playground-desktop-test--event
                    (or type 'down-mouse-1) window position start))
             (queue (funcall events window position))
             (command (key-binding (vector down) nil nil position))
             (last-input-event down)
             (ebox-playground-desktop-test--redisplays 0)
             (unread-command-events nil))
        (should (commandp command))
        (should (eq command (lookup-key map (vector (or type 'down-mouse-1)))))
        (cl-letf (((symbol-function 'read-event)
                   (lambda (&rest _)
                     (while (functionp (car queue)) (funcall (pop queue)))
                     (unless queue (ert-fail "Drag read beyond its terminal event"))
                     (pop queue)))
                  ((symbol-function 'redisplay)
                   (lambda (&rest _) (cl-incf ebox-playground-desktop-test--redisplays))))
          (call-interactively command nil (vector down)))
        (should-not queue)
        (should-not (desktop-demo-dragging ebox-playground-desktop-test--demo))
        (ebox-playground-layer-test--parity)
        unread-command-events))))

(ert-deftest ebox-playground-desktop-renders-five-independent-window-owners ()
  "The example retains five window owners and visible dock controls at two widths."
  (dolist (width '(80 120))
    (ebox-playground-desktop-test--with-preview (buffer width)
      (should (= (length (desktop-demo-windows ebox-playground-desktop-test--demo)) 5))
      (dolist (id '("desk-studio" "desk-notes" "desk-signal" "desk-terminal" "desk-palette"))
        (should (ebox-region-resolve buffer id)))
      (dolist (label '("01 ST" "02 NT" "03 SG" "04 TM" "05 PL" "RESET" "CYCLE"))
        (should (keymapp (get-text-property
                         (ebox-playground-layer-test--position label) 'keymap))))
      (dolist (line (ebox-string-lines (buffer-string)))
        (should (<= (ebox-string-pixel-width line) width)))
      (ebox-playground-layer-test--parity))))

(ert-deftest ebox-playground-desktop-compact-viewport-keeps-all-dock-commands ()
  "Every dock control remains visible and usable in a 40 by 20 viewport."
  (ebox-playground-desktop-test--with-preview (buffer 40 20)
    (dolist (entry '(("01 ST" . "desk-studio") ("02 NT" . "desk-notes")
                     ("03 SG" . "desk-signal") ("04 TM" . "desk-terminal")
                     ("05 PL" . "desk-palette")))
      (ebox-playground-layer-test--click (car entry))
      (should (equal (desktop-demo-active ebox-playground-desktop-test--demo)
                     (cdr entry))))))

(ert-deftest ebox-playground-desktop-gaps-and-endpoints-do-not-select-text ()
  "Desktop gaps, newlines and buffer end consume native selection commands."
  (ebox-playground-desktop-test--with-preview (buffer)
    (should desktop-demo-input-mode)
    (let* ((dock (ebox-playground-layer-test--position "01 ST"))
           (gap (next-single-property-change dock 'keymap nil (point-max)))
           (newline (save-excursion (goto-char dock) (line-end-position)))
           (transient-mark-mode t))
      (save-window-excursion
        (set-window-buffer (selected-window) buffer)
        (dolist (position (list (point-min) gap newline (point-max)))
          (dolist (type '(down-mouse-1 mouse-1 drag-mouse-1 S-mouse-1
                         M-down-mouse-1 M-mouse-1 M-drag-mouse-1))
            (goto-char position)
            (set-mark (if (= position (point-min)) (point-max) (point-min)))
            (setq mark-active t)
            (let* ((event (ebox-playground-desktop-test--event
                           type (selected-window) position '(0 . 0)))
                   (command (key-binding (vector type)))
                   (last-input-event event))
              (should (eq command #'desktop-demo--dismiss-mouse-selection))
              (call-interactively command)
              (should-not mark-active))))))))

(ert-deftest ebox-playground-desktop-fast-dock-clicks-remain-controls ()
  "Single, double and triple dock click sequences never activate a region."
  (ebox-playground-desktop-test--with-preview (buffer)
    (let ((transient-mark-mode t))
      (save-window-excursion
        (set-window-buffer (selected-window) buffer)
        (dolist (label '("01 ST" "02 NT" "03 SG" "04 TM" "05 PL"))
          (dolist (type '(down-mouse-1 mouse-1 double-down-mouse-1 double-mouse-1
                         triple-down-mouse-1 triple-mouse-1 drag-mouse-1
                         double-drag-mouse-1 triple-drag-mouse-1))
            (let* ((position (ebox-playground-layer-test--position label))
                   (event (ebox-playground-desktop-test--event
                           type (selected-window) position '(0 . 0)))
                   (last-input-event event))
              (goto-char position)
              (set-mark (point-min))
              (setq mark-active t)
              (run-hooks 'pre-command-hook)
              (let ((command (key-binding (vector type))))
                (should (commandp command))
                (should-not (memq command '(mouse-drag-region mouse-set-region mouse-set-point)))
                (call-interactively command))
              (should-not mark-active))))))
    (ebox-playground-layer-test--parity)))

(ert-deftest ebox-playground-desktop-mouse-policy-is-local-and-released ()
  "Other buffers and replacement previews retain ordinary Emacs selection."
  (ebox-playground-desktop-test--with-preview (buffer)
    (with-temp-buffer
      (should-not desktop-demo-input-mode)
      (should (eq (key-binding [down-mouse-1]) 'mouse-drag-region)))
    (ebox-playground-open-file ebox-playground-layer-test--file (buffer-name buffer))
    (should-not desktop-demo-input-mode)
    (should-not (memq #'desktop-demo--clear-mouse-mark pre-command-hook))
    (ebox-playground-open-file ebox-playground-desktop-test--file (buffer-name buffer))
    (should desktop-demo-input-mode)
    (ebox-unmount-buffer buffer)
    (should-not desktop-demo-input-mode)))

(ert-deftest ebox-playground-desktop-theme-adapts-all-card-and-chrome-styles ()
  "A theme toggle changes every semantic paint role without moving windows."
  (ebox-playground-desktop-test--with-preview (buffer)
    (let* ((demo ebox-playground-desktop-test--demo)
           (before (ebox-playground-desktop-test--state))
           (revision (ebox-playground-desktop-test--revision)))
      (ebox-playground-layer-test--activate "LIGHT")
      (should (eq (desktop-demo-theme demo) 'light))
      (should (= (ebox-playground-desktop-test--revision) (1+ revision)))
      (dolist (entry (desktop-demo-styles demo))
        (let ((matches (ebox-selector-query-buffer
                        buffer (concat "." (symbol-name (car entry))))))
          (should matches)
          (unless (eq (car entry) 'desktop-chrome)
            (dolist (match matches)
              (let ((node (plist-get match :node)) (style (nth 2 entry)))
                (while style
                  (let ((property (pop style)) (expected (pop style)))
                    (when (eq property :border)
                      (dolist (edge '(top right bottom left))
                        (should (equal (ebox-get node (intern (format ":border-%s-color" edge)))
                                       expected))
                        (should (> (ebox-get node (intern (format ":border-%s-pixel" edge))) 0))))
                    (unless (memq property '(:hover-style :border))
                      (should (equal (ebox-get node (if (eq property :background-color)
                                                       :bgcolor property))
                                     expected))))))))))
      (should (string-match-p "DARK" (buffer-string)))
      (should (member "#B9C9DE"
                      (flatten-tree (get-text-property
                                     (ebox-playground-layer-test--position "DARK") 'mouse-face))))
      (ebox-playground-layer-test--activate "DARK")
      (should (equal before (ebox-playground-desktop-test--state)))
      (should (eq (desktop-demo-theme demo) 'dark)))))

(ert-deftest ebox-playground-desktop-light-theme-keeps-focus-move-and-reset ()
  "Light cards and active chrome stay light after normal window operations."
  (ebox-playground-desktop-test--with-preview (buffer 40 20)
    (ebox-playground-layer-test--activate "LIGHT")
    (ebox-playground-layer-test--activate "01 ST")
    (let* ((demo ebox-playground-desktop-test--demo)
           (position (ebox-playground-layer-test--position "01 ST"))
           (face (flatten-tree (get-text-property position 'face))))
      (should (member "#6D4AA2" face))
      (should (member "#FFFFFF" face))
      (ebox-playground-layer-test--activate "01 ST" (kbd "M-<right>"))
      (ebox-playground-layer-test--activate "RESET")
      (should (eq (desktop-demo-theme demo) 'light))
      (should (equal (desktop-demo-active demo) "desk-palette"))
      (should (member "#875270" (flatten-tree
                                 (get-text-property
                                  (ebox-playground-layer-test--position "05 PL") 'face))))
      (dolist (label '("01 ST" "02 NT" "03 SG" "04 TM" "05 PL" "DARK"))
        (should (ebox-playground-layer-test--position label))))))

(ert-deftest ebox-playground-desktop-failed-theme-keeps-palette-and-state ()
  "Rejected theme publication rolls back the complete palette and state."
  (ebox-playground-desktop-test--with-preview (buffer)
    (dolist (failure-step '(text client-state))
      (let ((before (buffer-string))
            (state (ebox-playground-desktop-test--state))
            (tp--surface-publication-step-function
             (lambda (step _surface)
               (when (eq step failure-step) (error "Reject theme")))))
        (should-error (ebox-playground-layer-test--activate "LIGHT"))
        (should (equal state (ebox-playground-desktop-test--state)))
        (should (equal-including-properties before (buffer-string)))))
    (ebox-playground-layer-test--activate "LIGHT")))

(ert-deftest ebox-playground-desktop-light-palette-has-pale-cards-and-dark-ink ()
  "Every light card is pale and its body/caption text has useful contrast."
  (ebox-playground-desktop-test--with-preview (buffer)
    (let ((styles (desktop-demo-styles ebox-playground-desktop-test--demo)))
      (cl-labels
          ((light (role) (nth 2 (assq role styles)))
           (luminance (hex)
             (cl-loop for start in '(1 3 5) for weight in '(0.2126 0.7152 0.0722)
                      for value = (/ (string-to-number (substring hex start (+ start 2)) 16) 255.0)
                      sum (* weight (if (<= value 0.04045) (/ value 12.92)
                                      (expt (/ (+ value 0.055) 1.055) 2.4)))))
           (contrast (fg bg)
             (let ((a (luminance fg)) (b (luminance bg)))
               (/ (+ (max a b) 0.05) (+ (min a b) 0.05)))))
        (dolist (role '(desktop-root desktop-workspace desktop-studio desktop-notes
                       desktop-signal desktop-terminal desktop-palette))
          (let ((style (light role)))
            (should (> (luminance (plist-get style :background-color)) 0.7))
            (when (plist-get style :color)
              (should (> (contrast (plist-get style :color)
                                   (plist-get style :background-color)) 4.5)))))
        (dolist (pair '((desktop-studio-muted . desktop-studio)
                        (desktop-notes-caption . desktop-notes)
                        (desktop-signal-caption . desktop-signal)
                        (desktop-terminal-muted . desktop-terminal)
                        (desktop-palette-caption . desktop-palette)))
          (should (> (contrast (plist-get (light (car pair)) :color)
                               (plist-get (light (cdr pair)) :background-color)) 4.5)))))))

(ert-deftest ebox-playground-desktop-previews-have-independent-themes ()
  "Changing one desktop palette cannot recolor a second preview."
  (ebox-playground-desktop-test--with-preview (first)
    (let ((first-demo ebox-playground-desktop-test--demo))
      (ebox-playground-desktop-test--with-preview (second)
        (let ((before (buffer-string)))
          (with-current-buffer first
            (desktop-demo-toggle-theme first-demo)
            (ebox-playground-layer-test--parity))
          (should (equal-including-properties before (buffer-string)))
          (should (eq (desktop-demo-theme ebox-playground-desktop-test--demo) 'dark))
          (should (eq (desktop-demo-theme first-demo) 'light)))))))

(ert-deftest ebox-playground-desktop-repeated-keyboard-nudges-retain-dock-binding ()
  "Repeated arrow commands keep their native dock binding without repositioning."
  (dolist (key '("M-<right>" "M-<left>" "M-<up>" "M-<down>"))
    (let ((report (ebox-playground-interaction-evaluator-run
                   ebox-playground-desktop-test--file "01 ST" key 3 104 36)))
      (should (= (plist-get report :steps) 3))
      (should (>= (plist-get report :publications) 3))
      (should (plist-get report :fresh-parity)))))

(ert-deftest ebox-playground-desktop-repeated-title-presses-still-drag ()
  "Double and triple title presses track movement using their native bindings."
  (dolist (types '((double-down-mouse-1 . double-drag-mouse-1)
                   (triple-down-mouse-1 . triple-drag-mouse-1)))
    (ebox-playground-desktop-test--with-preview (buffer)
      (ebox-playground-layer-test--activate "01 ST")
      (ebox-playground-desktop-test--drag
       "STUDIO / 01" '(10 . 8)
       (lambda (window position)
         (list (ebox-playground-desktop-test--event
                'mouse-movement window position '(12 . 9))
               (ebox-playground-desktop-test--event
                (cdr types) window position '(10 . 8) '(13 . 10))))
       (car types))
      (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(3 . 2))))))

(ert-deftest ebox-playground-desktop-native-dock-raises-every-window ()
  "Every dock command raises its entire window including its nested content."
  (ebox-playground-desktop-test--with-preview (buffer)
    (dolist (entry '(("01 ST" "desk-studio" "Make space for the unexpected.")
                     ("02 NT" "desk-notes" "A quieter kind of focus.")
                     ("03 SG" "desk-signal" "AFTER HOURS")
                     ("04 TM" "desk-terminal" "$ build something good")
                     ("05 PL" "desk-palette" "Objects in conversation.")))
      (ebox-playground-layer-test--click (car entry))
      (should (equal (desktop-demo-active ebox-playground-desktop-test--demo)
                     (cadr entry)))
      (should (integerp (ebox-playground-layer-test--position (caddr entry)))))))

(ert-deftest ebox-playground-desktop-front-window-click-does-not-publish ()
  "Repeated activation of the front window is a publication no-op."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (let ((revision (ebox-playground-desktop-test--revision))
          (state (ebox-playground-desktop-test--state)))
      (ebox-playground-layer-test--click "Make space for the unexpected.")
      (should (= revision (ebox-playground-desktop-test--revision)))
      (should (equal state (ebox-playground-desktop-test--state))))))

(ert-deftest ebox-playground-desktop-exposed-body-raises-covered-nested-content ()
  "Clicking an exposed lower body restores its nested artwork above an overlapping pane."
  (ebox-playground-desktop-test--with-preview (buffer 80)
    (ebox-playground-layer-test--activate "01 ST")
    (ebox-playground-desktop-test--drag
     "STUDIO / 01" '(10 . 8)
     (lambda (window position)
       (list (ebox-playground-desktop-test--event
              'drag-mouse-1 window position '(10 . 8) '(28 . 11)))))
    (let ((artwork (ebox-playground-layer-test--coordinates "PLAY / 03")))
      (ebox-playground-layer-test--activate "03 SG")
      (should-not (string-match-p "PLAY / 03" (buffer-string)))
      (ebox-playground-layer-test--click "Make space for the unexpected.")
      (should (equal (desktop-demo-active ebox-playground-desktop-test--demo) "desk-studio"))
      (should (equal artwork (ebox-playground-layer-test--coordinates "PLAY / 03")))
      (ebox-playground-layer-test--activate "02 NT")
      (ebox-playground-layer-test--click "PLAY / 03")
      (should (equal (desktop-demo-active ebox-playground-desktop-test--demo) "desk-studio")))))

(ert-deftest ebox-playground-desktop-drag-publishes-each-motion-before-release ()
  "Motion publishes immediately and release uses its endpoint, preserving grab offset."
  (dolist (width '(80 120))
    (ebox-playground-desktop-test--with-preview (buffer width)
      (ebox-playground-layer-test--activate "01 ST")
      (ebox-playground-desktop-test--drag
       "STUDIO / 01" '(10 . 8)
       (lambda (window position)
         (list
          (ebox-playground-desktop-test--event 'mouse-movement window position '(15 . 10))
          (lambda ()
            (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(5 . 2)))
            (should (desktop-demo-dragging ebox-playground-desktop-test--demo))
            (should (>= ebox-playground-desktop-test--redisplays 2))
            (ebox-playground-layer-test--parity))
          (ebox-playground-desktop-test--event 'mouse-movement window position '(12 . 9))
          (lambda ()
            (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(2 . 1)))
            (should (>= ebox-playground-desktop-test--redisplays 3))
            (ebox-playground-layer-test--parity))
          (ebox-playground-desktop-test--event 'drag-mouse-1 window position '(10 . 8) '(16 . 11)))))
      (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(6 . 3))))))

(ert-deftest ebox-playground-desktop-repeated-motion-does-not-republish ()
  "Identical pointer positions and a matching release produce only one publication."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (let ((revision (ebox-playground-desktop-test--revision)))
      (ebox-playground-desktop-test--drag
       "STUDIO / 01" '(10 . 8)
       (lambda (window position)
         (list (ebox-playground-desktop-test--event 'mouse-movement window position '(12 . 9))
               (ebox-playground-desktop-test--event 'mouse-movement window position '(12 . 9))
               (ebox-playground-desktop-test--event 'drag-mouse-1 window position '(10 . 8) '(12 . 9)))))
      (should (= (1+ revision) (ebox-playground-desktop-test--revision))))))

(ert-deftest ebox-playground-desktop-second-drag-starts-at-current-displacement ()
  "A second grab adds its delta to the previously published window position."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (dolist (start '((10 . 8) (25 . 16)))
      (ebox-playground-desktop-test--drag
       "STUDIO / 01" start
       (lambda (window position)
         (list (ebox-playground-desktop-test--event
                'drag-mouse-1 window position start
                (cons (+ (car start) 3) (1+ (cdr start))))))))
    (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(6 . 2)))))

(ert-deftest ebox-playground-desktop-each-title-drags-its-own-window ()
  "Each title's native drag binding moves its associated semantic owner."
  (ebox-playground-desktop-test--with-preview (buffer)
    (dolist (entry '(("01 ST" "STUDIO / 01" "desk-studio")
                     ("02 NT" "NOTES / 02" "desk-notes")
                     ("03 SG" "SIGNAL / 03" "desk-signal")
                     ("04 TM" "TERMINAL / 04" "desk-terminal")
                     ("05 PL" "PALETTE / 05" "desk-palette")))
      (ebox-playground-layer-test--activate (car entry))
      (ebox-playground-desktop-test--drag
       (cadr entry) '(10 . 8)
       (lambda (window position)
         (list (ebox-playground-desktop-test--event
                'drag-mouse-1 window position '(10 . 8) '(11 . 9)))))
      (should (equal (ebox-playground-desktop-test--offset (caddr entry)) '(1 . 1))))))

(ert-deftest ebox-playground-desktop-reverse-drag-restores-original-paint ()
  "Moving away and back restores original coordinates and committed render parity."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (let ((home (ebox-playground-layer-test--coordinates "STUDIO / 01")))
      (dolist (end '((17 . 11) (3 . 5)))
        (ebox-playground-desktop-test--drag
         "STUDIO / 01" '(10 . 8)
         (lambda (window position)
           (list (ebox-playground-desktop-test--event
                  'drag-mouse-1 window position '(10 . 8) end)))))
      (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(0 . 0)))
      (should (equal home (ebox-playground-layer-test--coordinates "STUDIO / 01"))))))

(ert-deftest ebox-playground-desktop-unrelated-event-stops-and-is-requeued ()
  "Typing during a drag ends tracking and preserves the input for the command loop."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (should (equal (ebox-playground-desktop-test--drag
                    "STUDIO / 01" '(10 . 8) (lambda (_window _position) (list ?x)))
                   '(120)))))

(ert-deftest ebox-playground-desktop-quit-clears-dragging ()
  "A quit signal exits tracking without leaving the demo in its dragging state."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (let ((caught nil))
      (condition-case nil
          (ebox-playground-desktop-test--drag
           "STUDIO / 01" '(10 . 8)
           (lambda (_window _position) (list (lambda () (signal 'quit nil)))))
        (quit (setq caught t)))
      (should caught)
      (should-not (desktop-demo-dragging ebox-playground-desktop-test--demo))
      (ebox-playground-layer-test--parity))))

(ert-deftest ebox-playground-desktop-failed-activation-preserves-business-state ()
  "A rejected publication leaves focus, ordering and all window positions unchanged."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "05 PL")
    (let ((state (ebox-playground-desktop-test--state))
          (revision (ebox-playground-desktop-test--revision)))
      (dolist (failure-step '(text client-state))
        (let* ((failed nil)
              (tp--surface-publication-step-function
               (lambda (step _surface)
                 (when (eq step failure-step)
                   (setq failed t)
                   (error "Injected desktop publication failure: %s" step)))))
          (should-error (ebox-playground-layer-test--activate "01 ST"))
          (should failed)))
      (should (equal state (ebox-playground-desktop-test--state)))
      (should (= revision (ebox-playground-desktop-test--revision)))
      (ebox-playground-layer-test--parity))))

(ert-deftest ebox-playground-desktop-failed-motion-keeps-last-accepted-position ()
  "A rejected live drag publication keeps geometry and clears transient tracking."
  (ebox-playground-desktop-test--with-preview (buffer)
    (ebox-playground-layer-test--activate "01 ST")
    (let* ((revision (ebox-playground-desktop-test--revision))
          (failed nil)
          (tp--surface-publication-step-function
           (lambda (step _surface)
             (when (eq step 'client-state)
               (setq failed t)
               (error "Reject drag position")))))
      (should-error
       (ebox-playground-desktop-test--drag
        "STUDIO / 01" '(10 . 8)
        (lambda (window position)
          (list (ebox-playground-desktop-test--event
                 'mouse-movement window position '(15 . 10))))))
      (should failed)
      (should-not (desktop-demo-dragging ebox-playground-desktop-test--demo))
      (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(0 . 0)))
      (should (= revision (ebox-playground-desktop-test--revision))))
    (ebox-playground-layer-test--parity)))

(ert-deftest ebox-playground-desktop-outside-release-ends-tracking ()
  "Release over another window or frame area consumes the event and ends tracking."
  (dolist (target '(window frame area))
    (ebox-playground-desktop-test--with-preview (buffer)
      (ebox-playground-layer-test--activate "01 ST")
      (let ((other (generate-new-buffer " *ebox-desktop-outside*")))
        (unwind-protect
            (progn
              (with-current-buffer other (insert "Untouched other window"))
              (should-not
               (ebox-playground-desktop-test--drag
                "STUDIO / 01" '(10 . 8)
                (lambda (window position)
                  (let* ((other-window (split-window-right))
                         (where (if (eq target 'frame) (selected-frame) other-window)))
                    (set-window-buffer other-window other)
                    (list (list 'drag-mouse-1
                                (list window position '(10 . 8) 0)
                                (list where (if (eq target 'area) 'mode-line 1)
                                      '(500 . 500) 1)))))))
              (with-current-buffer other
                (should (equal (buffer-string) "Untouched other window"))))
          (kill-buffer other))))))

(ert-deftest ebox-playground-desktop-reset-restores-all-window-positions ()
  "Reset returns dragged windows to their original position and focus order."
  (ebox-playground-desktop-test--with-preview (buffer)
    (let ((initial-order (copy-sequence (desktop-demo-order ebox-playground-desktop-test--demo)))
          (initial-active (desktop-demo-active ebox-playground-desktop-test--demo)))
      (ebox-playground-layer-test--activate "01 ST")
      (ebox-playground-desktop-test--drag
       "STUDIO / 01" '(10 . 8)
       (lambda (window position)
         (list (ebox-playground-desktop-test--event
                'drag-mouse-1 window position '(10 . 8) '(16 . 10)))))
      (ebox-playground-layer-test--activate "RESET")
      (dolist (window (desktop-demo-windows ebox-playground-desktop-test--demo))
        (should (equal (ebox-playground-desktop-test--offset (desktop-demo-window-id window))
                       '(0 . 0))))
      (should (equal initial-order (desktop-demo-order ebox-playground-desktop-test--demo)))
      (should (equal initial-active (desktop-demo-active ebox-playground-desktop-test--demo))))))

(ert-deftest ebox-playground-desktop-previews-keep-independent-focus-and-position ()
  "A second preview starts fresh while the first retains its focus and displacement."
  (ebox-playground-desktop-test--with-preview (first 80)
    (ebox-playground-layer-test--activate "01 ST")
    (ebox-playground-desktop-test--drag
     "STUDIO / 01" '(10 . 8)
     (lambda (window position)
       (list (ebox-playground-desktop-test--event
              'drag-mouse-1 window position '(10 . 8) '(14 . 10)))))
    (let ((first-demo ebox-playground-desktop-test--demo)
          (state (ebox-playground-desktop-test--state)))
      (ebox-playground-desktop-test--with-preview (second 120)
        (should-not (eq first-demo ebox-playground-desktop-test--demo))
        (should (equal (ebox-playground-desktop-test--offset "desk-studio") '(0 . 0)))
        (ebox-playground-layer-test--activate "CYCLE")
        (with-current-buffer first
          (let ((ebox-playground-desktop-test--demo first-demo))
            (should (equal state (ebox-playground-desktop-test--state)))
            (ebox-playground-layer-test--parity)))))))

(provide 'ebox-playground-desktop-tests)
;;; ebox-playground-desktop-tests.el ends here
