#lang racket

(require "../main.rkt")

;; this is a manual test. Check the time gap between the 
;; printing of the text and the playing of the sound.
(for ([i (in-range 10)])
  (printf "ding\n")
  (play ding)
  (sleep 1.5))
