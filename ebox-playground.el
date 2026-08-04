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

;;;###autoload
(defun ebox-playground-view ()
  "Return a public Ebox example layout node without buffer side effects."
  (ebox-grid
   :width '(640)
   :grid-template-columns '((200) 1fr)
   :grid-template-rows '(1 1 1)
   :gap '(1 (12))
   :padding '(1 2)
   :border '((1) solid "#687386")
   (ebox-create :content "Ebox Playground" :face 'bold)
   (ebox-create :content "A pixel-precise two-dimensional layout")
   (ebox-create :content "Row / column / flex / grid share the public node contract")
   (ebox-create :content "Fixed and fractional tracks")
   (ebox-create :content "Placement" :grid-column 1 :grid-row 3)
   (ebox-create :content "No private calls" :grid-column 2 :grid-row 3)))

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
