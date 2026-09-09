;;; layer-reference.el --- State and actions for the layer lab -*- lexical-binding: t; -*-

;;; Commentary:
;; The matching .ebox file owns every layout declaration.  Each evaluation
;; creates independent application state; public Ebox adapters dispatch native
;; commands and help in the preview buffer and update semantic region IDs.

;;; Code:

(require 'cl-lib)
(require 'ebox)

(cl-defstruct (layer-demo (:constructor layer-demo-create))
  "Application state belonging to one layer-lab preview."
  (visible t) moved raised (revision 0) (lower-clicks 0)
  menu-visible (placement 0) anchor-moved (selection "none")
  exploded (focus 2) warm)

(defun layer-demo-orbit-status (demo)
  "Describe the spatial desktop controls for DEMO."
  (format "%s   /   %s IN FRONT   /   %s PALETTE"
          (if (layer-demo-exploded demo) "EXPANDED" "STACKED")
          (aref ["STUDIO" "NEXT" "SIGNAL"] (layer-demo-focus demo))
          (if (layer-demo-warm demo) "SOLAR" "LUNAR")))

(defconst layer-demo-placements
  [bottom-start bottom-end top-start top-end]
  "Anchor placements visited by the lab's placement control.")

(defun layer-demo-lower-content (demo)
  "Return the covered note's current content for DEMO."
  (format "LOWER REV %02d\nUpdated even while covered.\nReveal me, then click this surface.\nLower activations: %02d\nThe logical note never left the tree."
          (layer-demo-revision demo) (layer-demo-lower-clicks demo)))

(defun layer-demo-status (demo)
  "Describe DEMO's currently published panel and menu state."
  (format "A: %s / %s / z=%d  |  lower rev=%02d  |  menu: %s / %s  |  choice: %s"
          (if (layer-demo-visible demo) "shown" "hidden")
          (if (layer-demo-moved demo) "moved" "home")
          (if (layer-demo-raised demo) 4 2)
          (layer-demo-revision demo)
          (if (layer-demo-menu-visible demo) "open" "closed")
          (aref layer-demo-placements (layer-demo-placement demo))
          (layer-demo-selection demo)))

(defun layer-demo-help (demo subject)
  "Return live native help for DEMO's SUBJECT."
  (pcase subject
    ('lower (format "Lower note revision %d; activated %d times. RET / SPC / click."
                    (layer-demo-revision demo) (layer-demo-lower-clicks demo)))
    ('menu (format "Menu is %s; placement %s; selected %s. RET / SPC / click."
                   (if (layer-demo-menu-visible demo) "open" "closed")
                   (aref layer-demo-placements (layer-demo-placement demo))
                   (layer-demo-selection demo)))
    (_ (layer-demo-status demo))))

(defun layer-demo-action (demo action)
  "Create a native keymap for DEMO's business ACTION."
  (ebox-keymap-create
   :activate
   (lambda ()
     (pcase action
       ('explode
        (setf (layer-demo-exploded demo) (not (layer-demo-exploded demo)))
        (let ((expanded (layer-demo-exploded demo)))
          (ebox-region-update "orbit-violet"
                              :left (if expanded '(ch 2) '(ch 4))
                              :top (if expanded '(lh 1) '(lh 3)))
          (ebox-region-update "orbit-signal"
                              :left (if expanded '(ch 26) '(ch 20))
                              :top (if expanded '(lh 11) '(lh 7)))
          (ebox-region-update "orbit-lime"
                              :left (if expanded '(ch 52) '(ch 46))
                              :top (if expanded '(lh 0) '(lh 2)))))
       ('focus
        (setf (layer-demo-focus demo) (% (1+ (layer-demo-focus demo)) 3))
        (cl-loop for id in '("orbit-violet" "orbit-lime" "orbit-signal")
                 for index from 0
                 do (ebox-region-update id :z-index
                                        (if (= index (layer-demo-focus demo))
                                            6 (+ index 2)))))
       ('mood
        (setf (layer-demo-warm demo) (not (layer-demo-warm demo)))
        (cl-loop for id in '("orbit-violet" "orbit-signal" "orbit-lime")
                 for color in (if (layer-demo-warm demo)
                                  '("#FFADCF" "#FFD49B" "#B8F1CD")
                                '("#A99BFF" "#B9E9F2" "#D7FA73"))
                 do (ebox-region-update id :background-color color)))
       ('toggle
        (setf (layer-demo-visible demo) (not (layer-demo-visible demo)))
        (ebox-region-update "panel-a" :visibility
                            (if (layer-demo-visible demo) 'visible 'hidden)))
       ('move
        (setf (layer-demo-moved demo) (not (layer-demo-moved demo)))
        (ebox-region-update "panel-a"
                            :left (if (layer-demo-moved demo) '(ch 10) '(ch 4))
                            :top (if (layer-demo-moved demo) '(lh 0) '(lh 2))))
       ('raise
        (setf (layer-demo-raised demo) (not (layer-demo-raised demo)))
        (ebox-region-update "panel-a" :z-index
                            (if (layer-demo-raised demo) 4 2)))
       ('update-lower
        (cl-incf (layer-demo-revision demo))
        (ebox-region-update "lower-note" :content (layer-demo-lower-content demo)))
       ('lower
        (cl-incf (layer-demo-lower-clicks demo))
        (ebox-region-update "lower-note" :content (layer-demo-lower-content demo)))
       ('menu
        (setf (layer-demo-menu-visible demo) (not (layer-demo-menu-visible demo)))
        (ebox-region-update "root-menu" :visibility
                            (if (layer-demo-menu-visible demo) 'visible 'hidden)))
       ('placement
        (setf (layer-demo-placement demo) (% (1+ (layer-demo-placement demo)) 4))
        (ebox-region-update "root-menu" :placement
                            (aref layer-demo-placements (layer-demo-placement demo))))
       ('anchor
        (setf (layer-demo-anchor-moved demo) (not (layer-demo-anchor-moved demo)))
        (ebox-region-update "menu-trigger" :left
                            (if (layer-demo-anchor-moved demo) '(ch 12) '(ch 4))))
       ((or 'sage 'amber)
        (setf (layer-demo-selection demo) (symbol-name action)
              (layer-demo-menu-visible demo) nil)
        (ebox-region-update "menu-result" :content
                            (format "Selected %s from the anchored menu." action)
                            :color (if (eq action 'sage) "#286347" "#895314"))
        (ebox-region-update "root-menu" :visibility 'hidden))
       (_ (error "Unknown layer-lab action: %S" action)))
     (if (memq action '(explode focus mood))
         (ebox-region-update "orbit-state" :content (layer-demo-orbit-status demo))
       (ebox-region-update "layer-status" :content (layer-demo-status demo))))))

(provide 'layer-demo-reference)

;;; layer-reference.el ends here
