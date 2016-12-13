#lang racket/gui
(require drracket/tool
         framework)
 
(provide tool@)

;; the list of permissible default frame rates.
;; This is used for generation of all built-in sounds, and is the
;; default for pstreams and in other places. You can change it with
;; the default-frame-rate parameter, but this won't affect the sounds
;; that are already generated.
;; For ease of use, we limit this setting to one of a few possibilities.
;; there's really no reason not to allow anything between 8K and 48K except
;; that it would confuse people. I don't know whether 96K would present
;; problems... it might slow down sound generation unacceptably.
(define LEGAL-DEFAULT-FRS '(44100 48000))

;; if the existing preference is not one of the legal ones, reset to this:
(define RESET-FR 44100)

(define tool@
  (unit
    (import drracket:tool^)
    (export drracket:tool-exports^)
    (define (phase1)
      (define FR-pref-from-file (get-preference 'rsound:default-frame-rate))
      (define FR-pref (cond [(member FR-pref-from-file LEGAL-DEFAULT-FRS)
                             FR-pref-from-file]
                            [else
                             (put-preferences '(rsound:default-frame-rate)
                                              (list RESET-FR))
                             RESET-FR]))
      (define FR-pref-idx (for/first ([i (in-naturals)]
                                      [fr (in-list LEGAL-DEFAULT-FRS)]
                                      #:when (= FR-pref fr))
                            i))
      (preferences:add-panel
       "RSound"
       (λ (parent)
         (define vpanel
           (new vertical-panel% (parent parent) (alignment '(left top))))
         (new choice%
              [label "default frame rate"]
              [choices (map number->string LEGAL-DEFAULT-FRS)]
              [parent vpanel]
              [selection FR-pref-idx]
              [callback
               (λ (choicebox evt)
                 (when (equal? (send evt get-event-type) 'choice)
                   (match (send choicebox get-selection)
                     [#f (error 'choice-callbox
                                "internal error: no default frame rate selected (should be impossible?)")]
                     [n (put-preferences '(rsound:default-frame-rate)
                                         (list (list-ref LEGAL-DEFAULT-FRS n)))])))])
         vpanel)))
    (define (phase2) (void))))
