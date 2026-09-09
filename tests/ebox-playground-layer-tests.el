;;; ebox-playground-layer-tests.el --- Layer lab command regressions -*- lexical-binding: t; -*-

;;; Commentary:
;; Exercise the actual companion and DSL through the generic file runner.
;; Commands come from rendered native keymaps.  Every publication is compared
;; with an independent render of the committed logical input, including paint
;; and native interaction properties after normalizing runtime identities.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'ebox-playground)
(require 'ebox-playground-flex-resize-evaluator
         (expand-file-name "scripts/ebox-playground-flex-resize-evaluator.el"
                           ebox-playground-directory))

(defconst ebox-playground-layer-test--file
  (expand-file-name "examples/layer-reference.ebox" ebox-playground-directory)
  "Layer lab loaded by this suite through the ordinary file runner.")

(cl-defmacro ebox-playground-layer-test--with-preview
    ((buffer &optional (width 720)) &rest body)
  "Run BODY in a fresh BUFFER preview of WIDTH pixels and clean up afterward."
  (declare (indent 1) (debug ((symbolp &optional form) body)))
  `(let ((,buffer (generate-new-buffer " *ebox-layer-test*"))
         (ebox-viewport-width ,width) (ebox-viewport-height 100)
         (case-fold-search nil)
         (ebox-runtime-idle-prewarm nil)
         (ebox-runtime-idle-reflow-cache-prewarm nil))
     (unwind-protect
         (progn
           (ebox-playground-open-file
            ebox-playground-layer-test--file (buffer-name ,buffer))
           (with-current-buffer ,buffer ,@body))
       (when (buffer-live-p ,buffer)
         (ebox-playground-close (buffer-name ,buffer))))))

(defun ebox-playground-layer-test--position (label)
  "Return the first visible position of LABEL in the current preview."
  (save-excursion
    (goto-char (point-min))
    (unless (search-forward label nil t)
      (ert-fail (format "Missing visible layer label: %s" label)))
    (- (point) (length label))))

(defun ebox-playground-layer-test--coordinates (label)
  "Return LABEL's visible horizontal pixel and zero-based row coordinates."
  (save-excursion
    (goto-char (ebox-playground-layer-test--position label))
    (cons (ebox-string-pixel-width
           (buffer-substring (line-beginning-position) (point)))
          (1- (line-number-at-pos)))))

(defun ebox-playground-layer-test--parity ()
  "Compare native paint and interactions with the committed snapshot render."
  (let* ((state (ebox--buffer-render-state (current-buffer)))
         (ebox-viewport-width (plist-get state :viewport-width))
         (ebox-viewport-height (plist-get state :viewport-height))
         (snapshot (ebox-surface-buffer-snapshot (current-buffer)))
         (fresh (ebox-render (plist-get snapshot :input))))
    (should (ebox-canonical-input-p (plist-get snapshot :input)))
    (should
     (equal-including-properties
      (ebox-playground-scroll-evaluator--visual-text (buffer-string))
      (ebox-playground-scroll-evaluator--visual-text fresh)))))

(defun ebox-playground-layer-test--activate (label &optional key)
  "Invoke the native command at LABEL using KEY, then verify its publication."
  (let* ((keys (or key (kbd "RET")))
         (position (ebox-playground-layer-test--position label))
         (map (get-text-property position 'keymap)))
    (goto-char position)
    (should (keymapp map))
    (let ((command (key-binding keys))
          (last-input-event (aref (vconcat keys) (1- (length keys)))))
      (should (commandp command))
      (should (eq command (lookup-key map keys)))
      (call-interactively command)
      (ebox-playground-layer-test--parity)
      command)))

(defun ebox-playground-layer-test--click (label)
  "Dispatch LABEL's native mouse command while another buffer is current."
  (let* ((buffer (current-buffer))
         (position (ebox-playground-layer-test--position label))
         (map (get-text-property position 'keymap)))
    (save-window-excursion
      (set-window-buffer (selected-window) buffer)
      (let* ((event (list 'mouse-1 (list (selected-window) position '(0 . 0) 0)))
             (last-input-event event)
             (command (key-binding [mouse-1] nil nil position)))
        (should (commandp command))
        (should (eq command (lookup-key map [mouse-1])))
        (with-temp-buffer
          (call-interactively command nil (vector event))
          (should (zerop (buffer-size))))))
    (ebox-playground-layer-test--parity)))

(defun ebox-playground-layer-test--nodes (form)
  "Return DSL nodes in FORM without walking opaque property values."
  (when (and (consp form) (memq (car form) '(box text row column flex grid)))
    (let ((tail (cdr form)) (nodes (list form)))
      (while tail
        (if (keywordp (car tail))
            (setq tail (cddr tail))
          (setq nodes (append nodes (ebox-playground-layer-test--nodes (car tail)))
                tail (cdr tail))))
      nodes)))

(ert-deftest ebox-playground-layer-reference-declares-layers-with-one-font-size ()
  "Actual layout data contains the taught contracts and no font-size override."
  (let* ((form (ebox-playground--evaluate-form
                (ebox-playground--read-file ebox-playground-layer-test--file)
                ebox-playground-layer-test--file))
         (nodes (ebox-playground-layer-test--nodes form))
         (owner (cl-find-if
                 (lambda (node) (equal (plist-get (cdr node) :id) "menu-owner"))
                 nodes))
         (menu (cl-find-if
                (lambda (node) (equal (plist-get (cdr node) :id) "root-menu"))
                (ebox-playground-layer-test--nodes owner))))
    (should (ebox-canonical-input-p (ebox-build form)))
    (should (eq (plist-get (cdr owner) :overflow) 'hidden))
    (should (equal (plist-get (cdr owner) :height) '(lh 1)))
    (should (eq (plist-get (cdr menu) :layer) 'root))
    (should (equal (plist-get (cdr menu) :anchor) "menu-trigger"))
    (dolist (position '(relative absolute))
      (should (cl-some (lambda (node)
                         (eq (plist-get (cdr node) :position) position)) nodes)))
    (dolist (node nodes)
      (should-not (plist-member (cdr node) :isolation))
      (should-not (plist-member (cdr node) :font-size)))))

(ert-deftest ebox-playground-layer-covered-updates-reveal-latest-native-surface ()
  "Covered text remains retained; revealing it restores current native help."
  (ebox-playground-layer-test--with-preview (buffer)
    (should-not (string-match-p "LOWER REV" (buffer-string)))
    (should (ebox-region-resolve buffer "lower-note"))
    (ebox-playground-layer-test--activate "UPDATE COVERED NOTE")
    (ebox-playground-layer-test--activate "UPDATE COVERED NOTE" (kbd "SPC"))
    (should-not (string-match-p "LOWER REV" (buffer-string)))
    (should (string-match-p "lower rev=02" (buffer-string)))
    (ebox-playground-layer-test--activate "TOGGLE PANEL A")
    (let* ((position (ebox-playground-layer-test--position "LOWER REV 02"))
           (help (get-text-property position 'help-echo)))
      (should (eq (get-text-property position 'pointer) 'hand))
      (should (get-text-property position 'mouse-face))
      (should (functionp help))
      (should (string-match-p "revision 2; activated 0"
                              (funcall help (selected-window) buffer position))))
    (ebox-playground-layer-test--activate "LOWER REV 02" [return])
    (let* ((position (ebox-playground-layer-test--position "LOWER REV 02"))
           (help (get-text-property position 'help-echo)))
      (should (string-match-p "revision 2; activated 1"
                              (funcall help (selected-window) buffer position))))
    (ebox-playground-layer-test--activate "TOGGLE PANEL A")
    (should-not (string-match-p "LOWER REV" (buffer-string)))
    (ebox-playground-layer-test--activate "TOGGLE PANEL A")
    (should (integerp (ebox-playground-layer-test--position "LOWER REV 02")))))

(ert-deftest ebox-playground-layer-move-and-raise-preserve-flow-and-coverage ()
  "Moving changes paint coordinates; raising changes only overlap ownership."
  (ebox-playground-layer-test--with-preview (buffer)
    (let ((home (ebox-playground-layer-test--coordinates "PANEL A / blue"))
          (desk-end (ebox-playground-layer-test--coordinates "DESK END")))
      (should-not (string-match-p "A survives under the amber panel" (buffer-string)))
      (ebox-playground-layer-test--activate "RAISE / LOWER A")
      (should (integerp (ebox-playground-layer-test--position
                         "A survives under the amber panel")))
      (should-not (string-match-p "PANEL B / amber" (buffer-string)))
      (should (equal home (ebox-playground-layer-test--coordinates "PANEL A / blue")))
      (ebox-playground-layer-test--activate "RAISE / LOWER A")
      (should (integerp (ebox-playground-layer-test--position "PANEL B / amber")))
      (ebox-playground-layer-test--activate "MOVE PANEL A")
      (let ((moved (ebox-playground-layer-test--coordinates "PANEL A / blue")))
        (should (> (car moved) (car home)))
        (should (= (cdr moved) (- (cdr home) 2))))
      (should (equal desk-end (ebox-playground-layer-test--coordinates "DESK END")))
      (ebox-playground-layer-test--activate "MOVE PANEL A")
      (should (equal home (ebox-playground-layer-test--coordinates "PANEL A / blue"))))))

(ert-deftest ebox-playground-layer-relative-marker-reserves-its-original-row ()
  "The relative marker moves into row two while row three retains its slot."
  (ebox-playground-layer-test--with-preview (buffer)
    (let ((marker (ebox-playground-layer-test--coordinates "RELATIVE / +4ch, +1lh"))
          (following (ebox-playground-layer-test--coordinates "FLOW ROW 3")))
      (should (= (1+ (cdr marker)) (cdr following)))
      (should (> (car marker) (car following)))
      (save-excursion
        (goto-char (ebox-playground-layer-test--position "RELATIVE / +4ch, +1lh"))
        (forward-line -1)
        (should (string-match-p
                 "\\`[[:space:]]*\\'"
                 (buffer-substring-no-properties
                  (line-beginning-position) (line-end-position)))))
      (ebox-playground-layer-test--parity))))

(ert-deftest ebox-playground-layer-root-menu-follows-all-four-anchor-placements ()
  "The nested menu escapes its one-row owner and follows the moved trigger."
  (ebox-playground-layer-test--with-preview (buffer)
    (should-not (string-match-p "ROOT MENU / choose" (buffer-string)))
    (ebox-playground-layer-test--activate "OPEN / CLOSE ROOT MENU")
    (let* ((trigger (ebox-playground-layer-test--coordinates "OPEN / CLOSE ROOT MENU"))
           (bottom-start (ebox-playground-layer-test--coordinates "ROOT MENU / choose")))
      (should (= (cdr bottom-start) (1+ (cdr trigger))))
      (should (= (car bottom-start) (car trigger)))
      (ebox-playground-layer-test--activate "CYCLE PLACEMENT")
      (let ((bottom-end (ebox-playground-layer-test--coordinates "ROOT MENU / choose")))
        (should (= (cdr bottom-end) (cdr bottom-start)))
        (should (> (car bottom-end) (car bottom-start)))
        (ebox-playground-layer-test--activate "CYCLE PLACEMENT")
        (let ((top-start (ebox-playground-layer-test--coordinates "ROOT MENU / choose")))
          (should (= (cdr top-start) (- (cdr trigger) 3)))
          (should (= (car top-start) (car bottom-start))))
        (ebox-playground-layer-test--activate "CYCLE PLACEMENT")
        (let ((top-end (ebox-playground-layer-test--coordinates "ROOT MENU / choose")))
          (should (= (cdr top-end) (- (cdr trigger) 3)))
          (should (= (car top-end) (car bottom-end))))
        (ebox-playground-layer-test--activate "CYCLE PLACEMENT"))
      (should (equal bottom-start (ebox-playground-layer-test--coordinates "ROOT MENU / choose")))
      (ebox-playground-layer-test--activate "MOVE ANCHOR")
      (let ((moved-trigger (ebox-playground-layer-test--coordinates "OPEN / CLOSE ROOT MENU"))
            (moved-menu (ebox-playground-layer-test--coordinates "ROOT MENU / choose")))
        (should (> (car moved-trigger) (car trigger)))
        (should (= (- (car moved-menu) (car bottom-start))
                   (- (car moved-trigger) (car trigger))))))
    (let ((position (ebox-playground-layer-test--position "CHOOSE SAGE")))
      (dolist (property '(keymap mouse-face help-echo pointer))
        (should (get-text-property position property))))
    (ebox-playground-layer-test--click "CHOOSE SAGE")
    (should-not (string-match-p "ROOT MENU / choose" (buffer-string)))
    (should (integerp (ebox-playground-layer-test--position
                       "Selected sage from the anchored menu.")))
    (ebox-playground-layer-test--activate "OPEN / CLOSE ROOT MENU")
    (ebox-playground-layer-test--activate "CHOOSE AMBER" (kbd "SPC"))
    (should (integerp (ebox-playground-layer-test--position
                       "Selected amber from the anchored menu.")))))

(ert-deftest ebox-playground-layer-previews-retain-independent-state-at-two-widths ()
  "Separate previews keep independent notes and menus, with bounded rendering."
  (ebox-playground-layer-test--with-preview (first)
    (ebox-playground-layer-test--activate "UPDATE COVERED NOTE")
    (ebox-playground-layer-test--with-preview (second 1000)
      (should (string-match-p "lower rev=00" (buffer-string)))
      (ebox-playground-layer-test--activate "OPEN / CLOSE ROOT MENU")
      (with-current-buffer first
        (should (string-match-p "lower rev=01" (buffer-string)))
        (should-not (string-match-p "ROOT MENU / choose" (buffer-string)))
        (ebox-playground-layer-test--parity))
      (dolist (line (ebox-string-lines (buffer-string)))
        (should (<= (ebox-string-pixel-width line) 1000)))
      (ebox-playground-layer-test--parity))))

(provide 'ebox-playground-layer-tests)
;;; ebox-playground-layer-tests.el ends here
