#lang racket 

(require "../rsound.rkt"
         "../util.rkt"
         rackunit)


(define r (make-tone 882 0.2 44100 44100))

(check-equal? (rsound-nth-sample/left r 0) 0)
(check-equal? (rsound-nth-sample/right r 50) 0)
(check-= (rsound-nth-sample/left r 27) (round (* s16max (* 0.2 (sin (* twopi 882 27/44100))))) 0.0)

;; table-based-sine-wave

(check-= ((raw-sine-wave 4 44100) 13) (sin (* 2 pi 13/44100 4)) 1e-4)

(check-= ((raw-square-wave 2 500) 0) 1.0 1e-4)
(check-= ((raw-square-wave 2 500) 10) 1.0 1e-4)
(check-= ((raw-square-wave 2 500) 124) 1.0 1e-4)
(check-= ((raw-square-wave 2 500) 125) -1.0 1e-4)
(check-= ((raw-square-wave 2 500) 249) -1.0 1e-4)
(check-= ((raw-square-wave 2 500) 250)  1.0 1e-4)
(check-= ((raw-square-wave 3 500) 166) -1.0 1e-4)
(check-= ((raw-square-wave 3 500) 167)  1.0 1e-4)



;; vectors->rsound

(let ([r (vectors->rsound (vector 3 4 5) (vector 2 -15 0) 200)]
      [s (/ s16max 15)])
  (check-equal? (rsound-nth-sample/left r 0)  (round (* s 3)))
  (check-equal? (rsound-nth-sample/right r 1)  (round (* s -15))))

(check-not-exn (lambda () (make-harm3tone 430 0.1 400 44100)))

;; is fader too slow?
;; answer: not yet a problem.
#;(time 
 (for ([i (in-range 100)])
   (fun->mono-rsound 44100 44100 (fader 44100))))

#;(time 
 (for ([i (in-range 100)])
   (fun->mono-rsound 44100 44100 (sine-wave 440 44100))))

#;(time
 (for ([i (in-range 100)])
   (fun->mono-rsound 44100 44100 (sawtooth-wave 440 44100))))

(let ([tr (sawtooth-wave 100 1000)])
  (check-= (tr 0) 0.0 1e-5)
  (check-= (tr 1) 0.2 1e-5)
  (check-= (tr 5) -1.0 1e-5))

;; memoizing

(let ([s1 (fun->mono-rsound 200 44100 (signal-*s (list (dc-signal 0.5) (sine-wave 100 44100))))]
      [s2 (time (make-tone 100 0.5 441000 44100))]
      [s3 (time (make-tone 100 0.5 441000 44100))])
  (check-= (rsound-nth-sample/right s1 73)
           (rsound-nth-sample/right s2 73)
           1e-2)
  (check-= (rsound-nth-sample/right s2 73)
           (rsound-nth-sample/right s3 73)
           1e-2))

;; bug in memoization:
(check-not-exn
 (lambda ()
   (make-tone 100 0.5 200 44100)
   (make-tone 100 0.5 400 44100)))

;; FFT

(let* ([tone (make-tone 147 1.0 4800 44100)]
       [fft (rsound-fft/left tone)])
  (check-= (magnitude (vector-ref fft 15)) 0.0 1e-2)
  (check-= (magnitude (vector-ref fft 16)) 2400.0 1e-2)
  (check-= (magnitude (vector-ref fft 17)) 0.0 1e-2))

(check-= ((frisellinator 100) 0) 0.0 1e-4)
(check-= ((frisellinator 100) 100) 1.0 1e-4)
(check-= ((frisellinator 100) 50) 0.5 1e-4)



(check-equal? (binary-logn 4096) 12)
(check-equal? (binary-logn 4095) #f)