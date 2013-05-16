#lang racket

(require (for-syntax syntax/parse)
         racket/stxparam)


(provide network
         prev
         signal?
         signal-*s
         signal-+s
         (struct-out network/s)
         (contract-out [network-init (-> network/c procedure?)])
         fixed-inputs
         loop-ctr
         simple-ctr
         signal-samples
         signal-nth
         tap)

;; this representation can in principle handle multiple-out networks,
;; but the surface syntax will get yucky. For now, let's just do one
;; output....

;; a network is either a function or (make-network number number procedure)

;; ins and outs not currently used, could be used for static checking...
;; or for better error messages, at any rate.

(struct network/s (ins outs maker))

(define network/c (or/c network/s? procedure?))

;; given a network/c, initialize it and return a thunk that 
;; produces samples
(define (network-init signal)
  (cond [(network/s? signal) ((network/s-maker signal))]
        [(procedure? signal) signal]
        [else (raise-argument-error
               'signal-init
               "network or procedure" signal)]))


;; maker: (-> (arg ... -> result ...))

(define-syntax-parameter prev (lambda (stx)
                                #'(error "can't use prev outside of a network definition")))

;; this is the cleaned-up version. It insists on having a sequence of ids for the out-names
(define-syntax (network/inr stx)
  (define-syntax-class network-clause
    #:description "network/inr clause"
    (pattern ((out:id ...) (node:expr input:expr ...))))
  (syntax-parse stx
    [(_ (in:id ...)
        clause:network-clause ...+)
     (define num-ins (length (syntax->list #'(in ...))))
     (define lhses (syntax->list #'((clause.out ...) ...)))
     (define num-outs (length (syntax->list (car (reverse lhses)))))
     (define lhses/flattened (syntax->list #'(clause.out ... ...)))
     (with-syntax
         ([(saved-val ...) (generate-temporaries lhses/flattened)]
          [(signal-proc ...) (generate-temporaries #'(clause ...))]
          [(lhs ...) lhses/flattened]
          [last-out
           (syntax-parse (car (reverse lhses))
             [(out:id) #'out]
             [(out:id out2:id ...+) #'(values out out2 ...)])])
       (with-syntax 
           (;; this one just reduces to the init:
            [init-prev
             #`(lambda (stx)
                 (syntax-parse stx
                   #:literals (prev)
                   [(_ id init) #'init]))]
            ;; this one does a lookup:
            ;; NB: TOTALLY SCARY MACRO STUFF HERE: this is 
            ;; expanding into a macro definition. The macro
            ;; definition that goes into the code doesn't
            ;; have any dots in it.
            [lookup-prev
             #'(lambda (stx)
                 (syntax-case stx (lhs ...)
                   [(_ lhs init) #'saved-val] 
                   ...))]
            ;; the body of the function is the same for each one,
            ;; just nested inside a different syntax-parameterize
            [fun-body
             #`(let*-values ([(clause.out ...) (signal-proc 
                                                clause.input ...)]
                             ...)
                 (begin
                   (set! saved-val lhs)
                   ...)
                 last-out)])
         (with-syntax
             ([maker
               #`(lambda ()
                   (define saved-val #f)
                   ...
                   (define signal-proc (network-init clause.node))
                   ...
                   ;; this one should be used only after the saved-vals
                   ;; are initialized
                   (define (later-times-fun in ...)
                     ;; in this one, "prev" should do a lookup
                     (syntax-parameterize
                      ([prev lookup-prev])
                      fun-body))
                   (define (first-time-fun in ...)
                     ;; mutate myself into the later-times-fun...
                     (set! first-time-fun later-times-fun)
                     ;; in this one, "prev" should just insert the init vals
                     (syntax-parameterize
                      ([prev init-prev])
                      fun-body))
                   (lambda (in ...)
                     (first-time-fun in ...)))])
           #`(network/s (quote #,num-ins) 
                        (quote #,num-outs)
                        maker))))]))

(define-syntax (network stx)
  (define-syntax-class oneormoreids
    #:description "id or (id ...)"
    (pattern out:id)
    (pattern (outs:id ...)))
  (define-syntax-class rhs
    #:description "network clause rhs"
    #:literals (prev)
    (pattern (prev named:id init:expr))
    (pattern (node:expr input:expr ...))
    (pattern input:expr))
  (define-syntax-class network-clause
    #:description "network clause"
    #:literals (prev)
    (pattern (outs:oneormoreids rhs:rhs)))
  ;; right here: split rewrite into two functions!
  (define (ensure-parens ids)
    (syntax-parse ids
      [out:id #'(out)]
      [(outs:id ...) #'(outs ...)]))
  ;; stick the identity function in to avoid disrupting certain forms:
  (define (maybe-wrap rhs)
    (syntax-parse rhs
      #:literals (prev)
      [(prev named:id init:expr) #'((lambda (x) x) (prev named init))]
      [(node:expr input:expr ...) #'(node input ...)]
      [node:expr #'((lambda (x) x) node)]))
  (define (rewrite clause)
    (syntax-parse clause
      [(out1a:id  (node:expr input:expr ...))
       #'((out1a) (node input ...))]
      [(out1b:id  node:expr)
       #'((out1b) ((lambda (x) x) node))]
      [((out*a:id ...) (node:expr input:expr ...))
       #'((out*a ...) (node input ...))]))
  (syntax-parse stx
    [(_ (in:id ...)
        clause:network-clause ...+)
     (with-syntax ([((outs ...) ...)
                    (map ensure-parens (syntax->list #'(clause.outs ...)))]
                   [(rhs ...)
                    (map maybe-wrap (syntax->list #'(clause.rhs ...)))])
       #'(network/inr (in ...)
                      [(outs ...) rhs] ...))])
  )


;; a signal is a network with no inputs.
(define (signal? f)
  (or (and (network/s? f) (= (network/s-ins f) 0))
      (and (procedure? f) (procedure-arity-includes? f 0))))

;; take a network with inputs and a set of fixed 
;; inputs and return a new signal closed over those inputs
(define-syntax (fixed-inputs stx)
  (syntax-parse stx
    [(_ net arg ...)
     #'(network () [out (net arg ...)])]))

;; multiply the signals together:
(define (signal-*s los)
  (unless (andmap signal? los)
    (raise-argument-error 'signal-*s "list of signals" 0 los))
  (network/s 0 1 (lambda ()
                   (define sigfuns (map network-init los))
                   (lambda ()
                     (for/product ([fun sigfuns]) (fun))))))

;; add the signals together:
(define (signal-+s los)
  (unless (andmap signal? los)
    (raise-argument-error 'signal-*s "list of signals" 0 los))
  (network/s 0 1 (lambda ()
                   (define sigfuns (map network-init los))
                   (lambda ()
                     (for/sum ([fun sigfuns]) (fun))))))

;; a simple signal that starts at 0 and increments by "skip"
;; until it passes "len", then jumps back to 0
(define (loop-ctr len skip)
  (define (increment p)
    (define next-p (+ p skip))
    (cond [(< next-p len) next-p]
          [else (- next-p len)]))
  (network ()
           [a (prev b 0)]
           [b (increment a)]
           [out a]))

;; a signal that simply starts at "init"  and adds "skip"
;; each time
(define (simple-ctr init skip)
  (network ()
           [a (prev b init)]
           [b (+ skip a)]
           [out a]))


;; a vector containing the first 'n' samples of a signal
(define (signal-samples signal n)
  (define sigfun (network-init signal))
  (for/vector ([i n]) (sigfun)))

;; determine the nth sample, by discarding the first n-1:
(define (signal-nth signal n)
  (define sigfun (network-init signal))
  (for ([i n]) (sigfun))
  (sigfun))

;; create a tap of the given length (we could generalize
;; this to allow multiple tap lengths from one vector.)
;; for now, it assumes real-valued inputs, and pre-fills
;; the vector with zeros.
;; nat -> network
(define (tap len init-val)
  (define the-proc
    (lambda ()
      (define tap-vec (make-vector len init-val))
      (define idx 0)
      (lambda (new-val)
        (begin0 (vector-ref tap-vec idx)
                (vector-set! tap-vec idx new-val)
                (let ()
                  (define next-idx (add1 idx))
                  (set! idx (cond [(< next-idx len) next-idx]
                                  [else 0])))))))
  (network/s 1 1 the-proc))

