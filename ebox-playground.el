;;; ebox-playground.el --- Public Ebox layout examples -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later
;; Author: Ebox contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (ebox "1.0.1"))
;; URL: https://github.com/ginqi7/ebox-playground

;;; Commentary:

;; This package is intentionally small and public-only.  It demonstrates the
;; Ebox contract without reaching into internal implementation details.  ETAF's
;; application examples live in the sibling `etaf-playground' package.

;;; Code:

(require 'ebox)
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

(defun ebox-playground--source-form ()
  "Read the single Ebox DSL form from the current buffer."
  (ebox-playground--read-form
   (buffer-substring-no-properties (point-min) (point-max))))

;;;###autoload
(define-derived-mode ebox-dsl-mode emacs-lisp-mode "EboxDSL"
  "Major mode for Ebox DSL source files."
  (setq-local truncate-lines nil)
  (setq-local bidi-display-reordering nil)
  (setq-local bidi-paragraph-direction 'left-to-right))

;;;###autoload
(defun ebox-dsl-render ()
  "Render the current Ebox DSL buffer into a preview buffer."
  (interactive)
  (let* ((source (ebox-playground--source-form))
         (name (format "*Ebox Preview: %s*"
                       (or (buffer-file-name) (buffer-name))))
         (node (ebox-build source)))
    (ebox-render-to-buffer name node)
    (message "Rendered Ebox DSL into %s" name)
    (get-buffer name)))

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
(defun ebox-playground-view (&optional file)
  "Build the Ebox DSL form in FILE without buffer side effects."
  (ebox-build
   (ebox-playground--read-file
    (expand-file-name (or file ebox-playground-default-file)))))

;;;###autoload
(defun ebox-playground-open (&optional buffer-name)
  "Render the default Ebox DSL example into BUFFER-NAME and return its buffer."
  (interactive)
  (ebox-render-to-buffer (or buffer-name ebox-playground-buffer-name)
                         (ebox-playground-view)))

;;;###autoload
(defun ebox-playground-open-file (file &optional buffer-name)
  "Render Ebox DSL FILE into BUFFER-NAME and return its buffer."
  (interactive "fEbox DSL file: ")
  (ebox-render-to-buffer
   (or buffer-name
       (format "*Ebox Preview: %s*" (file-name-nondirectory file)))
   (ebox-playground-view file)))

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
