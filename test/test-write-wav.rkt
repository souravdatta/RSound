#lang racket

(require "../rsound.rkt"
         "../util.rkt"
         "../write-wav.rkt"
         "../read-wav.rkt"
         rackunit)

(define sound-len 32114)
(define test-samplerate 30022)
(define r (make-tone 882 0.20 sound-len test-samplerate))

(check-equal? (rsound-nth-sample/left r 0) 0)
(check-= (rsound-nth-sample/left r 27) (round (* 0.2 s16max (sin (* twopi 882 (/ 27 test-samplerate))))) 0.0)
(check-= (rsound-nth-sample/right r 27) (round (* 0.2 s16max (sin (* twopi 882 (/ 27 test-samplerate))))) 0.0)

(define temp-filename (make-temporary-file))
(write-sound/s16vector (rsound-data r) (rsound-sample-rate r) (path->string temp-filename))

(check-equal? (rsound-read-frames temp-filename) sound-len)
(check-equal? (rsound-read-sample-rate temp-filename) test-samplerate)

(define s (apply rsound (read-sound/s16vector (path->string temp-filename) 0 #f)))

(check-true
 (for/and ([i (in-range sound-len)])
   (and (= (rsound-nth-sample/left r i) (rsound-nth-sample/left s i))
        (= (rsound-nth-sample/right r i) (rsound-nth-sample/right s i)))))

