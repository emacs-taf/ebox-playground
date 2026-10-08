;;; performance-scenarios.el --- Playground example interaction latency -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Interaction workloads on the maintained `.ebox' examples, run with the
;; workspace `scripts/performance.py'.  Each scenario opens one example through
;; `ebox-playground-open-file', places point on a visible control label once and
;; repeats that control's native key binding at point, or alternates the
;; viewport width.  Verification compares the live buffer with a fresh render of
;; a copy of the retained tree.
;;
;;   ebox-playground.desktop.nudge       M-<right>/M-<left> on a title bar
;;   ebox-playground.layer.explode       RET on EXPLODE STACK
;;   ebox-playground.interaction.add     RET on ADD
;;   ebox-playground.flex.resize         alternate the Flex reference width

;;; Code:
(require 'cl-lib)
(require 'ebox)
(require 'ebox-playground)
(declare-function taf-benchmark-register "performance-driver" (id &rest properties))

(defun ebox-playground-benchmark--file (name)
  "Return the example file NAME."
  (expand-file-name (concat "examples/" name) ebox-playground-directory))

(defun ebox-playground-benchmark--fresh-difference (buffer)
  "Return nil when BUFFER's text matches a fresh render of its tree."
  (pcase-let* ((`(,width . ,height) (ebox-mount-viewport buffer))
               (fresh (let ((ebox-viewport-width width) (ebox-viewport-height height))
                        (ebox-render (ebox-node-copy (ebox-buffer-root buffer)))))
               (live (with-current-buffer buffer
                       (buffer-substring-no-properties (point-min) (point-max)))))
    (unless (string= live (substring-no-properties fresh))
      (let ((i (or (compare-strings live nil nil fresh nil nil) 0)))
        (setq i (1- (abs i)))
        (format "Line %d differs from a fresh render"
                (1+ (cl-count ?\n live :end (min i (length live)))))))))

(defun ebox-playground-benchmark--observe (buffer)
  "Return an :observe function forwarding BUFFER's flush reports."
  (lambda (sink)
    (ebox-buffer-set-observer buffer sink)
    (lambda () (when (buffer-live-p buffer) (ebox-buffer-set-observer buffer nil)))))

(defun ebox-playground-benchmark--open (file height)
  "Open example FILE in a fresh buffer HEIGHT lines tall and return it."
  (let ((buffer (generate-new-buffer " *Ebox Playground benchmark*"))
        (ebox-viewport-width (window-body-width nil t))
        (ebox-viewport-height height))
    (ebox-playground-open-file file (buffer-name buffer))
    (ebox-mount-set-viewport buffer ebox-viewport-width height)
    buffer))

(cl-defun ebox-playground-benchmark--key-fixture (file label keys &key alternate (height 60))
  "Return a fixture repeating KEYS at LABEL in FILE.
With ALTERNATE, odd samples use those keys instead.  HEIGHT is in lines."
  (let* ((buffer (ebox-playground-benchmark--open file height))
         (sequences (mapcar #'kbd (if alternate (list keys alternate) (list keys)))))
    (with-current-buffer buffer
      (goto-char (point-min))
      (unless (search-forward label nil t)
        (error "Example label is not rendered: %s" label))
      (goto-char (match-beginning 0)))
    (list
     :buffer buffer
     :invoke (lambda (sample)
               (with-current-buffer buffer
                 (let* ((sequence (nth (% sample (length sequences)) sequences))
                        (command (key-binding sequence))
                        (last-input-event (aref sequence (1- (length sequence)))))
                   (unless (commandp command)
                     (error "%s lost its binding at %d" (key-description sequence) (point)))
                   (call-interactively command))))
     :observe (ebox-playground-benchmark--observe buffer)
     :verify (lambda () (or (ebox-playground-benchmark--fresh-difference buffer) t))
     :cleanup (lambda () (when (buffer-live-p buffer) (kill-buffer buffer))))))

(defun ebox-playground-benchmark--resize-fixture ()
  "Return a fixture alternating the Flex reference between two widths."
  (let* ((buffer (ebox-playground-benchmark--open
                  (ebox-playground-benchmark--file "flex-reference.ebox") 60))
         (wide (car (ebox-mount-viewport buffer)))
         (narrow (max 320 (- wide 160))))
    (list
     :buffer buffer
     :invoke (lambda (sample)
               (ebox-mount-set-viewport buffer (if (cl-evenp sample) narrow wide) 60))
     :observe (ebox-playground-benchmark--observe buffer)
     :verify (lambda () (or (ebox-playground-benchmark--fresh-difference buffer) t))
     :cleanup (lambda () (when (buffer-live-p buffer) (kill-buffer buffer))))))

(defun ebox-playground-benchmark--register (id description setup)
  "Register scenario ID with DESCRIPTION and a fixture SETUP thunk."
  (taf-benchmark-register
   id :version 1 :modes '(batch gui) :isolation 'series :impact 'local
   :budget-ms 16 :description description
   :setup (lambda (_mode) (funcall setup))))

(ebox-playground-benchmark--register
 "ebox-playground.desktop.nudge"
 "Move the Studio pane one column right or left from its title bar"
 (lambda ()
   (ebox-playground-benchmark--key-fixture
    (ebox-playground-benchmark--file "desktop-reference.ebox")
    "STUDIO / 01" "M-<right>" :alternate "M-<left>" :height 40)))

(ebox-playground-benchmark--register
 "ebox-playground.layer.explode"
 "Spread or restack the three ORBIT cards"
 (lambda ()
   (ebox-playground-benchmark--key-fixture
    (ebox-playground-benchmark--file "layer-reference.ebox") "EXPLODE STACK" "RET")))

(ebox-playground-benchmark--register
 "ebox-playground.interaction.add"
 "Add to the interaction lab counter and event log"
 (lambda ()
   (ebox-playground-benchmark--key-fixture
    (ebox-playground-benchmark--file "interaction-reference.ebox") "ADD 1" "RET")))

(ebox-playground-benchmark--register
 "ebox-playground.flex.resize"
 "Alternate the Flex reference between two viewport widths"
 #'ebox-playground-benchmark--resize-fixture)

(provide 'performance-scenarios)
;;; performance-scenarios.el ends here
