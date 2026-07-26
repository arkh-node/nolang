;;;; nolang src 03 — eval. Implements spec/03_eval.md.
;;;; Computation = (result . provenance). Forms: check/if/gate/and/or. Three-valued. Provenance threaded throughout.

(load (merge-pathnames "gate.lisp" *load-pathname*))       ; atom + gate
(load (merge-pathnames "evidence.lisp" *load-pathname*))   ; honest (f,c) combination

(defvar *knowledge* (make-hash-table :test #'equal) "base: judgment → atom (what the agent knows).")
(defun know (a) (setf (gethash (natom-judgment a) *knowledge*) a) a)
(defun lookup (j)
  "Atom for judgment j: known — from the base; else unknown (low c, honest not-knowing)."
  (or (gethash j *knowledge*)
      (make-natom j 0.5 0.1 "unknown")))

(defun combine (op a b)
  "Logical composition of two DISTINCT judgments (evidence calculus).
   and = NARS conjunction (f·f, c·c) ; or = NARS union (1-(1-f)(1-f), c·c).
   NB: pooling two sources of the SAME judgment is `revise`, not this — see evidence.lisp."
  (let ((fa (natom-f a)) (ca (natom-c a)) (fb (natom-f b)) (cb (natom-c b))
        (tr (format nil "~a+~a" (natom-trace a) (natom-trace b))))
    (multiple-value-bind (f c)
        (ecase op (and (t-and fa ca fb cb)) (or (t-or fa ca fb cb)))
      ;; derived (compound) judgment — %make-natom skips base-atom check; c<1 preserved by construction
      (%make-natom :judgment (list op (natom-judgment a) (natom-judgment b))
                   :f f :c c :trace tr))))

(defun evaluate (expr)
  "expr → (values result provenance). result = value | atom | :route | action-permission."
  (cond
    ((value-p expr) (values expr '()))                              ; literal: (v . ∅)
    ((and (consp expr) (eq (first expr) 'check))
     (let ((a (lookup (second expr))))
       (values a (list (natom-trace a)))))                          ; knowledge/unknown + source
    ((and (consp expr) (eq (first expr) 'if))
     (destructuring-bind (test yes no) (rest expr)
       (multiple-value-bind (a tr) (evaluate test)
         (ecase (outcome a)
           (:confident-yes (multiple-value-bind (r tr2) (evaluate yes) (values r (append tr tr2))))
           (:confident-no  (multiple-value-bind (r tr2) (evaluate no)  (values r (append tr tr2))))
           (:undecided     (values :route (cons "undecided→route" tr)))))))  ; do NOT guess
    ((and (consp expr) (member (first expr) '(and or)))
     (multiple-value-bind (a ta) (evaluate (second expr))
       (multiple-value-bind (b tb) (evaluate (third expr))
         (values (combine (first expr) a b) (append ta tb)))))
    ((and (consp expr) (eq (first expr) 'revise))                   ; pool two sources of one judgment → higher c
     (multiple-value-bind (a ta) (evaluate (second expr))
       (multiple-value-bind (b tb) (evaluate (third expr))
         (values (revise-atoms a b) (append ta tb)))))
    ((and (consp expr) (eq (first expr) 'gate))
     (destructuring-bind (class j) (rest expr)
       (multiple-value-bind (a tr) (evaluate (list 'check j))
         (values (permit a class) tr))))
    (t (error 'defect :why (format nil "not a nolang expression: ~s" expr)))))
