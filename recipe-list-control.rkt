#lang racket/gui
(require db deta threading "data.rkt")

(define/contract (insert-new-recipe! conn new-recipe)
  (-> connection? recipe? recipe?)
  (insert-one! conn new-recipe))

(define search-box%
  (class text-field%
    (super-new)
    (init [on-search (lambda () void)])
    (define/override (on-subwindow-char win char)
      ;;(when (eq? #\return (send char get-key-code))
      ;;  ((get-on-search this) (send this get-value)))
      (super on-subwindow-char win char))))

(define recipe-editor%
  (class vertical-panel%
    (super-new)
    (define/public (set-value val)
      (send title-field set-value (recipe-Name val))
      (send ingerdients-field set-value (recipe-Ingredients val))
      (send directions-field set-value (recipe-Notes val)))
    (define title-field (new text-field%
                             [label "Title"]
                             [parent this]
                             [style (list 'multiple 'vertical-label)]))
    (define ingerdients-field (new text-field%
                                   [label "Ingredients"]
                                   [parent this]
                                   [min-height 100]
                                   [style (list 'multiple 'vertical-label)]))

    (define directions-field (new text-field%
                                  [label "Directions"]
                                  [parent this]
                                  [style (list 'multiple 'vertical-label)]
                                  [min-height 200]
                                  [stretchable-height true]))
    (define/public (get-new-recipe) (make-recipe #:Name (send title-field get-value)
                                          #:Ingredients (send ingerdients-field get-value)
                                          #:Notes (send directions-field get-value)
                                          #:Favorite? false))
    ))

(define (recipe-tab tab-parent conn)
  (begin
    (define (current-recipe ls)
      (send ls get-data (first (send ls get-selections))))

    (define (open-recipe-item ls ev)
      (send recipe-item set-value (current-recipe ls)))

    (define (all-recipes) (recipe-list-data conn 0))
    (define (fav-recipes) (recipe-list-data conn 1))

    (define search (new search-box%
                        [label false]
                        [init-value "[fav]"]
                        [parent tab-parent]
                        [on-search (lambda (str) (print str))]))

    (define switches (new horizontal-panel%
                          [parent tab-parent]
                          [stretchable-height false]))
    (new button%
         [parent switches]
         [label "all"]
         [callback (λ (target event)
                     (refresh-lists all-recipes))])

    (new button%
         [parent switches]
         [label "fav"]
         [callback (λ (target event)
                     (refresh-lists fav-recipes))])

    (new button%
         [parent switches]
         [label "veg"]
         [callback (λ (target event)
                     (refresh-lists fav-recipes))])

    (define panel (new horizontal-panel%
                       [parent tab-parent]))

    (define recipe-list (new list-box%
                             [parent panel]
                             [label false]
                             [choices (list)]
                             [callback open-recipe-item]))

    (define (refresh-lists data)
      (send recipe-list clear)
      (map (lambda (item) (send recipe-list append (recipe-Name item) item))
           (data)))

    (refresh-lists all-recipes)

    ;RECIPE-ITEM

    (define recipe-item (new recipe-editor% 
                             [parent panel]))

    (define save-btn (new button%
                          [parent recipe-item]
                          [label "save"]
                          [callback (lambda (btn ev)
                                      (define item (insert-new-recipe! conn (send recipe-item get-new-recipe)))
                                      (refresh-lists conn))]))
    (define fav-btn (new button%
                         [parent recipe-item]
                         [label "fav"]
                         [callback (lambda (btn ev)
                                     (recipe-toggle-Favorite! conn (current-recipe recipe-list))
                                     ;;(refresh-lists conn)
                                     void)]))
    void))



(provide recipe-tab)
