#lang racket/gui
(require db deta threading gregor "data.rkt")

(provide planner-tab)

(define (planner-tab parent-tab conn)

  (define (shuffle-planner btn ev)
    (define choice (in-entities conn
                                (~> (from recipe #:as u)
                                    (order-by ([(random)]))
                                    (limit 4))))
    (Today (sequence-ref choice 0))
    (Tomorrow (sequence-ref choice 1))
    (Today+2 (sequence-ref choice 2))
    (Today+3 (sequence-ref choice 3)))

  (define (controls parent)
    (define control-container (new horizontal-panel%
                                   [parent parent]))
    (new button%
         [label "Shuffle"]
         [parent control-container]
         [callback shuffle-planner])
    (new button%
         [parent control-container]
         [label "save"]))

  (define Today (recipe-summary-view parent-tab "Today"))
  (define Tomorrow (recipe-summary-view parent-tab "Tomorrow"))
  (define Today+2 (recipe-summary-view parent-tab (~t (+days (today) 2) "EEEE")))
  (define Today+3 (recipe-summary-view parent-tab (~t (+days (today) 3) "EEEE")))
  (controls parent-tab)
)


(define (recipe-summary-view parent name)
  (define main (new horizontal-panel%
                    [parent (new group-box-panel%
                                 [parent parent]
                                 [label name])]))

  (define image (new panel%
                     [parent main]
                     [min-height 100]
                     [min-width 100]
                     [stretchable-width false]
                     [stretchable-height false]
                     [style (list 'border)]))
  (send image accept-drop-files true)

  (define dwane (make-object bitmap% (string->path "/Users/chrismatheson/Downloads/dwayne1.jpg")))

  (new message%
       [parent image]
       [label "<add photo>"])

  (define text (new message%
                 [parent main]
                 [label "..."]
                 [stretchable-width false]

                 [auto-resize true]))
  (lambda (r)
    (send text set-label (recipe-Name r))))

