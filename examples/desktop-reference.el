;;; desktop-reference.el --- Direct manipulation for the desktop example -*- lexical-binding: t; -*-

;;; Commentary:
;; The matching .ebox file declares the five windows and their initial layout.
;; Native mouse tracking publishes positions while the button is held.  All
;; document changes use public Ebox region updates; each preview owns its state.

;;; Code:

(require 'cl-lib)
(require 'ebox)

(defun desktop-demo--dismiss-mouse-selection ()
  "Consume a native text-selection command in a desktop preview."
  (interactive)
  (deactivate-mark))

(defvar desktop-demo-input-mode-map
  (let ((map (make-sparse-keymap)))
    (dolist (command '(mouse-drag-region mouse-set-region mouse-set-point
                      mouse-save-then-kill mouse-drag-secondary
                      mouse-start-secondary mouse-set-secondary
                      mouse-secondary-save-then-kill))
      (define-key map (vector 'remap command) #'desktop-demo--dismiss-mouse-selection))
    map)
  "Desktop-local fallbacks for mouse events outside individual controls.")

(defun desktop-demo--clear-mouse-mark ()
  "Clear a preceding text selection when a desktop mouse command starts."
  (when (mouse-event-p last-input-event)
    (deactivate-mark)))

(define-minor-mode desktop-demo-input-mode
  "Keep desktop gestures from entering native text selection.
Control text keymaps retain their own activation and title-drag commands."
  :lighter nil :keymap desktop-demo-input-mode-map
  (if desktop-demo-input-mode
      (progn
        (deactivate-mark)
        (add-hook 'pre-command-hook #'desktop-demo--clear-mouse-mark nil t))
    (remove-hook 'pre-command-hook #'desktop-demo--clear-mouse-mark t)))

(defun desktop-demo--sync-input-mode ()
  "Apply the desktop mouse policy only to a successfully mounted desktop."
  (desktop-demo-input-mode
   (if (and ebox-buffer-mode
            (condition-case nil
                (ebox-region-resolve (current-buffer) "desktop-root")
              (user-error nil)))
       1 -1)))

(add-hook 'ebox-buffer-mode-hook #'desktop-demo--sync-input-mode)

(cl-defstruct (desktop-demo-window (:constructor desktop-demo-window-create))
  "A desktop pane's identity, palette, initial offsets and pixel displacement."
  id label accent ink light-accent light-ink left top (x 0) (y 0))

(cl-defstruct (desktop-demo (:constructor desktop-demo-create))
  "Independent state captured by the native commands of one desktop preview."
  windows order active styles (theme 'dark) (serial 5))

(defun desktop-demo-style (demo role)
  "Return DEMO's current theme declarations for the semantic style ROLE."
  (let ((entry (assq role (desktop-demo-styles demo))))
    (unless entry (error "Unknown desktop style: %s" role))
    (nth (if (eq (desktop-demo-theme demo) 'light) 2 1) entry)))

(defun desktop-demo-chrome-style (demo pane active)
  "Return DEMO's themed title/dock declarations for PANE and ACTIVE state."
  (if active
      (if (eq (desktop-demo-theme demo) 'light)
          (list :background-color (desktop-demo-window-light-accent pane)
                :color (desktop-demo-window-light-ink pane))
        (list :background-color (desktop-demo-window-accent pane)
              :color (desktop-demo-window-ink pane)))
    (desktop-demo-style demo 'desktop-chrome)))

(defun desktop-demo--window (demo id)
  "Return DEMO's pane with semantic ID."
  (or (cl-find id (desktop-demo-windows demo)
               :key #'desktop-demo-window-id :test #'equal)
      (error "Unknown desktop window: %s" id)))

(defun desktop-demo-status (demo)
  "Describe DEMO's frontmost pane and its displacement."
  (let ((pane (desktop-demo--window demo (desktop-demo-active demo))))
    (format " %s / FRONT   X %+d  Y %+d   |   DRAG A TITLE BAR"
            (desktop-demo-window-label pane)
            (desktop-demo-window-x pane) (desktop-demo-window-y pane))))

(defun desktop-demo--chrome (demo pane active)
  "Return DEMO's themed title and dock updates for PANE and ACTIVE state."
  (let ((style (desktop-demo-chrome-style demo pane active)))
    (mapcar (lambda (suffix)
              (cons (concat (desktop-demo-window-id pane) suffix) style))
            '("-title" "-dock"))))

(defun desktop-demo--keyboard-anchor ()
  "Capture the native control at point for keyboard repeat, if applicable."
  (unless (mouse-event-p last-input-event)
    (let* ((map (get-text-property (point) 'keymap))
           (command (and (keymapp map) (lookup-key map (kbd "RET")))))
      (when (commandp command)
        (list command
              (- (point) (previous-single-property-change
                          (1+ (point)) 'keymap nil (point-min))))))))

(defun desktop-demo--restore-keyboard-anchor (anchor)
  "Restore point within ANCHOR's surviving native control after publication."
  (when anchor
    (let ((position (point-min)))
      (catch 'restored
        (while (< position (point-max))
          (let ((map (get-text-property position 'keymap))
                (end (next-single-property-change position 'keymap nil (point-max))))
            (when (and (keymapp map) (eq (lookup-key map (kbd "RET")) (car anchor)))
              (goto-char (+ position (min (cadr anchor) (1- (- end position)))))
              (throw 'restored t))
            (setq position end)))))))

(defun desktop-demo--publish (demo candidate updates)
  "Publish UPDATES and CANDIDATE's status, then advance DEMO's state.
Failed Ebox publication leaves the business state on its accepted generation."
  (let ((anchor (desktop-demo--keyboard-anchor)))
    (ebox-call-with-update-batch
     (lambda ()
       (dolist (update updates)
         (apply #'ebox-region-update update))
       (ebox-region-update "desktop-status" :content (desktop-demo-status candidate))))
    (setf (desktop-demo-windows demo) (desktop-demo-windows candidate)
          (desktop-demo-order demo) (desktop-demo-order candidate)
          (desktop-demo-active demo) (desktop-demo-active candidate)
          (desktop-demo-theme demo) (desktop-demo-theme candidate)
          (desktop-demo-serial demo) (desktop-demo-serial candidate))
    (desktop-demo--restore-keyboard-anchor anchor)))

(defun desktop-demo-activate (demo id)
  "Bring DEMO's pane ID forward."
  (let ((pane (desktop-demo--window demo id)))
    (unless (equal id (desktop-demo-active demo))
      (let ((candidate (copy-desktop-demo demo)))
        (setf (desktop-demo-active candidate) id
              (desktop-demo-order candidate)
              (append (remove id (desktop-demo-order demo)) (list id))
              (desktop-demo-serial candidate) (1+ (desktop-demo-serial demo)))
        (desktop-demo--publish
         demo candidate
         (append (list (list id :z-index (desktop-demo-serial candidate)))
                 (desktop-demo--chrome
                  demo (desktop-demo--window demo (desktop-demo-active demo)) nil)
                 (desktop-demo--chrome demo pane t)))))
    nil))

(defun desktop-demo-move (demo id x y &optional row-height)
  "Move DEMO's pane ID to pixel displacement X, Y from its initial offsets.
ROW-HEIGHT is the drag frame's host row size, defaulting to the selected frame.
Return non-nil only after a changed position has been published."
  (let ((pane (desktop-demo--window demo id)))
    (unless (and (= x (desktop-demo-window-x pane))
                 (= y (desktop-demo-window-y pane)))
      (let ((candidate (copy-desktop-demo demo))
            (moved (copy-desktop-demo-window pane))
            (rows (/ y (float (max 1 (or row-height (frame-char-height)))))))
        (setf (desktop-demo-window-x moved) x
              (desktop-demo-window-y moved) y
              (desktop-demo-windows candidate)
              (mapcar (lambda (item) (if (eq item pane) moved item))
                      (desktop-demo-windows demo)))
        (desktop-demo--publish
         demo candidate
         (list (list id :left `(calc (+ ,(desktop-demo-window-left pane) (px ,x)))
                     :top `(calc (+ ,(desktop-demo-window-top pane) (lh ,rows))))))
        t))))

(defun desktop-demo-drag-handler (demo id)
  "Return a shared Ebox gesture callback moving DEMO's pane ID."
  (let (origin-x origin-y row-height)
    (lambda (gesture)
      (pcase (plist-get gesture :phase)
        ('start
         (let ((pane (desktop-demo--window demo id)))
           (setq origin-x (desktop-demo-window-x pane)
                 origin-y (desktop-demo-window-y pane)
                 row-height (max 1 (frame-char-height
                                    (window-frame (plist-get gesture :window))))))
         (desktop-demo-activate demo id))
        ((or 'move 'end)
         (let ((delta (plist-get gesture :delta)))
           (desktop-demo-move
            demo id (+ origin-x (round (car delta)))
            (+ origin-y (* row-height (round (/ (cdr delta) (float row-height)))))
            row-height)))))))

(defun desktop-demo--nudge (demo id dx dy)
  "Activate DEMO's pane ID and move it DX columns and DY host rows."
  (desktop-demo-activate demo id)
  (let ((pane (desktop-demo--window demo id)))
    (desktop-demo-move demo id
                       (+ (desktop-demo-window-x pane) (* dx (frame-char-width)))
                       (+ (desktop-demo-window-y pane) (* dy (frame-char-height))))))

(defun desktop-demo-keymap (demo id &optional title)
  "Create DEMO's pane ID keymap; TITLE enables shared Ebox dragging."
  (ebox-keymap-create
   :activate (lambda () (desktop-demo-activate demo id))
   :drag (when title (desktop-demo-drag-handler demo id))
   :bindings
   (append
    (unless title
      (mapcar (lambda (event) (cons event (lambda () (desktop-demo-activate demo id))))
              '([down-mouse-1] [double-down-mouse-1] [triple-down-mouse-1])))
    (list (cons "M-<left>" (lambda () (desktop-demo--nudge demo id -1 0)))
          (cons "M-<right>" (lambda () (desktop-demo--nudge demo id 1 0)))
          (cons "M-<up>" (lambda () (desktop-demo--nudge demo id 0 -1)))
          (cons "M-<down>" (lambda () (desktop-demo--nudge demo id 0 1)))))))

(defun desktop-demo-reset (demo)
  "Restore DEMO's original positions and document-order stack in one update."
  (let* ((candidate (copy-desktop-demo demo))
         (panes (mapcar #'copy-desktop-demo-window (desktop-demo-windows demo)))
         (ids (mapcar #'desktop-demo-window-id panes))
         (active (car (last ids))) updates)
    (cl-loop for pane in panes for depth from 1 do
             (setf (desktop-demo-window-x pane) 0 (desktop-demo-window-y pane) 0)
             (push (list (desktop-demo-window-id pane)
                         :left (desktop-demo-window-left pane)
                         :top (desktop-demo-window-top pane) :z-index depth) updates)
             (setq updates
                   (append updates (desktop-demo--chrome
                                    demo pane (equal active (desktop-demo-window-id pane))))))
    (setf (desktop-demo-windows candidate) panes (desktop-demo-order candidate) ids
          (desktop-demo-active candidate) active (desktop-demo-serial candidate) (length ids))
    (desktop-demo--publish demo candidate updates)))

(defun desktop-demo-toggle-theme (demo)
  "Switch DEMO's complete palette without changing window geometry or order."
  (let ((candidate (copy-desktop-demo demo)) updates)
    (setf (desktop-demo-theme candidate)
          (if (eq (desktop-demo-theme demo) 'dark) 'light 'dark))
    (dolist (entry (desktop-demo-styles demo))
      (dolist (match (ebox-selector-query-buffer
                      (current-buffer) (concat "." (symbol-name (car entry)))))
        (when-let* ((handle (plist-get match :region-handle)))
          (push (cons handle (desktop-demo-style candidate (car entry))) updates))))
    (desktop-demo--publish
     demo candidate
     (append (nreverse updates)
             (desktop-demo--chrome
              candidate (desktop-demo--window demo (desktop-demo-active demo)) t)
             (list (list "desktop-theme" :content
                         (if (eq (desktop-demo-theme candidate) 'light) "DARK" "LIGHT")))))))

(defun desktop-demo-control (demo action)
  "Create a native toolbar command for DEMO's ACTION."
  (ebox-keymap-create
   :activate
   (lambda ()
     (pcase action
       ('reset (desktop-demo-reset demo))
       ('next (desktop-demo-activate demo (car (desktop-demo-order demo))))
       ('theme (desktop-demo-toggle-theme demo))
       (_ (error "Unknown desktop action: %s" action))))))

(provide 'desktop-demo-reference)
;;; desktop-reference.el ends here
