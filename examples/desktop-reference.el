;;; desktop-reference.el --- Direct manipulation for the desktop example -*- lexical-binding: t; -*-

;;; Commentary:
;; The matching .ebox file declares the five windows and their initial layout.
;; Native mouse tracking publishes positions while the button is held.  All
;; document changes use public Ebox region updates; each preview owns its state.

;;; Code:

(require 'cl-lib)
(require 'ebox)

(cl-defstruct (desktop-demo-window (:constructor desktop-demo-window-create))
  "A desktop pane's identity, palette, initial offsets and pixel displacement."
  id label accent ink left top (x 0) (y 0))

(cl-defstruct (desktop-demo (:constructor desktop-demo-create))
  "Independent state captured by the native commands of one desktop preview."
  windows order active (serial 5) dragging)

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

(defun desktop-demo--chrome (pane active)
  "Return title and dock updates for PANE, highlighted when ACTIVE."
  (let ((background (if active (desktop-demo-window-accent pane) "#25324B"))
        (foreground (if active (desktop-demo-window-ink pane) "#C1CBE0")))
    (mapcar (lambda (suffix)
              (list (concat (desktop-demo-window-id pane) suffix)
                    :background-color background :color foreground))
            '("-title" "-dock"))))

(defun desktop-demo--keyboard-anchor ()
  "Capture the native control at point for keyboard repeat, if applicable."
  (unless (mouse-event-p last-input-event)
    (let* ((map (get-text-property (point) 'keymap))
           (command (and (keymapp map) (lookup-key map [mouse-1]))))
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
            (when (and (keymapp map) (eq (lookup-key map [mouse-1]) (car anchor)))
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
          (desktop-demo-serial demo) (desktop-demo-serial candidate)
          (desktop-demo-dragging demo) (desktop-demo-dragging candidate))
    (desktop-demo--restore-keyboard-anchor anchor)))

(defun desktop-demo-activate (demo id &optional dragging)
  "Bring DEMO's pane ID forward; DRAGGING begins a transient mouse gesture."
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
                  (desktop-demo--window demo (desktop-demo-active demo)) nil)
                 (desktop-demo--chrome pane t)))))
    (when dragging (setf (desktop-demo-dragging demo) id))))

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

(defun desktop-demo--frame-point (position frame)
  "Convert a supported mouse POSITION to pixels in FRAME, or return nil.
Text-window positions and same-frame outside-window positions are supported;
fringe, scrollbar and other area-specific coordinate systems are skipped."
  (let ((where (posn-window position)) (xy (posn-x-y position)))
    (when (and (consp xy) (numberp (car xy)) (numberp (cdr xy)))
      (cond
       ((eq where frame) xy)
       ((and (window-live-p where) (eq (window-frame where) frame)
             (null (posn-area position)))
        (let ((edges (window-inside-pixel-edges where)))
          (cons (+ (car edges) (car xy)) (+ (cadr edges) (cdr xy)))))))))

(defun desktop-demo-drag (demo id event)
  "Raise DEMO's pane ID and track its title-bar press EVENT until release.
Publish each changed position before reading the next event.  Preserve the
grab offset, consume the release endpoint and retain unrelated input.  Quit
or failure releases gesture state and keeps the last accepted geometry."
  (let* ((position (event-start event))
         (window (posn-window position)))
    (unless (and (window-live-p window) (null (posn-area position)))
      (user-error "Drag a desktop title bar in a live text window"))
    (let* ((buffer (window-buffer window))
           (frame (window-frame window))
           (start (desktop-demo--frame-point position frame))
           (pane (desktop-demo--window demo id))
           (origin-x (desktop-demo-window-x pane))
           (origin-y (desktop-demo-window-y pane))
           (row-height (max 1 (frame-char-height frame)))
           (button (event-basic-type event))
           (mouse-fine-grained-tracking t))
      (unless start (user-error "The drag event has no text coordinates"))
      (unwind-protect
          (with-current-buffer buffer
            (desktop-demo-activate demo id t)
            (redisplay t)
            (track-mouse
              (let ((track-mouse 'dragging) done)
                (while (and (not done) (window-live-p window)
                            (buffer-live-p buffer) (eq (window-buffer window) buffer)
                            (ebox-surface-buffer-mounted-p buffer))
                  (let* ((next (read-event))
                         (release
                          (and (eq (event-basic-type next) button)
                               (or (memq 'click (event-modifiers next))
                                   (memq 'drag (event-modifiers next)))))
                         (point (when (or release (mouse-movement-p next))
                                  (desktop-demo--frame-point
                                   (if release (event-end next) (event-start next)) frame))))
                    (when (and point (window-live-p window) (buffer-live-p buffer)
                               (eq (window-buffer window) buffer)
                               (ebox-surface-buffer-mounted-p buffer))
                      (let* ((edges (window-inside-pixel-edges window))
                             ;; Keep the grab point in the original text window.
                             (x (max (nth 0 edges) (min (1- (nth 2 edges)) (car point))))
                             (y (max (nth 1 edges) (min (1- (nth 3 edges)) (cdr point)))))
                        (with-current-buffer buffer
                          (when (desktop-demo-move
                                 demo id (+ origin-x (round (- x (car start))))
                                 (+ origin-y (* row-height
                                                (round (/ (- y (cdr start))
                                                          (float row-height)))))
                                 row-height)
                            (redisplay t)))))
                    (cond
                     (release (setq done t))
                     ((mouse-movement-p next) nil)
                     (t (push next unread-command-events) (setq done t))))))))
        (setf (desktop-demo-dragging demo) nil)))))

(defun desktop-demo--nudge (demo id dx dy)
  "Activate DEMO's pane ID and move it DX columns and DY host rows."
  (desktop-demo-activate demo id)
  (let ((pane (desktop-demo--window demo id)))
    (desktop-demo-move demo id
                       (+ (desktop-demo-window-x pane) (* dx (frame-char-width)))
                       (+ (desktop-demo-window-y pane) (* dy (frame-char-height))))))

(defun desktop-demo-keymap (demo id &optional title)
  "Create DEMO's pane ID keymap; TITLE enables native live dragging."
  (let ((press (if title (lambda () (desktop-demo-drag demo id last-input-event))
                 (lambda () (desktop-demo-activate demo id)))))
    (ebox-keymap-create
     :activate (lambda () (desktop-demo-activate demo id))
     :bindings
     (append
      (mapcar (lambda (event) (cons event press))
              '([down-mouse-1] [double-down-mouse-1] [triple-down-mouse-1]))
      (list (cons "M-<left>" (lambda () (desktop-demo--nudge demo id -1 0)))
            (cons "M-<right>" (lambda () (desktop-demo--nudge demo id 1 0)))
            (cons "M-<up>" (lambda () (desktop-demo--nudge demo id 0 -1)))
            (cons "M-<down>" (lambda () (desktop-demo--nudge demo id 0 1))))))))

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
                                    pane (equal active (desktop-demo-window-id pane))))))
    (setf (desktop-demo-windows candidate) panes (desktop-demo-order candidate) ids
          (desktop-demo-active candidate) active (desktop-demo-serial candidate) (length ids))
    (desktop-demo--publish demo candidate updates)))

(defun desktop-demo-control (demo action)
  "Create a native toolbar command for DEMO's ACTION."
  (ebox-keymap-create
   :activate
   (lambda ()
     (pcase action
       ('reset (desktop-demo-reset demo))
       ('next (desktop-demo-activate demo (car (desktop-demo-order demo))))
       (_ (error "Unknown desktop action: %s" action))))))

(provide 'desktop-demo-reference)
;;; desktop-reference.el ends here
