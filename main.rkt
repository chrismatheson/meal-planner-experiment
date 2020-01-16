#lang racket/gui
(require "recipe-list-control.rkt" "data.rkt" "planner-tab.rkt")

; Make a frame by instantiating the frame% class

(define frame (new frame%
                   [label "Open-Sauce"]
                   [width 1024]
                   [height 768]))

(define (show-tab panel event)
  (map
   (lambda (child) (send panel delete-child child))
   (send panel get-children))


  (match (send panel get-selection)
    [0 (recipe-tab panel conn)]
    [1 (planner-tab panel conn)]
    [2 void]))


(define tabs (new tab-panel%
                       (parent frame)
                       (choices (list "Recipes"
                                      "Planner"
                                      "Shop"
                                      "Admin/Guide/ToDo"))
                       [callback show-tab]))

(send frame show #t)

