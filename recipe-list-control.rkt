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
      (when (eq? #\return (send char get-key-code))
        ((get-on-search this) (send this get-value)))
      (super on-subwindow-char win char))))

(define (recipe-tab tab-parent conn)
  (begin
    (define (current-recipe ls)
      (send ls get-data (first (send ls get-selections))))

    (define (open-recipe-item ls ev)
      (define r (current-recipe ls))
      (send title-field set-value (recipe-Name r))
      (send ingerdients-field set-value (recipe-Ingredients r))
      (send directions-field set-value (recipe-Notes r))
      )

    (define search (new search-box%
                        [label false]
                        [init-value "[fav]"]
                        [parent tab-parent]
                        [on-search (lambda (str) (print str))]))

    (define panel (new horizontal-panel%
                       [parent tab-parent]))

    (define recipe-list (new list-box%
                             [parent panel]
                             [label false]
                             [choices (list)]
                             [callback open-recipe-item]))

    (define fav-recipe-list (new list-box%
                             [parent panel]
                             [label false]
                             [choices (list)]
                             [callback open-recipe-item]))

    (define (refresh-lists conn)
      (send recipe-list clear)
      (send fav-recipe-list clear)
      (map (lambda (item) (send recipe-list append (recipe-Name item) item))
           (recipe-list-data conn 0))
      (map (lambda (item) (send fav-recipe-list append (recipe-Name item) item))
           (recipe-list-data conn 1)))

    (refresh-lists conn)

    ;RECIPE-ITEM

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
                                          #:Favorite? false))

    (define save-btn (new button%
                          [parent recipe-item]
                          [label "save"]
                          [callback (lambda (btn ev)
                                      (define item (insert-new-recipe! conn (get-new-recipe)))
                                      (refresh-lists conn))]))
    (define fav-btn (new button%
                         [parent recipe-item]
                         [label "fav"]
                         [callback (lambda (btn ev)
                                     (recipe-toggle-Favorite! conn (current-recipe recipe-list))
                                     (refresh-lists conn)
                                     void)]))
    void))



(provide recipe-tab)
