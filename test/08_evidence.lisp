;;;; test/08_evidence.lisp — evidence calculus. Run: sbcl --script test/08_evidence.lisp
;;;; Red→green. asserts fail loudly; reaching the end prints ALL GREEN.
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))

(defun ~= (a b &optional (eps 1e-5)) (< (abs (- a b)) eps))  ; single-float tolerance
(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

(format t "~&── bridge (f,c) ↔ evidence round-trips ──~%")
(multiple-value-bind (w+ w-) (fc->evidence 0.8 0.6)
  (check "w+ = 1.2" (~= w+ 1.2))
  (check "w- = 0.3" (~= w- 0.3))
  (multiple-value-bind (f c) (evidence->fc w+ w-)
    (check "round-trip f = 0.8" (~= f 0.8))
    (check "round-trip c = 0.6" (~= c 0.6))))
(multiple-value-bind (f c) (evidence->fc 0 0)
  (check "no evidence ⇒ f=0.5" (~= f 0.5))
  (check "no evidence ⇒ c=0"   (~= c 0.0)))

(format t "~%── REVISION: two agreeing sources raise confidence (the fix) ──~%")
(multiple-value-bind (f c) (t-revise 0.9 0.5 0.9 0.5)
  (check "revised f stays 0.9"          (~= f 0.9))
  (check "revised c = 0.667 (> 0.5 each)" (~= c (/ 2.0 3.0) 1e-6))
  (check "confidence ROSE above inputs"  (> c 0.5)))
;; broken old behaviour would have given c = 0.5·0.5 = 0.25 (agreement LOWERING trust) — guard against it
(multiple-value-bind (f c) (t-revise 0.9 0.5 0.9 0.5)
  (declare (ignore f))
  (check "not the old c=ca·cb bug (0.25)" (not (~= c 0.25 1e-3))))

(format t "~%── monotonicity: more agreeing evidence ⇒ higher c ──~%")
(multiple-value-bind (f2 c2) (t-revise 0.8 0.6 0.8 0.6)
  (declare (ignore f2))
  (multiple-value-bind (f3 c3) (t-revise 0.8 0.6 0.8 (nth-value 1 (t-revise 0.8 0.6 0.8 0.6)))
    (declare (ignore f3))
    (check "3 sources more confident than 2" (> c3 c2))))

(format t "~%── associativity of revision (evidence addition is associative) ──~%")
(let* ((ab (multiple-value-list (t-revise 0.7 0.4 0.6 0.5)))
       (ab-c (multiple-value-list (t-revise (first ab) (second ab) 0.8 0.55)))
       (bc (multiple-value-list (t-revise 0.6 0.5 0.8 0.55)))
       (a-bc (multiple-value-list (t-revise 0.7 0.4 (first bc) (second bc)))))
  (check "revise assoc: f equal" (~= (first ab-c) (first a-bc) 1e-6))
  (check "revise assoc: c equal" (~= (second ab-c) (second a-bc) 1e-6)))

(format t "~%── AIKR: confidence never reaches 1, even under massive evidence ──~%")
(let ((c 0.5))
  (dotimes (i 40) (setf c (nth-value 1 (t-revise 0.9 0.9 0.9 c))))
  (check "c < 1 after 40 revisions" (< c 1))
  (check "c climbed high (> 0.99)"  (> c 0.99)))

(format t "~%── deduction LOWERS confidence (weak syllogism) ──~%")
(multiple-value-bind (f c) (t-deduce 0.9 0.8 0.9 0.8)
  (check "deduced f = 0.81"        (~= f 0.81))
  (check "deduced c < each input"  (< c 0.8)))

(format t "~%── conjunction/disjunction are honest NARS forms ──~%")
(multiple-value-bind (f c) (t-and 0.8 0.7 0.5 0.6)
  (check "and: f = 0.4"  (~= f 0.4))
  (check "and: c = 0.42" (~= c 0.42)))
(multiple-value-bind (f c) (t-or 0.8 0.7 0.5 0.6)
  (check "or: f = 0.9 (1-(1-.8)(1-.5))" (~= f 0.9))
  (check "or: c = 0.42"                 (~= c 0.42)))

(format t "~%ALL GREEN — ~a checks passed.~%" *n*)
