#lang racket/base

(require "rsound.rkt"
         "util.rkt"
         racket/runtime-path
         (only-in racket/list first)
         (only-in racket/match match-define match))

(provide piano-tone)

(define-runtime-path piano-samples "piano-samples")

;; load the C4 and C5 samples

(define C3samp (rs-read (build-path piano-samples "Piano.c3.clipped.wav"))) ; 48
(define C4samp (rs-read (build-path piano-samples "Piano.c4.clipped.wav"))) ; 60
(define C5samp (rs-read (build-path piano-samples "Piano.c5.clipped.wav"))) ; 72
(define C6samp (rs-read (build-path piano-samples "Piano.c6.clipped.wav"))) ; 84

(define sample-table
  `((48 ,C3samp)
    (60 ,C4samp)
    (72 ,C5samp)
    (84 ,C6samp)))

;; find-nearest-sample : given a midi note number, find the 
;; note number and rsound of the sampled note with the
;; closest midi note number.
;; real -> (list/c real rsound)
;; NB: if this table were longer we might care about efficiency.
(define (find-nearest-sample nn)
  (for/fold ([nearest (first sample-table)])
    ([pr (in-list sample-table)])
    (cond [(< (abs (- (first pr) nn)) (abs (- (first nearest) nn)))
           pr]
          [else nearest])))

(module+ test
  (require rackunit)
  (check-equal? (find-nearest-sample 66.4) (list 72 C5samp)))

;; produce a (resampled) note of a given frequency
(define (resampled-piano f)
  (define desired-note-num (pitch->midi-note-num f))
  (match-define (list nn snd) (find-nearest-sample desired-note-num))
  (define best-pitch (midi-note-num->pitch nn))
  (resample/interp (/ f best-pitch) snd))

;; convert a list of lists of length 2 to a hash table
(define (assoc-list-to-hash l)
  (apply hasheq (apply append l)))


;; resample these to produce samples ... memoized.
(define resampled-piano-table (make-hasheq))
(define (resampled-piano/nn/memo nn)
  (match (hash-ref resampled-piano-table nn #f)
    [#f 
     (define new-sound (resampled-piano (midi-note-num->pitch nn)))
     (hash-set! resampled-piano-table nn new-sound)
     new-sound]
    [other
     other]))

(define (piano-tone nn)
  (resampled-piano/nn/memo nn))