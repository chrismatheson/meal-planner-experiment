#lang racket
(require db deta threading)

(define conn (sqlite3-connect 	#:database 'memory))

(define-schema recipe
  ([id id/f #:primary-key #:auto-increment]
   [title string/f #:contract non-empty-string? #:wrapper string-titlecase]
   [ingrediants string/f]
   [directions string/f]))

(create-table! conn 'recipe)

(void
 (insert! conn
          (make-recipe #:title "Hot Dog, Macn & cheese"
                     #:ingrediants ""
                     #:directions "")
          (make-recipe #:title "Banger and Mash"
                     #:ingrediants ""
                     #:directions "")
          (make-recipe #:title "Peking Duck"
                     #:ingrediants ""
                     #:directions "")))

(provide
 conn
 recipe
 recipe-title
 recipe-ingrediants
 recipe-directions
 make-recipe)
