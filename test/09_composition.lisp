;;;; test/09_composition.lisp — the whole point, composed. Run: sbcl --script test/09_composition.lisp
;;;; Evidence (revision) changes what the gate PERMITS: confidence earned from below
;;;; is spent above. One agreeing source → fold (careful); two → act (irreversible allowed).
(load (merge-pathnames "../src/return.lisp" *load-pathname*))     ; gate + ilan
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))   ; revision

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

(format t "~&── one source: not sure enough → the gate folds first (reversible) ──~%")
(let* ((s1 (make-natom '(safe migrate-prod) 0.5 0.4 "ci:run-A"))
       (p1 (permit s1 :irreversible)))
  (format t "  (safe migrate-prod) @ (f=0.5 c=0.4)  →  permit :irreversible = ~s~%" p1)
  (check "one source ⇒ :fold-first" (eq p1 :fold-first)))

(format t "~%── two AGREEING sources: revision raises confidence → the gate ALLOWS ──~%")
(let* ((s1 (make-natom '(safe migrate-prod) 0.5 0.4 "ci:run-A"))
       (s2 (make-natom '(safe migrate-prod) 0.5 0.4 "ci:run-B"))
       (rev (revise-atoms s1 s2))
       (p2 (permit rev :irreversible)))
  (format t "  revise(A,B)  →  (f=~,3f c=~,3f)  from two sources at c=0.4~%"
          (natom-f rev) (natom-c rev))
  (check "revision raised c above θ=0.5" (>= (natom-c rev) 0.5))
  (format t "  revised (safe migrate-prod)  →  permit :irreversible = ~s~%" p2)
  (check "two agreeing sources ⇒ :allowed" (eq p2 :allowed)))

(format t "~%── the composition, stated ──~%")
(format t "  The SAME irreversible action is refused-into-a-fold with one witness,~%")
(format t "  and permitted with two that agree. Confidence is earned from below~%")
(format t "  (evidence pooled by revision) and spent above (the gate's permission).~%")
(format t "  nolang decides WHEN; ilan decides HOW to come back; revision decides HOW SURE.~%")

(format t "~%ALL GREEN — ~a checks passed.~%" *n*)
