;;; ebox-playground-runtime.el --- Public Ebox layout examples -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later
;; Author: Ebox contributors
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

(defvar ebox-playground-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map emacs-lisp-mode-map)
    (define-key map (kbd "C-c C-c") #'ebox-playground-render)
    map)
  "Keymap used by `ebox-playground-mode'.")

(defconst ebox-playground--dsl-header-line
  "Ebox DSL  |  C-c C-c  Render preview"
  "Header line shown by `ebox-playground-mode'.")

(defun ebox-playground--source-form ()
  "Read and evaluate the single Elisp expression in the current buffer."
  (ebox-playground--evaluate-form
   (ebox-playground--read-form
    (buffer-substring-no-properties (point-min) (point-max)))
   buffer-file-name))

;;;###autoload
(define-derived-mode ebox-playground-mode emacs-lisp-mode "EboxDSL"
  "Major mode for Ebox DSL source files."
  (setq-local header-line-format ebox-playground--dsl-header-line)
  (setq-local truncate-lines nil)
  (setq-local bidi-display-reordering nil)
  (setq-local bidi-paragraph-direction 'left-to-right))

;;;###autoload
(defun ebox-playground-render ()
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

;; Playground owns the richer split-window interaction while Ebox core owns
;; the standalone file mode and single-buffer preview command.
(define-key ebox-playground-mode-map (kbd "C-c C-c") #'ebox-playground-render)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ebox\\'" . ebox-playground-mode))

(defgroup ebox-playground nil
  "Run Ebox DSL examples from source files."
  :group 'ebox)

(defconst ebox-playground-directory
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))
  "Directory containing the Ebox Playground package.")

(defcustom ebox-playground-default-file
  (expand-file-name "examples/grid-reference.ebox"
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

(defun ebox-playground--apply-preview-display-settings ()
  "Apply text redisplay settings without overriding buffer chrome or faces."
  (setq-local truncate-lines t)
  (setq-local auto-hscroll-mode t)
  (setq-local fringe-indicator-alist
              (cl-remove-if
               (lambda (entry)
                 (memq (car-safe entry) '(truncation continuation)))
               (copy-tree fringe-indicator-alist)))
  (setq-local bidi-display-reordering nil)
  (setq-local bidi-paragraph-direction 'left-to-right)
  (setq-local bidi-inhibit-bpa t))

(defconst ebox-playground--preview-display-variables
  '(truncate-lines auto-hscroll-mode
    fringe-indicator-alist bidi-display-reordering bidi-paragraph-direction
    bidi-inhibit-bpa)
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

(defun ebox-playground--render-to-preview-buffer (buffer input)
  "Render canonical INPUT into BUFFER with transactional display settings."
  (unless (ebox-canonical-input-p input)
    (signal 'wrong-type-argument (list 'ebox-canonical-input-p input)))
  (with-current-buffer (get-buffer-create buffer)
    ;; A preview name is stable across edits, while its canonical source
    ;; generation is not.  Drop the retained surface before publishing the
    ;; replacement so a failed/old generation can never remain visible.
    (when (ebox-surface-buffer-mounted-p (current-buffer))
      (ebox-unmount-buffer (current-buffer)))
    (erase-buffer)
    (let ((snapshot (ebox-playground--preview-display-snapshot))
          (published-p nil))
      (unwind-protect
          (prog1
              (progn
                (ebox-playground--apply-preview-display-settings)
                (ebox-render-to-buffer buffer input))
            (setq published-p t))
        (unless published-p
          (ebox-playground--restore-preview-display-snapshot snapshot))))))

(defun ebox-playground--render-input-to-buffer (buffer input viewport-width)
  "Render canonical INPUT into BUFFER using VIEWPORT-WIDTH.
Visible mounted buffers follow their window through Ebox's viewport controller."
  (let ((ebox-viewport-width
         (or viewport-width
             (ebox-playground--effective-viewport-width))))
    (ebox-playground--render-to-preview-buffer buffer input)))

(defun ebox-playground--evaluate-form (form &optional source-file)
  "Evaluate one Elisp FORM lexically to produce Ebox DSL data.
When SOURCE-FILE names a .ebox file, load its optional same-basename .el
companion first.  Reload that exact source file on every evaluation."
  (ebox-file-evaluate-form form source-file))

(defun ebox-playground--read-form (source)
  "Read exactly one Elisp expression from SOURCE."
  (ebox-file-read-form source))

(defun ebox-playground--read-file (file)
  "Read one Elisp expression from FILE."
  (ebox-file-read-file file))

;;;###autoload
(defun ebox-playground-view (&optional file viewport-width)
  "Build the Ebox DSL form in FILE at VIEWPORT-WIDTH without publishing it.
Reload FILE's optional same-basename .el companion before evaluating its DSL."
  (let ((ebox-viewport-width
         (or viewport-width (ebox-playground--effective-viewport-width)))
        (file (expand-file-name (or file ebox-playground-default-file))))
    (ebox-build
     (ebox-playground--evaluate-form
      (ebox-playground--read-file file) file))))

;;;###autoload
(defun ebox-playground-open (&optional buffer-name)
  "Render the default Ebox DSL example into BUFFER-NAME and return its buffer."
  (interactive)
  (let ((viewport-width (ebox-playground--effective-viewport-width)))
    (ebox-playground--render-input-to-buffer
     (or buffer-name ebox-playground-buffer-name)
     (ebox-playground-view nil viewport-width)
     viewport-width)))

;;;###autoload
(defun ebox-playground-open-file (file &optional buffer-name)
  "Render Ebox DSL FILE into BUFFER-NAME and return its buffer."
  (interactive "fEbox DSL file: ")
  (let ((viewport-width (ebox-playground--effective-viewport-width)))
    (ebox-playground--render-input-to-buffer
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

(provide 'ebox-playground-runtime)

;;; ebox-playground-runtime.el ends here
