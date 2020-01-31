#lang racket
(require megaparsack megaparsack/text data/monad data/applicative)

(define word/p
  (many+/p letter/p))

(define tag/p
  (do (char/p #\[)
      [tag <- word/p]
      (char/p #\])
      (pure (string->symbol (apply string tag)))))


(define (parse-search-string str)
  (parse-result!
   (parse-string
    (many/p (or/p word/p
                  tag/p)
            #:sep space/p)
    str)))

(provide parse-search-string)

(parse-search-string "[fav] [thing]")


(module+ test
  (require rackunit rackunit/text-ui rackunit/quickcheck quickcheck)

  (run-tests
   (test-suite
    "parse search string into tags"
    (check-equal? (parse-search-string "[fav] [thing]") '(fav thing))
    )))
