;;; ebox-playground.el --- Public Ebox layout examples -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later
;; Author: Ebox contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (ebox "2.0.0"))
;; URL: https://github.com/ginqi7/ebox-playground

;;; Commentary:

;; This package is intentionally small and public-only.  It demonstrates the
;; Ebox contract without reaching into internal implementation details.  ETAF's
;; application examples live in the sibling `etaf-playground' package.

;;; Code:

(require 'ebox)
(require 'cl-lib)
(require 'elisp-mode)
(require 'subr-x)
(defvar read-eval)

(defconst ebox-playground-buffer-name "*Ebox Playground*"
  "Default buffer name used by `ebox-playground-open'.")

(defvar ebox-dsl-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map emacs-lisp-mode-map)
    (define-key map (kbd "C-c C-c") #'ebox-dsl-render)
    map)
  "Keymap used by `ebox-dsl-mode'.")

(defconst ebox-playground--dsl-header-line
  "Ebox DSL  |  C-c C-c  Render preview"
  "Header line shown by `ebox-dsl-mode'.")

(defun ebox-playground--source-form ()
  "Read the single Ebox DSL form from the current buffer."
  (ebox-playground--evaluate-form
   (ebox-playground--read-form
    (buffer-substring-no-properties (point-min) (point-max)))))

;;;###autoload
(define-derived-mode ebox-dsl-mode emacs-lisp-mode "EboxDSL"
  "Major mode for Ebox DSL source files."
  (setq-local header-line-format ebox-playground--dsl-header-line)
  (setq-local truncate-lines nil)
  (setq-local bidi-display-reordering nil)
  (setq-local bidi-paragraph-direction 'left-to-right))

;;;###autoload
(defun ebox-dsl-render ()
  "Render the current DSL buffer beside its right-hand preview."
  (interactive)
  (delete-other-windows)
  (let* ((window-min-height 1)
         (window-min-width 1)
         (source-window (selected-window))
         (preview-window (split-window-right))
         (preview-width
          (ebox-playground--window-viewport-width preview-window))
         (bound-width (and (numberp ebox-viewport-width)
                           (> ebox-viewport-width 0)
                           (floor ebox-viewport-width)))
         (viewport-width
          (or bound-width preview-width
              ebox-playground-default-viewport-width))
         (ebox-viewport-width viewport-width)
         (source-buffer (current-buffer))
         (source-form (ebox-playground--source-form))
         (name (format "*Ebox Preview: %s*"
                       (or (buffer-file-name) (buffer-name))))
         (node (ebox-build source-form))
         (buffer (ebox-playground--render-to-preview-buffer name node)))
    (set-window-buffer source-window source-buffer)
    (set-window-buffer preview-window buffer)
    (select-window source-window)
    (message "Rendered Ebox DSL into %s" name)
    buffer))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-dsl-mode))

(defgroup ebox-playground nil
  "Run Ebox DSL examples from source files."
  :group 'ebox)

(defconst ebox-playground-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the Ebox Playground package.")

(defcustom ebox-playground-default-file
  (expand-file-name "examples/public-layout-gallery.ebox"
                    ebox-playground-directory)
  "Ebox DSL file rendered by `ebox-playground-open'."
  :type 'file
  :group 'ebox-playground)

(defcustom ebox-playground-default-viewport-width 720
  "Viewport width used when a caller does not provide one explicitly."
  :type 'positive-integer
  :group 'ebox-playground)

(defun ebox-playground--window-viewport-width (&optional window)
  "Return Ebox's shared display-safe viewport width for WINDOW."
  (ebox-viewport-window-width window))

(defun ebox-playground--effective-viewport-width (&optional window)
  "Return the caller's width, WINDOW's text width, or the compact default."
  (cond
   ((and (numberp ebox-viewport-width)
         (> ebox-viewport-width 0))
    (floor ebox-viewport-width))
   ((ebox-playground--window-viewport-width window))
   (t ebox-playground-default-viewport-width)))

(defun ebox-playground--apply-preview-display-settings (&optional canvas-background)
  "Apply canvas redisplay settings to the current preview buffer.
CANVAS-BACKGROUND fills display space outside generated root lines."
  (setq-local truncate-lines t)
  (setq-local header-line-format nil)
  (setq-local mode-line-format nil)
  (setq-local auto-hscroll-mode t)
  (setq-local fringe-indicator-alist
              (cl-remove-if
               (lambda (entry)
                 (memq (car-safe entry) '(truncation continuation)))
               (copy-tree fringe-indicator-alist)))
  (setq-local bidi-display-reordering nil)
  (setq-local bidi-paragraph-direction 'left-to-right)
  (setq-local bidi-inhibit-bpa t)
  (setq-local face-remapping-alist
              (when (stringp canvas-background)
                (list (list 'default (list :background canvas-background))))))

(defconst ebox-playground--preview-display-variables
  '(truncate-lines header-line-format mode-line-format auto-hscroll-mode
    fringe-indicator-alist bidi-display-reordering bidi-paragraph-direction
    bidi-inhibit-bpa face-remapping-alist)
  "Buffer-local display variables owned by a playground preview.")

(defun ebox-playground--preview-display-snapshot ()
  "Return the current values and locality of preview display variables."
  (mapcar
   (lambda (variable)
     (list variable
           (local-variable-p variable)
           (and (boundp variable) (symbol-value variable))))
   ebox-playground--preview-display-variables))

(defun ebox-playground--restore-preview-display-snapshot (snapshot)
  "Restore preview display variable SNAPSHOT in the current buffer."
  (dolist (entry snapshot)
    (let ((variable (nth 0 entry))
          (was-local-p (nth 1 entry))
          (value (nth 2 entry)))
      (if was-local-p
          (set (make-local-variable variable) value)
        (kill-local-variable variable)))))

(defun ebox-playground--render-to-preview-buffer (buffer node)
  "Render NODE into BUFFER with transactional preview display settings."
  (with-current-buffer (get-buffer-create buffer)
    (let ((snapshot (ebox-playground--preview-display-snapshot))
          (published-p nil))
      (unwind-protect
          (prog1
              (progn
                (ebox-playground--apply-preview-display-settings
                 (and (consp node)
                      (ebox-style-node-specified-value
                       node :background-color)))
                (ebox-render-to-buffer buffer node))
            (setq published-p t))
        (unless published-p
          (ebox-playground--restore-preview-display-snapshot snapshot))))))

(defun ebox-playground--render-node-to-buffer (buffer node viewport-width)
  "Render NODE into BUFFER using VIEWPORT-WIDTH.
Visible mounted buffers follow their window through Ebox's viewport controller."
  (let ((ebox-viewport-width
         (or viewport-width
             (ebox-playground--effective-viewport-width))))
    (ebox-playground--render-to-preview-buffer buffer node)))

(defun ebox-playground--static-value-p (value)
  "Return non-nil when VALUE is a literal or explicitly quoted form."
  (or (null value) (numberp value) (stringp value) (characterp value)
      (keywordp value) (eq value t)
      (and (consp value) (memq (car value) '(quote function)))))

(defun ebox-playground--evaluate-value (value)
  "Evaluate executable DSL VALUE while preserving literal data values."
  (if (ebox-playground--static-value-p value)
      (if (and (consp value) (memq (car value) '(quote function)))
          (eval value nil)
        value)
    (eval value nil)))

(defun ebox-playground--evaluate-items (items)
  "Evaluate property values and recurse into child forms in ITEMS."
  (let (result)
    (while items
      (let ((item (pop items)))
        (if (keywordp item)
            (progn
              (unless items
                    (error "Ebox playground: missing value for %S" item))
              (push item result)
              (push (ebox-playground--evaluate-value (pop items)) result))
          (push (ebox-playground--evaluate-form item) result))))
    (nreverse result)))

(defun ebox-playground--evaluate-form (form)
  "Evaluate property expressions in one structural DSL FORM."
  (if (and (consp form) (symbolp (car form)))
      (cons (car form) (ebox-playground--evaluate-items (cdr form)))
    form))

(defun ebox-playground--read-form (source)
  "Read one Ebox DSL form from SOURCE."
  (when (string-empty-p (string-trim source))
    (user-error "The Ebox DSL source is empty"))
  (with-temp-buffer
    (insert source)
    (goto-char (point-min))
    (let ((read-eval nil)
          (form (read (current-buffer))))
      (condition-case nil
          (progn
            (read (current-buffer))
            (user-error "The Ebox DSL source must contain one form"))
        (end-of-file form)))))

(defun ebox-playground--read-file (file)
  "Read one Ebox DSL form from FILE."
  (unless (file-readable-p file)
    (user-error "Ebox DSL file is not readable: %s" file))
  (with-temp-buffer
    (insert-file-contents file)
    (ebox-playground--read-form
     (buffer-substring-no-properties (point-min) (point-max)))))

;;;###autoload
(defun ebox-playground-view (&optional file viewport-width)
  "Build the Ebox DSL form in FILE at VIEWPORT-WIDTH without buffer side effects."
  (let ((ebox-viewport-width
         (or viewport-width (ebox-playground--effective-viewport-width))))
    (ebox-build
     (ebox-playground--evaluate-form
      (ebox-playground--read-file
       (expand-file-name (or file ebox-playground-default-file)))))))

;;;###autoload
(defun ebox-playground-open (&optional buffer-name)
  "Render the default Ebox DSL example into BUFFER-NAME and return its buffer."
  (interactive)
  (let ((viewport-width (ebox-playground--effective-viewport-width)))
    (ebox-playground--render-node-to-buffer
     (or buffer-name ebox-playground-buffer-name)
     (ebox-playground-view nil viewport-width)
     viewport-width)))

;;;###autoload
(defun ebox-playground-open-file (file &optional buffer-name)
  "Render Ebox DSL FILE into BUFFER-NAME and return its buffer."
  (interactive "fEbox DSL file: ")
  (let ((viewport-width (ebox-playground--effective-viewport-width)))
    (ebox-playground--render-node-to-buffer
     (or buffer-name
         (format "*Ebox Preview: %s*" (file-name-nondirectory file)))
     (ebox-playground-view file viewport-width)
     viewport-width)))

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
