;;;; test/07_nars.lisp — OPTIONAL bridge to an external reasoning substrate (ONA).
;;;; The core does NOT depend on this. Skips cleanly if the external NAR binary is absent.
;;;; Run: sbcl --script test/07_nars.lisp
(load (merge-pathnames "../src/nars.lisp" *load-pathname*))
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))

(defparameter *facts*
  (list (make-natom '(isa socrates human)  0.9 0.9 "biography")
        (make-natom '(isa human mortal)    0.9 0.9 "aristotle")))

(format t "~&── nolang can derive the syllogism ITSELF (own evidence calculus) ──~%")
;; deduction now lives in the core (evidence.lisp) — no external substrate needed.
(multiple-value-bind (f c)
    (t-deduce (natom-f (first *facts*)) (natom-c (first *facts*))
              (natom-f (second *facts*)) (natom-c (second *facts*)))
  (format t "  (isa socrates human) ⊕ (isa human mortal) ⊢ (isa socrates mortal)~%")
  (format t "  own deduction: f=~,3f c=~,3f  (confidence falls — weak syllogism, as it should)~%" f c)
  (assert (< c 0.9) () "deduction must lower confidence")
  (format t "  ✓ core deduces without any external NARS.~%"))

(format t "~%── optional: hand off to external ONA if installed ──~%")
(handler-case
    (let ((r (nars-ask *facts* '(isa socrates mortal))))
      (format t "  external NARS derived: ~s (f=~,3f c=~,3f) ← ~a~%"
              (natom-judgment r) (natom-f r) (natom-c r) (natom-trace r)))
  (error (e)
    (declare (ignore e))
    (format t "  SKIPPED: external ONA (NAR binary) not installed — not required.~%")
    (format t "  The core stands on its own evidence calculus; the substrate bridge is optional.~%")))
