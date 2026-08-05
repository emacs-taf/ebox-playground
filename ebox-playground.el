;;; ebox-playground.el --- Public Ebox layout examples -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later
;; Author: Ebox contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (ebox "1.0.1"))
;; URL: https://github.com/ginqi7/ebox-playground

;;; Commentary:

;; This package is intentionally small and public-only.  It demonstrates the
;; Ebox contract without reaching into ebox-- internals.  ETAF's application
;; examples live in the sibling `etaf-playground' package.

;;; Code:

(require 'ebox)

(defconst ebox-playground-buffer-name "*Ebox Playground*"
  "Default buffer name used by `ebox-playground-open'.")

(defun ebox-playground--header ()
  "Return the gallery header."
  (ebox-create
   :content "Ebox Playground\nPixel-precise layout, composed only from public nodes."
   :width '(720)
   :padding '(1 (18))
   :border "#8F432F"
   :color "#252A2E"
   :bgcolor "#FFFDF8"
   :face 'bold
   :text-align 'center))

(defun ebox-playground--section-heading
    (number title copy border background)
  "Return a section heading for NUMBER, TITLE, COPY, BORDER, and BACKGROUND."
  (ebox-create
   :content (format "%s  %s\n%s" number title copy)
   :width '(720)
   :padding '(0 (16))
   :border border
   :border-bottom-p nil
   :color "#252A2E"
   :bgcolor background
   :wrap-mode 'word))

(defun ebox-playground--track-grid ()
  "Return the fixed and fractional track example."
  (ebox-grid
   :width '(718)
   :grid-template-columns '((220) 1fr)
   :gap '(1 (12))
   :border "#C97252"
   :bgcolor "#FFF9F5"
   (ebox-create :content "FIXED TRACK\n220 px stays exact"
                :width '(220) :padding '(1 0) :text-align 'center
                :color "#252A2E" :bgcolor "#F1D4C9")
   (ebox-create :content "FRACTIONAL TRACK\n1fr receives the remaining width"
                :width '(486) :padding '(1 0) :text-align 'center
                :color "#252A2E" :bgcolor "#F9E8E0")
   (ebox-create :content "The Grid owns one definite width; its tracks divide that space without competing viewport calculations."
                :grid-column '(1 :span 2) :width '(718) :padding '(1 0)
                :color "#663322" :bgcolor "#FFFDF8"
                :text-align 'center :wrap-mode 'word)))

(defun ebox-playground--placement-grid ()
  "Return the explicit Grid placement example."
  (ebox-grid
   :width '(718)
   :grid-template-columns '((210) (210) 1fr)
   :gap '(1 (10))
   :border "#6D8A73"
   :bgcolor "#F7FBF7"
   (ebox-create :content "SPAN 1 → 3" :grid-column '(1 :span 2)
                :width '(430) :padding '(1 0) :text-align 'center
                :color "#24422D" :bgcolor "#DCEBDD")
   (ebox-create :content "COLUMN 3" :grid-column 3 :grid-row 1
                :width '(278) :padding '(1 0) :text-align 'center
                :color "#24422D" :bgcolor "#C8DDCB")
   (ebox-create :content "ROW 2 / COL 1" :grid-column 1 :grid-row 2
                :width '(210) :padding '(1 0) :text-align 'center
                :color "#24422D" :bgcolor "#EDF5EE")
   (ebox-create :content "AUTO PLACED" :width '(210) :padding '(1 0)
                :text-align 'center
                :color "#24422D" :bgcolor "#E3F0E5")
   (ebox-create :content "STABLE CELLS" :width '(278) :padding '(1 0)
                :text-align 'center
                :color "#24422D" :bgcolor "#D4E6D7")))

(defun ebox-playground--composition-flex ()
  "Return the public node composition example."
  (ebox-flex
   :width '(720)
   :flex-flow '(row wrap)
   :gap '(1 (12))
   :padding '(1 (12))
   :border "#4E7890"
   :bgcolor "#F7FAFC"
   (ebox-create :content "COLUMN\nvertical composition"
                :flex-grow 1 :flex-shrink 1 :flex-basis '(200)
                :min-width '(180) :padding '(1 (12))
                :color "#193846" :bgcolor "#D9EAF2")
   (ebox-create :content "FLEX\nwrap and distribute"
                :flex-grow 1 :flex-shrink 1 :flex-basis '(200)
                :min-width '(180) :padding '(1 (12))
                :color "#3F3655" :bgcolor "#E7E2F1")
   (ebox-create :content "GRID\nplace in two dimensions"
                :flex-grow 1 :flex-shrink 1 :flex-basis '(200)
                :min-width '(180) :padding '(1 (12))
                :color "#6B3020" :bgcolor "#F1D4C9")))

(defun ebox-playground--footer ()
  "Return the public-contract footer."
  (ebox-create
   :content "PUBLIC CONTRACT  ebox-create · ebox-column · ebox-flex · ebox-grid · ebox-spacer"
   :width '(720)
   :padding '(0 (16))
   :border "#8D887F"
   :color "#4D5651"
   :bgcolor "#EEEAE2"
   :wrap-mode 'word))

;;;###autoload
(defun ebox-playground-view ()
  "Return a public Ebox example layout node without buffer side effects."
  (ebox-column
   (ebox-playground--header)
   (ebox-spacer :height 1)
   (ebox-playground--section-heading
    "01" "FIXED + FRACTIONAL"
    "A definite Grid width divides into one exact track and one flexible track."
    "#C97252" "#F1D4C9")
   (ebox-playground--track-grid)
   (ebox-spacer :height 1)
   (ebox-playground--section-heading
    "02" "EXPLICIT PLACEMENT"
    "Span columns, target cells, and leave the remaining nodes to auto placement."
    "#6D8A73" "#DCEBDD")
   (ebox-playground--placement-grid)
   (ebox-spacer :height 1)
   (ebox-playground--section-heading
    "03" "PUBLIC COMPOSITION"
    "Column, Flex, and Grid share the same public node contract."
    "#4E7890" "#D9EAF2")
   (ebox-playground--composition-flex)
   (ebox-spacer :height 1)
   (ebox-playground--footer)))

;;;###autoload
(defun ebox-playground-open (&optional buffer-name)
  "Render the public Ebox example into BUFFER-NAME and return its buffer."
  (interactive)
  (ebox-render-to-buffer (or buffer-name ebox-playground-buffer-name)
                         (ebox-playground-view)))

;;;###autoload
(defun ebox-playground-close (&optional buffer-name)
  "Kill the playground BUFFER-NAME and return its former buffer."
  (interactive)
  (let ((buffer (get-buffer (or buffer-name ebox-playground-buffer-name))))
    (when buffer
      (kill-buffer buffer))
    buffer))

(provide 'ebox-playground)

;;; ebox-playground.el ends here
