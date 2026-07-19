;;;; test/07_nars.lisp — the language hands off inference to a reasoning substrate. sbcl --script test/07_nars.lisp
(load (merge-pathnames "../src/nars.lisp" *load-pathname*))

(format t "~&── nolang hands off the heavy inference to NARS, gets a derived atom ──~%")

;; nolang KNOWS two judgments; it does NOT derive the conclusion between them itself
(defparameter *facts*
  (list (make-natom '(isa socrates human)  0.9 0.9 "biography")
        (make-natom '(isa human mortal)    0.9 0.9 "aristotle")))

(format t "  know: ~a~%" (->narsese (first *facts*)))
(format t "  know: ~a~%" (->narsese (second *facts*)))

;; ask for the conclusion it did not derive itself
(let ((r (nars-ask *facts* '(isa socrates mortal))))
  (format t "~%  asked NARS:   (isa socrates mortal)?~%")
  (format t "  NARS derived: ~s  (f=~,3f c=~,3f)  ← ~a~%"
          (natom-judgment r) (natom-f r) (natom-c r) (natom-trace r)))

;; what does not follow — NARS won't invent (low confidence / no answer)
(let ((r (nars-ask *facts* '(isa socrates dog))))
  (format t "~%  asked NARS:   (isa socrates dog)?~%")
  (format t "  answer:       (f=~,3f c=~,3f)  ← ~a~%" (natom-f r) (natom-c r) (natom-trace r)))

(format t "~%  The language does not imitate reasoning — it hands it off to the substrate. (f,c) ↔ NARS truth, one pair on both sides.~%")
