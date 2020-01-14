#lang racket
(require db deta threading)

(define conn (sqlite3-connect	#:database "./recipes.db"))

(define-schema recipe
  ([Name string/f #:contract non-empty-string? #:wrapper string-titlecase]
   [Ingredients string/f]
   [Notes string/f]))

(create-table! conn 'recipe)


; (~> (from "recipe" #:as u) (order-by (["random()"])))




(provide
 conn
 recipe
 recipe-Name
 recipe-Ingredients

 recipe-Notes
 make-recipe)
