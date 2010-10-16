#lang racket

(require rackunit
         "../private/portaudio.rkt")

;; 

(check-not-exn (lambda () (pa-get-version)))
(check-not-exn (lambda () (pa-get-version-text)))

;; this can change, as long as it's something sensible:
(check-equal? (pa-get-error-text 'paBufferTooBig) "Buffer too big")


;; almost everything untested.