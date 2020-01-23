#lang racket/gui
(require db deta threading "data.rkt")

(define (recipe-list-data conn)
  (for/list ([b (in-entities conn (~> (from recipe #:as b)))])
    b))

(define (recipe-tab tab-parent conn)
  (begin
    (define (open-recipe-item ls ev)
      (define r (send ls get-data (first (send ls get-selections))))
      (send title-field set-value (recipe-Name r))
      (send ingerdients-field set-value (recipe-Ingredients r))
      (send directions-field set-value (recipe-Notes r))
      )

    (define search (new text-field%
                        [label false]
                        [parent tab-parent]))

    (define panel (new horizontal-panel%
                       [parent tab-parent]))

    (define recipe-list (new list-box%
                             [parent panel]
                             [label false]
                             [choices (list)]
                             [callback open-recipe-item]))
    (map (lambda (item) (send recipe-list append (recipe-Name item) item))
         (recipe-list-data conn))

    (define recipe-item (new vertical-panel% 
                             [parent panel]))

    (define title-field (new text-field%
                             [label "Title"]
                             [parent recipe-item]
                             [style (list 'multiple 'vertical-label)]))

    (define ingerdients-field (new text-field%
                                   [label "Ingredients"]
                                   [parent recipe-item]
                                   [min-height 100]
                                   [style (list 'multiple 'vertical-label)]))

    (define directions-field (new text-field%
                                  [label "Directions"]
                                  [parent recipe-item]
                                  [style (list 'multiple 'vertical-label)]
                                  [min-height 200]
                                  [stretchable-height true]))

    (define (get-new-recipe) (make-recipe #:Name (send title-field get-value)
                                          #:Ingredients (send ingerdients-field get-value)
                                          #:Notes (send directions-field get-value)
                                          #:Favorite false))

    (define save-btn (new button%
                          [parent recipe-item]
                          [label "save"]
                          [callback (lambda (btn ev)
                                      (define item (insert-one! conn (get-new-recipe)))
                                      (send recipe-list append  (recipe-Name item) item))]))
    (define fav-btn (new button%
                         [parent recipe-item]
                         [label "fav"]
                         [callback (lambda (btn ev) void)]))
    void))



(provide recipe-tab)
