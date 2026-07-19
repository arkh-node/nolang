;;;; test/03_eval.lisp — evaluator over atoms. sbcl --script test/03_eval.lisp
(load (merge-pathnames "../src/eval.lisp" *load-pathname*))

;; the agent's knowledge base
(know (make-natom '(safe migration)   0.9 0.7 "ci:4412"))
(know (make-natom '(tested migration) 0.8 0.6 "suite:green"))
(know (make-natom '(subject ari)      0.5 0.4 "zenodo:21288590"))  ; undecided (c<θ)

(defun show (label expr)
  (multiple-value-bind (r tr) (evaluate expr)
    (let ((res (if (natom-p r)
                   (format nil "judg ~s (f=~a c=~a)" (natom-judgment r) (natom-f r) (natom-c r))
                   (format nil "~s" r))))
      (format t "  ~40s → ~a~%       provenance: ~s~%" label res tr))))

(format t "~&── evaluating nolang expressions (result + provenance) ──~%")
(show "(if (check (safe migration)) :apply :abort)"
     '(if (check (safe migration)) :apply :abort))
(show "(if (check (subject ari)) :yes :no)   ; undecided"
     '(if (check (subject ari)) :yes :no))
(show "(if (check (deploy prod)) :go :stop)  ; UNknown"
     '(if (check (deploy prod)) :go :stop))

(format t "~%── composing judgments: a chain LOWERS confidence (deduction) ──~%")
(show "(and (check (safe migration)) (check (tested migration)))"
     '(and (check (safe migration)) (check (tested migration))))

(format t "~%── gate inside evaluation: confidence decides permission ──~%")
(show "(gate :irreversible (safe migration))"   '(gate :irreversible (safe migration)))
(show "(gate :irreversible (subject ari))"      '(gate :irreversible (subject ari)))

(format t "~%  Evaluation carries (value-or-judgment, provenance). Uncertainty is not guessed — it is routed.~%")
