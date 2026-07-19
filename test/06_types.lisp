;;;; test/06_types.lisp — action contracts. sbcl --script test/06_types.lisp
(load (merge-pathnames "../src/types.lisp" *load-pathname*))

;; contract: apply the migration — requires safety AND a test; irreversible; yields «applied»
(defparameter *apply-fx*
  (make-contract :name 'apply-migration
                 :requires '((safe migration) (tested migration))
                 :class :irreversible
                 :yields '(applied migration)))

(defun run-case (label)
  (let ((r (run-contract *apply-fx* (lambda () :migration-run))))
    (format t "  ~34a → ~s~%" label r)))

(format t "~&── contract apply-migration (requires: safe AND tested) ──~%")

(know (make-natom '(safe migration)   0.9 0.7 "ci"))
(know (make-natom '(tested migration) 0.8 0.6 "suite"))
(run-case "both preconditions hold")
(format t "     now known: ~s~%" (multiple-value-list (evaluate '(check (applied migration)))))

;; drop confidence in the test → precondition undecided → route
(know (make-natom '(tested migration) 0.8 0.3 "flaky"))   ; c<θ
(run-case "test unsure (c=0.3)")

;; test is confidently false → unmet
(know (make-natom '(tested migration) 0.1 0.8 "failed"))  ; confident it does NOT hold
(run-case "test confidently failed")

(format t "~%  An action carries a contract: not knowing a precondition → route (not a guess); success → effect into knowledge.~%")
