#lang racket
(require db deta threading gregor)

(define conn (sqlite3-connect	#:database "./recipes.db"))

;https://datasetsearch.research.google.com/search?query=recipes&docid=p1MVBTA9E0I2UAn2AAAAAA%3D%3D
(define-schema recipe
  ([Name string/f #:primary-key #:contract non-empty-string? #:wrapper string-titlecase]
  [Ingredients string/f]
  [Favorite? boolean/f  #:name "Favorite"]
  [Notes string/f]))

(define-schema meals
  ([Name string/f #:contract non-empty-string?]
   [Time date/f]))

(create-table! conn 'recipe)
(create-table! conn 'meals)

;(insert-one! conn (make-meals #:Name "SpagBol" #:Time (today)))

; (~> (from "recipe" #:as u) (order-by (["random()"])))


(provide (schema-out recipe))
(provide conn)
