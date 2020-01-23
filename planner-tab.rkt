#lang racket/gui
(require db deta threading gregor "data.rkt")

(provide planner-tab)

(define (planner-tab parent-tab conn)
  ;; (define (switch-meal Day)
  ;;   (define choice (in-entities conn
  ;;                               (~> (from recipe #:as u)
  ;;                                   (order-by ([(random)]))
  ;;                                   (limit 1))))
  ;;   (Day (sequence-ref choice 0)))

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

  (define Today    (recipe-summary-view parent-tab
                                        #:name "Today"))
  (define Tomorrow (recipe-summary-view parent-tab
                                        #:name "Tomorrow"))
  (define Today+2  (recipe-summary-view parent-tab
                                        #:name (~t (+days (today) 2) "EEEE")))
  (define Today+3  (recipe-summary-view parent-tab
                                        #:name (~t (+days (today) 3) "EEEE")))
  (controls parent-tab)


  (define (recipe-summary-view parent #:name name)
    (define/contract (self r)
      (-> recipe? any/c)
      (send text set-label (recipe-Name r)))
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
    (new button%
         [parent main]
         [label "switch"]
         [callback (lambda (btn ev) void)])
    (new button%
         [parent main]
         [label "pin"]
         [callback (lambda (btn ev) void)])
    self)
  void)

