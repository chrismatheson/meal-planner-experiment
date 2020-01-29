#lang racket
(require db deta threading gregor predicates)

(define conn (sqlite3-connect	#:database "./recipes.db"))

;https://datasetsearch.research.google.com/search?query=recipes&docid=p1MVBTA9E0I2UAn2AAAAAA%3D%3D
(define-schema recipe
  ([id id/f #:primary-key #:auto-increment]
   [Name string/f #:contract non-empty-string? #:wrapper string-titlecase]
   [Ingredients string/f]
   [Favorite? boolean/f  #:name "Favorite"]
   [Notes string/f]))

(define-schema meals
  ([id id/f #:primary-key #:auto-increment]
   [Name string/f #:contract non-empty-string?]
   [Time date/f]))

(create-table! conn 'recipe)
(create-table! conn 'meals)

;(insert-one! conn (make-meals #:Name "SpagBol" #:Time (today)))
; (~> (from "recipe" #:as u) (order-by (["random()"])))

(define (recipe-list-data conn [fav 0])
  (sequence->list (in-entities conn
                               (~> (from recipe #:as b)
                                   (where (= ,fav b.Favorite))
                                   ))))

(define (all-meals conn)
  (sequence->list (in-entities conn
                               (~> (from meals #:as meals))
                               )))

(define/contract (recipe-toggle-Favorite! conn selected)
  (-> connection? recipe? any)
  (print "hello")
  (define modified (update-recipe-Favorite? selected not))
  (print modified)
  (update-one! conn modified))

(define/contract (upsert-one! conn e)
  (-> connection? recipe? recipe?)
  (cond
    [(not-null? (recipe-id e)) (update-one! e)]
    [(null? (recipe-id e)) (insert-one! e)]))

(provide (schema-out recipe))
(provide
 conn
 all-meals
 recipe-list-data
 recipe-toggle-Favorite!)


(module+ test
  (require rackunit rackunit/text-ui rackunit/quickcheck quickcheck)

  (define (as-value e)
    (drop (vector->list (struct->vector e)) 2))

  (define test-conn (sqlite3-connect 	#:database 'memory 	#:mode 'create))
  (create-table! test-conn 'recipe)
  (create-table! test-conn 'meals)

  (define fake-recipe (make-recipe
                         #:Name "something else"
                         #:Favorite? false
                         #:Ingredients " "
                         #:Notes " "))

  (insert-one! test-conn (make-meals #:Name "SpagBol" #:Time (today)))


  (run-tests
   (test-suite
    "basic CRUD"
    (check-equal? (length (recipe-list-data test-conn)) 0)
    (check-equal? (length (all-meals test-conn)) 1)
    (check-equal?
     (as-value (insert-one! test-conn (make-meals #:Name "SpagBol" #:Time (today))))
     (as-value (make-meals #:id 2 #:Name "SpagBol" #:Time (today))))

    (check-equal? (length (all-meals test-conn)) 2)

    (around
     (begin
       (drop-table! test-conn 'recipe)
       (create-table! test-conn 'recipe)
       )
     (check-equal? (length (recipe-list-data test-conn)) 0)
     (check-not-false (insert-one! test-conn fake-recipe))
     (check-equal? (length (recipe-list-data test-conn)) 1
                   )
     (lambda () void))

    (check-property (property ([name (choose-string choose-ascii-char 20)])
                              (meals? (make-meals #:Name name #:Time (today)))))
    )
   )

  )


