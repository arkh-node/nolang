;;;; nolang src 03 — eval. Implements spec/03_eval.md.
;;;; Computation = (result . provenance). Forms: check/if/gate/and/or. Three-valued. Provenance threaded throughout.

(load (merge-pathnames "gate.lisp" *load-pathname*))   ; atom + gate

(defvar *knowledge* (make-hash-table :test #'equal) "base: judgment → atom (what the agent knows).")
(defun know (a) (setf (gethash (natom-judgment a) *knowledge*) a) a)
(defun lookup (j)
  "Atom for judgment j: known — from the base; else unknown (low c, honest not-knowing)."
  (or (gethash j *knowledge*)
      (make-natom j 0.5 0.1 "unknown")))

(defun combine (op a b)
  "Chain/alternative of judgments: (f,c) combine, provenance is merged. Deduction lowers confidence."
  (let ((fa (natom-f a)) (ca (natom-c a)) (fb (natom-f b)) (cb (natom-c b))
        (tr (format nil "~a+~a" (natom-trace a) (natom-trace b))))
    ;; derived (compound) judgment — %make-natom without base-atom check; c=ca·cb<1 is preserved
    (ecase op
      (and (%make-natom :judgment (list 'and (natom-judgment a) (natom-judgment b))
                        :f (* fa fb) :c (* ca cb) :trace tr))
      (or  (%make-natom :judgment (list 'or (natom-judgment a) (natom-judgment b))
                        :f (max fa fb) :c (min 0.99 (max ca cb)) :trace tr)))))

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
    ((and (consp expr) (eq (first expr) 'gate))
     (destructuring-bind (class j) (rest expr)
       (multiple-value-bind (a tr) (evaluate (list 'check j))
         (values (permit a class) tr))))
    (t (error 'defect :why (format nil "not a nolang expression: ~s" expr)))))
