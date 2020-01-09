#lang racket/gui
(require db deta threading "data.rkt")

(define (recipe-list-data conn)
  (for/list ([b (in-entities conn (~> (from recipe #:as b)))])
    b))

(define (recipe-tab tab-parent conn)
  (begin
    (define (open-recipe-item ls ev)
      (define r (send ls get-data (first (send ls get-selections))))
      (send title-field set-value (recipe-title r))
      (send ingerdiants-field set-value (recipe-ingrediants r))
      (send directions-field set-value (recipe-directions r))
    )
   

    (define panel (new horizontal-panel%
                       [parent tab-parent]))

    (define recipe-list (new list-box%
                             [parent panel]
                             [label false]
                             [choices (list)]
                             [callback open-recipe-item]))
    (map (lambda (item) (send recipe-list append (recipe-title item) item))
         (recipe-list-data conn))

    (define recipe-item (new vertical-panel% 
                             [parent panel]))

    (define title-field (new text-field%
                             [label "Title"]
                             [parent recipe-item]
                             [style (list 'multiple 'vertical-label)]))

    (define ingerdiants-field (new text-field%
                                   [label "Ingrediants"]
                                   [parent recipe-item]
                                   [min-height 100]
                                   [style (list 'multiple 'vertical-label)]))

    (define directions-field (new text-field%
                                  [label "Directions"]
                                  [parent recipe-item]
                                  [style (list 'multiple 'vertical-label)]
                                  [min-height 200]
                                  [stretchable-height true]))

    (define (get-new-recipe) (make-recipe #:title (send title-field get-value)
                                          #:ingrediants (send ingerdiants-field get-value)
                                          #:directions (send directions-field get-value)))

    (define save-btn (new button%
                          [parent recipe-item]
                          [label "save"]
                          [callback (lambda (btn ev)
                                      (define item (insert-one! conn (get-new-recipe)))
                                      (send recipe-list append  (recipe-title item) item))]))
    void))



(provide recipe-tab)
