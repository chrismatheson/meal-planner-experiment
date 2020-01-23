#lang racket
(require db deta threading gregor)

(define conn (sqlite3-connect	#:database "./recipes.db"))


(define-schema recipe
 ([Name string/f #:contract non-empty-string? #:wrapper string-titlecase]
  [Ingredients string/f]
  [Favorite boolean/f]
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
