#lang racket/gui
(require drracket/tool
         framework)
 
(provide tool@)
 
(define tool@
  (unit
    (import drracket:tool^)
    (export drracket:tool-exports^)
    (define (phase1)
      (preferences:add-panel
       "RSound"
       (λ (parent)
         (define vpanel
           (new vertical-panel% (parent parent) (alignment '(left top))))
         (new choice% [label "default frame rate"]
              [choices '("44100" "48000")]
              [parent vpanel])
         vpanel)))
    (define (phase2) (message-box "rsound example" "phase2"))
    (message-box "tool example" "unit invoked")))
