;;; ebox-playground.el --- Public Ebox layout examples -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later
;; Author: Ebox contributors
;; Version: 0.1.1
;; Package-Requires: ((emacs "29.1") (ebox "3.0.0"))
;; URL: https://github.com/ginqi7/ebox-playground

;;; Commentary:

;; Public API
;;
;; Load this package with (require 'ebox-playground) after adding the repository
;; root to load-path.
;; Only the interfaces listed below are supported for use by other packages.
;; All unlisted symbols and implementation features are internal, including
;; names without a double hyphen. Do not require files below lisp/ from consumers.
;; This Commentary is the authoritative export list; implementations and precise
;; docstrings remain beside their definitions. The manual contains workflows.
;;
;; Function: ebox-playground-mode ()
;;;###autoload (autoload 'ebox-playground-mode "ebox-playground" nil t)
;; Major mode for Ebox DSL source files.
;;
;; In addition to any hooks its parent mode `emacs-lisp-mode' might have
;; run, this mode runs the hook `ebox-playground-mode-hook', as the final or
;; penultimate step during initialization.
;;
;; \{ebox-playground-mode-map}
;;
;; Variable: ebox-playground-mode-map
;; Keymap used by `ebox-playground-mode'.
;;
;; Function: ebox-playground-render ()
;;;###autoload (autoload 'ebox-playground-render "ebox-playground" nil t)
;; Render the current DSL buffer beside its right-hand preview.
;;
;; Variable: ebox-playground-directory
;; Directory containing the Ebox Playground package.
;;
;; Function: ebox-playground-open (&optional buffer-name)
;;;###autoload (autoload 'ebox-playground-open "ebox-playground" nil t)
;; Render the default Ebox DSL example into BUFFER-NAME and return its buffer.
;;
;; Function: ebox-playground-open-file (file &optional buffer-name)
;;;###autoload (autoload 'ebox-playground-open-file "ebox-playground" nil t)
;; Render Ebox DSL FILE into BUFFER-NAME and return its buffer.
;;

;;; Code:

;;;###autoload
(eval-and-compile
  (add-to-list 'load-path
               (expand-file-name "lisp"
                                 (file-name-directory
                                  (or load-file-name
                                      (bound-and-true-p byte-compile-current-file)
                                      buffer-file-name)))))

(require 'ebox-playground-runtime)

(provide 'ebox-playground)
;;; ebox-playground.el ends here
