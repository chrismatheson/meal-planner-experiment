#lang racket
(require db deta threading gregor predicates
         (prefix-in h: html)
         html-parsing
         xml/path
         net/url
         json)

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

(define null-recipe (make-recipe #:Name " "
                                 #:Ingredients ""
                                 #:Notes ""
                                 #:Favorite? false))



(define/contract (import-recipe url)
  (-> url? recipe?)
  ;(define page-content (get-pure-port url))
  (define schema-org-recipe (string->jsexpr "{\"@context\":\"https://schema.org\",\"@type\":\"Recipe\",\"aggregateRating\":{\"ratingCount\":3,\"ratingValue\":5},\"author\":{\"@type\":\"Person\",\"name\":\"Angela Hartnett\"},\"cookTime\":\"PT30M\",\"description\":\"A classic recipe done to perfection: spinach pasta filled with lemony ricotta and topped with a hazelnut pesto. It takes time, but the only tricky element is making sure the tortellini is properly shaped and sealed.\\r\\n\\r\\nFor this recipe you will need a pasta machine and a 9cm/3½in round cutter.\",\"image\":[\"https://food-images.files.bbci.co.uk/food/recipes/spinach_and_ricotta_93886_16x9.jpg\"],\"keywords\":\"quick, instagram, spring recipes , tortellini, 00 flour, pregnancy friendly, vegetarian, Best Home Cook\",\"name\":\"Spinach and ricotta tortellini\",\"prepTime\":\"PT30M\",\"recipeCategory\":\"Main course\",\"recipeCuisine\":\"Italian\",\"recipeIngredient\":[\"70g/2½oz spinach\",\"4 large free-range egg yolks\",\"200g/7oz ‘00’ flour, plus extra for dusting\",\"25g/1oz whole blanched hazelnuts\",\"15g/½oz Parmesan (or a similar vegetarian hard cheese), grated\",\"1 tbsp hazelnut oil\",\"1 tbsp grapeseed oil\",\"150g/5½oz ricotta\",\"50g/1¾oz Parmesan (or a similar vegetarian hard cheese), grated\",\"1 lemon, zest only\",\"pinch grated nutmeg\",\"salt and freshly ground pepper\",\"knob of butter, to serve\"],\"recipeInstructions\":[\"Preheat the oven to 180C/160C Fan/Gas 4.\",\"Put the spinach and egg yolks in a food processor and process until smooth. Add the flour and whizz again to combine – the mixture will look like breadcrumbs at this stage. Tip out onto a lightly floured board and bring together using your hands. Knead the dough until it’s no longer sticky. Cover and rest in the fridge while you make the filling and pesto.\",\"For the pesto, spread the hazelnuts on a baking tray and toast in the oven for 6–8 minutes, until golden brown, then set aside to cool.\",\"For the filling, mix the ricotta, Parmesan, lemon zest, nutmeg and a pinch of salt and pepper until well combined. Transfer to a piping bag or a plastic food bag with the corner snipped off.\",\"To make the pesto, crush the hazelnuts in a pestle and mortar, then gently stir in the Parmesan and oils.\",\"To assemble the tortellini, roll the pasta dough through all the sizes on the pasta machine starting with the widest setting and finishing on the smallest setting when the pasta is very thin. Using a 9cm/3½in round cutter, cut out 10 circles. (Any leftover dough can be frozen to use another time.)\",\"Pipe a heaped teaspoon amount of filling inside each pasta circle and fold in half to create a half moon shape. Wet the edges and press down to help them stick. Pull the two narrow ends together to form a tortellini shape.  \",\"Bring a large saucepan of salted water to the boil. Cook the pasta in the boiling water for 2–3 minutes, or until al dente. Drain well. \",\"Meanwhile, put a frying pan over a medium–high heat and add a knob of butter. Cook until lightly browned and starting to bubble. Then add the hazelnut pesto and gently heat through. \",\"Serve the tortellini with the pesto spooned over the top.\"],\"recipeYield\":\"Serves 2\",\"suitableForDiet\":[\"http://schema.org/VegetarianDiet\"]}"))

  (print (hash-keys-subset? (hasheq '@type "Recipe") schema-org-recipe))
  (make-recipe #:Name (hash-ref schema-org-recipe 'name)
               #:Ingredients (apply string-append (hash-ref schema-org-recipe 'recipeIngredient))
               #:Favorite? false
               #:Notes (apply string-append (hash-ref schema-org-recipe 'recipeInstructions))))

(provide (schema-out recipe))
(provide
 conn
 all-meals
 null-recipe
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

  (define spinich-and-ricotta-tortalini-url (string->url "https://www.bbc.co.uk/food/recipes/spinach_and_ricotta_93886"))
  ;(define blah (se-path*/list '(script)  (html->xexp (get-pure-port spinich-and-ricotta-tortalini-url))))

  (run-tests
   (test-suite "data"
               (test-suite
                "basic CRUD"
                (check-equal? (length (recipe-list-data test-conn)) 0)
                (check-equal? (length (all-meals test-conn)) 1)
                (check-equal?
                 (as-value (insert-one! test-conn (make-meals #:Name "SpagBol" #:Time (today))))
                 (as-value (make-meals #:id 2 #:Name "SpagBol" #:Time (today))))

                (check-equal? (length (all-meals test-conn)) 2)

                (test-suite
                 "recipe"
                 #:before (begin
                            (drop-table! test-conn 'recipe)
                            (create-table! test-conn 'recipe))
                 (check-equal? (length (recipe-list-data test-conn)) 0)
                 (check-not-false (insert-one! test-conn fake-recipe))
                 (check-equal? (length (recipe-list-data test-conn)) 1))

                (check-property (property ([name (choose-string choose-ascii-char 20)])
                                          (meals? (make-meals #:Name name #:Time (today)))))
                )
               (test-suite
                "importing"
                (check-equal?
                 (as-value (make-recipe
                            #:Name "Spinach and ricotta tortellini"
                            #:Favorite? false
                            #:Ingredients "70g/2½oz spinach4 large free-range egg yolks200g/7oz ‘00’ flour, plus extra for dusting25g/1oz whole blanched hazelnuts15g/½oz Parmesan (or a similar vegetarian hard cheese), grated1 tbsp hazelnut oil1 tbsp grapeseed oil150g/5½oz ricotta50g/1¾oz Parmesan (or a similar vegetarian hard cheese), grated1 lemon, zest onlypinch grated nutmegsalt and freshly ground pepperknob of butter, to serve"
                            #:Notes "Preheat the oven to 180C/160C Fan/Gas 4.Put the spinach and egg yolks in a food processor and process until smooth. Add the flour and whizz again to combine – the mixture will look like breadcrumbs at this stage. Tip out onto a lightly floured board and bring together using your hands. Knead the dough until it’s no longer sticky. Cover and rest in the fridge while you make the filling and pesto.For the pesto, spread the hazelnuts on a baking tray and toast in the oven for 6–8 minutes, until golden brown, then set aside to cool.For the filling, mix the ricotta, Parmesan, lemon zest, nutmeg and a pinch of salt and pepper until well combined. Transfer to a piping bag or a plastic food bag with the corner snipped off.To make the pesto, crush the hazelnuts in a pestle and mortar, then gently stir in the Parmesan and oils.To assemble the tortellini, roll the pasta dough through all the sizes on the pasta machine starting with the widest setting and finishing on the smallest setting when the pasta is very thin. Using a 9cm/3½in round cutter, cut out 10 circles. (Any leftover dough can be frozen to use another time.)Pipe a heaped teaspoon amount of filling inside each pasta circle and fold in half to create a half moon shape. Wet the edges and press down to help them stick. Pull the two narrow ends together to form a tortellini shape.  Bring a large saucepan of salted water to the boil. Cook the pasta in the boiling water for 2–3 minutes, or until al dente. Drain well. Meanwhile, put a frying pan over a medium–high heat and add a knob of butter. Cook until lightly browned and starting to bubble. Then add the hazelnut pesto and gently heat through. Serve the tortellini with the pesto spooned over the top."))
                    (as-value (import-recipe spinich-and-ricotta-tortalini-url))))
               )))


