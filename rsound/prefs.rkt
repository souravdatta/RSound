#lang typed/racket/base

;; manage the default-frame-rate pref

(require racket/file)

(provide get-fr-pref
         set-fr-pref!
         LEGAL-DEFAULT-FRS)

;; the list of permissible default frame rates.
;; This is used for generation of all built-in sounds, and is the
;; default for pstreams and in other places. You can change it with
;; the default-frame-rate parameter, but this won't affect the sounds
;; that are already generated.
;; For ease of use, we limit this setting to one of a few possibilities.
;; there's really no reason not to allow anything between 8K and 48K except
;; that it would confuse people. I don't know whether 96K would present
;; problems... it might slow down sound generation unacceptably.
(: LEGAL-DEFAULT-FRS (Listof Real))
(define LEGAL-DEFAULT-FRS '(44100 48000))

;; if the existing preference is not one of the legal ones, reset to this:
(: RESET-FR Real)
(define RESET-FR 44100)

;; the name used in the prefs file to associated the FR with:
(define PREF-NAME 'rsound:default-frame-rate)

(unless (member RESET-FR LEGAL-DEFAULT-FRS)
  (error 'rsound-prefs
         "internal error: default fr pref (~e) is not one of the legal ones: ~e"
         RESET-FR LEGAL-DEFAULT-FRS))

;; get the value of the pref. Reset it to RESET-FR if it's not one of
;; the legal ones.
(: get-fr-pref (-> Real))
(define (get-fr-pref)
  (define FR-pref-from-file (get-preference PREF-NAME))
  (cond [(member FR-pref-from-file LEGAL-DEFAULT-FRS)
         ;; invariant: membership in a list of reals means it must
         ;; be a real. TR can't prove this...
         (cast FR-pref-from-file Real)]
        [else
         (set-fr-pref! RESET-FR)
         RESET-FR]))

;; set the fr pref stored in the file.
;; WARNING: calling this outside of the preferences panel will
;; mean that the value of the choice box no longer matches the
;; value stored in the preferences file.
(: set-fr-pref! (Real -> Void))
(define (set-fr-pref! fr)
  (unless (member fr LEGAL-DEFAULT-FRS)
    (raise-argument-error 'set-fr-pref!
                          (format "frame rate from legal list (~e)"
                                  LEGAL-DEFAULT-FRS)
                          0 fr))
  (put-preferences (list PREF-NAME)
                   (list fr)))