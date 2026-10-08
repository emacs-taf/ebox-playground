;;; interaction-reference.el --- State and actions for the interaction lab -*- lexical-binding: t; -*-

;;; Commentary:
;; Loaded by the generic playground runner before interaction-reference.ebox.
;; Each DSL evaluation creates its own state.  Ebox supplies command/keymap
;; construction and mouse-buffer targeting; actions update retained nodes
;; found by id or class.

;;; Code:

(require 'ebox)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(cl-defstruct (interaction-demo
               (:constructor interaction-demo--make))
  "Application state belonging to one interaction-lab preview."
  (count 0) (step 1) (enabled t) warm events (serial 0) keymap subtract-keymap)

(defun interaction-demo-create ()
  "Create independent state and bindings for a new preview."
  (let ((demo (interaction-demo--make)))
    (setf (interaction-demo-keymap demo)
          (interaction-demo--step-map demo)
          (interaction-demo-subtract-keymap demo)
          (interaction-demo--step-map demo t))
    demo))

(defun interaction-demo-description (demo &optional subtract)
  "Return DEMO's current action hint, describing subtraction when SUBTRACT."
  (format "Live help: count = %d; this action %s %d.  RET / SPC / click."
          (interaction-demo-count demo) (if subtract "subtracts" "adds")
          (interaction-demo-step demo)))

(defun interaction-demo--update (target &rest props)
  "Apply author PROPS to TARGET, a node or the id of nodes in this preview.
A :content property replaces the node's children with that string."
  (let ((content (plist-member props :content))
        (rest (cl-loop for (key value) on props by #'cddr
                       unless (eq key :content) append (list key value))))
    (dolist (node (if (stringp target)
                      (ebox-selector-query-buffer (current-buffer) (concat "#" target))
                    (list target)))
      (when rest
        (let ((merged (copy-sequence (ebox-node-props node))))
          (cl-loop for (key value) on rest by #'cddr
                   do (setq merged (plist-put merged key value)))
          (ebox-node-set-props node merged)))
      (when content
        (if (ebox-node-text-p node)
            (ebox-node-set-text node (cadr content))
          (ebox-node-replace-children node (list (ebox-text-create (cadr content)))))))))

(defun interaction-demo--record (demo description)
  "Record DEMO's action DESCRIPTION and refresh its four-line event log."
  (push (format "%02d  %s" (cl-incf (interaction-demo-serial demo))
                description)
        (interaction-demo-events demo))
  (setf (interaction-demo-events demo)
        (seq-take (interaction-demo-events demo) 4))
  (let ((events (interaction-demo-events demo)))
    (interaction-demo--update
     "event-log" :content
     (string-join (append events (make-list (- 4 (length events)) "—")) "\n"))))

(defun interaction-demo--show-count (demo)
  "Refresh the displayed count for DEMO."
  (interaction-demo--update "count" :content
                      (format "COUNT  %02d" (interaction-demo-count demo))))

(defun interaction-demo--add (demo amount)
  "Add AMOUNT to DEMO's count and record the action."
  (cl-incf (interaction-demo-count demo) amount)
  (interaction-demo--show-count demo)
  (interaction-demo--record
   demo (format "%+d → count %d" amount (interaction-demo-count demo))))

(defun interaction-demo-hover (demo)
  "Return DEMO's chosen hover palette using ordinary Ebox declarations."
  (if (interaction-demo-warm demo)
      '(:background-color "#F6D6AB" :color "#683D16"
        :text-decoration-line underline)
    '(:background-color "#BCDDE5" :color "#123E4B"
      :text-decoration-line underline)))

(defun interaction-demo--step-map (demo &optional subtract)
  "Create DEMO's captured step map, with SUBTRACT choosing negative activation."
  (let ((amount (interaction-demo-step demo)))
    (ebox-keymap-create
     :activate (lambda ()
                 (interaction-demo--add demo (if subtract (- amount) amount)))
     :bindings
     (list (cons "+" (lambda () (interaction-demo--add demo amount)))
           (cons "-" (lambda () (interaction-demo--add demo (- amount))))))))

(defun interaction-demo--refresh (demo)
  "Publish DEMO's current action properties and binding summary."
  (let ((enabled (interaction-demo-enabled demo))
        (step (interaction-demo-step demo)))
    (interaction-demo--update
     "live-action"
     :help-echo (and enabled
                     (ebox-help-create
                      (apply-partially #'interaction-demo-description demo)))
     :pointer (and enabled 'hand)
     :hover-style (and enabled (interaction-demo-hover demo))
     :keymap (and enabled (interaction-demo-keymap demo)))
    (interaction-demo--update
     "action-label" :content
     (if enabled (format "ADD %d   [+] " step) "BINDING REMOVED "))
    (interaction-demo--update
     "subtract-text"
     :help-echo (and enabled
                     (ebox-help-create
                      (apply-partially #'interaction-demo-description demo t)))
     :keymap (and enabled (interaction-demo-subtract-keymap demo))))
  (interaction-demo--update
   "binding-state" :content
   (format "step %d  ·  %s  ·  %s hover"
           (interaction-demo-step demo)
           (if (interaction-demo-enabled demo)
               "four properties attached" "four properties nil")
           (if (interaction-demo-warm demo) "warm" "cool"))))

(defun interaction-demo-action (demo action)
  "Return a native activation keymap for DEMO's named ACTION."
  (ebox-keymap-create
   :activate
   (lambda ()
     (ebox-with-batch
      (pcase action
       ('step
        (setf (interaction-demo-step demo)
              (if (= (interaction-demo-step demo) 1) 5 1)
              (interaction-demo-keymap demo)
              (interaction-demo--step-map demo)
              (interaction-demo-subtract-keymap demo)
              (interaction-demo--step-map demo t))
        (interaction-demo--refresh demo)
        (interaction-demo--record
         demo (format "Replaced keymap: step %d" (interaction-demo-step demo))))
       ('binding
        (setf (interaction-demo-enabled demo)
              (not (interaction-demo-enabled demo)))
        (interaction-demo--refresh demo)
        (interaction-demo--record
         demo (if (interaction-demo-enabled demo)
                  "Restored all four properties" "Removed all four properties")))
       ('palette
        (setf (interaction-demo-warm demo)
              (not (interaction-demo-warm demo)))
        (interaction-demo--refresh demo)
        (interaction-demo--record
         demo (if (interaction-demo-warm demo)
                  "Hover → warm palette" "Hover → cool palette")))
       ('reset
        (setf (interaction-demo-count demo) 0)
        (interaction-demo--show-count demo)
        (interaction-demo--record demo "Reset count"))
       ('group
        (dolist (node (ebox-selector-query-buffer (current-buffer) ".demo-status"))
          (interaction-demo--update
           node :content "READY" :color "#287A52"
           :help-echo "This status was updated with its class group."))
        (interaction-demo--record demo "Updated three .demo-status Boxes in one batch"))
       ('parent (interaction-demo--record demo "PARENT surface activated"))
       ('child (interaction-demo--record demo "CHILD text activated"))
       (_ (error "Unknown interaction-lab action: %S" action)))))))

(provide 'interaction-demo-reference)

;;; interaction-reference.el ends here
