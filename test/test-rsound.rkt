#lang racket

(require "../rsound.rkt"
         rackunit
         racket/runtime-path)

;;; HELPERS FOR TEST CASES


(define twopi (* 2 pi))
(define s16max #x7fff)

(define (sine-wave pitch sample-rate volume)
  (let ([scalar (* twopi pitch)])
    (lambda (i)
      (let ([t (/ i sample-rate)])
        (* volume (sin (* scalar t)))))))

;; make a monaural pitch with the given number of frames
(define (make-tone pitch volume frames sample-rate)
  (fun->mono-rsound frames sample-rate (sine-wave pitch sample-rate volume)))
;;; TEST CASES

(let ([t (fun->mono-rsound 100 44100 (lambda (i) (sin (* twopi 13/44100 i))))])
  (check-= (rsound-nth-sample/left t 0) 0 1e-4)
  (check-= (rsound-nth-sample/right t 1) (round (* s16max (sin (* twopi 13/44100)))) 1e-4))

;; test rsound-ith/left & right
(let ([t (fun->mono-rsound 100 44100 (lambda (i) (sin (* twopi 13/44100 i))))])
  (check-= (rsound-ith/left t 0) 0 1e-4)
  (check-= (rsound-ith/right t 1) (sin (* twopi 13/44100)) 1e-4))

;; tests of make-silence
#;(let ([sample-silence (make-silence )]))

;; tests of rsound-largest-sample
(let ([sample-sound (make-tone 2000 0.15 10 44100)])
  (check-= (/ (rsound-largest-sample sample-sound) s16max) 0.15 1))

;; tests of check-below-threshold:
#;(let ([sample-sound (rsound-append* (list (make-silence 10 44100) 
                                          (make-tone 2000 0.15 10 44100)))])
  (check-not-exn (lambda () (check-below-threshold (rsound-data sample-sound) (rsound-frames sample-sound) 0.15)))
  (check-exn exn:fail? (lambda () (check-below-threshold (rsound-data sample-sound) (rsound-frames sample-sound) 0.1))))

;; how long does it take to scan a minute of sound for loud things?
#;(let ([sample-sound (make-tone 400 0.15 (* 60 44100) 44100)])
  (time (check-below-threshold sample-sound 0.2)))

;; make-silence:
(let ([s (make-silence 100 44100)])
  (for ([i (in-range 100)])
    (check-equal? (rsound-nth-sample/left s i) 0)
    (check-equal? (rsound-nth-sample/right s i) 0)))
(check-equal? (rsound-frames (make-silence 22050 44100)) 22050)
(check-equal? (rsound-sample-rate (make-silence 22050 44100)) 44100)

;; sound-list-total-frames:
(check-equal? (sound-list-total-frames (list (list (make-silence 22050 44100) 0))) 22050)
(check-equal? (sound-list-total-frames (list (list (make-silence 22050 44100) 0)
                                             (list (make-silence 44100 44100) 22050)
                                             (list (make-silence 20000 44100) 44100)))
              66150)

;; different sample rates:
(check-exn exn:fail? (lambda () (same-sample-rate-check (list (make-silence 10 22050) 
                                                              (make-silence 20 44100)))))
(check-exn exn:fail? (lambda () (same-sample-rate-check (list ))))
(check-not-exn       (lambda () (same-sample-rate-check (list (make-silence 10 22050) 
                                                              (make-silence 20 22050)))))


;; rsound-overlay*
(let* ([sample-sound (make-tone 400 0.15 6 44100)]
       [overlaid (rsound-overlay* (list (list sample-sound 0) (list sample-sound 0)))]
       [doublevol (make-tone 400 0.3 6 44100)])
  (for ([i (in-range 6)])
    (check-= (rsound-nth-sample/left overlaid i) (rsound-nth-sample/left doublevol i) 1.0)
    (check-= (rsound-nth-sample overlaid i) (rsound-nth-sample doublevol i) 2.0)))

(check-exn exn:fail? 
           (lambda ()
             (rsound-overlay* (list (list (make-tone 400 0.15 3 44100) 0)
                                    (list (make-tone 400 0.15 3 44100) 34/5)))))

;; rsound-read

;; tests copied from read-wav; these call the rsound-read funs directly:

(define-runtime-path short-test-wav "./short-test.wav")
(define test-rsound (rsound-read short-test-wav))

(define (desired-nth-sample n)
  (round (* #x8000 (sin (* 2 pi (/ n 44100) 700)))))
;; truncation due to 16-bit PCM rounding:
(define first-sample (desired-nth-sample 1))
(define second-sample (desired-nth-sample 2))
(define thirtieth-sample (desired-nth-sample 30))
(define fiftieth-sample (desired-nth-sample 50))

(check-= (rsound-nth-sample/left test-rsound 0) 0.0 1e-4)
(check-= (rsound-nth-sample/left test-rsound 1) first-sample 1e-4)
(check-= (rsound-nth-sample/right test-rsound 2) second-sample 1e-4)
;; why is this one not exact? Something to do with negative numbers... still can't quite figure it out.
(check-= (rsound-nth-sample/right test-rsound 50) fiftieth-sample 1)


(define test-sub-rsound (rsound-read/clip short-test-wav 30 40))

(check-equal? (rsound-frames test-sub-rsound) 10)
(check-= (rsound-nth-sample/left test-sub-rsound 0) (desired-nth-sample 30) 1e-4)
(check-= (rsound-nth-sample/right test-sub-rsound 1) (desired-nth-sample 31) 1e-4)

(define-runtime-path kick-wav "./kick_01.wav")

(define kick-rsound (rsound-read kick-wav))

;; purely regression testing:
(check-equal? (rsound-frames kick-rsound) 4410)
(check-equal? (rsound-nth-sample/left kick-rsound 1803) 27532)
(check-equal? (rsound-nth-sample/right kick-rsound 1803) 27532)

;; test with PAD

(define-runtime-path short-with-pad-wav "./short-with-pad.wav")
(define short-with-pad (rsound-read short-with-pad-wav))
(check-equal? (rsound-frames short-with-pad) #x21)
(check-equal? (rsound-nth-sample/left short-with-pad 5) #x892)
(check-equal? (rsound-nth-sample/right short-with-pad 6) #x478)


;; clipping isn't happening right.

(check-= (/ (rsound-nth-sample/left (fun->mono-rsound 300 44100
                                                      (lambda (i) (* 1.5 (sin (* twopi 147/44100 i)))))
                                    73)
            #x7fff)
         1.0
         1e-4)


#|(time (rsound-draw (make-tone 400 0.15 10 44100) 400 100))
(time (rsound-draw (make-tone 400 0.15 100 44100) 400 100))
(time (rsound-draw (make-tone 400 0.15 1000 44100) 400 100))
(time (rsound-draw (rsound-overlay* (list (list (make-tone 400 0.15 1000 44100) 0)
                                          (list (make-tone 404 0.15 1000 44100) 0))) 400 100))

|#