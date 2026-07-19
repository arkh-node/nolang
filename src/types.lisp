;;;; nolang src 04 — types. Implements spec/04_types.md.
;;;; Action contract: what it requires (precondition judgments), which class, what it yields (effect judgment).
;;;; Unknown precondition → route (no guess). Success → effect extends knowledge.

(load (merge-pathnames "eval.lisp" *load-pathname*))   ; atom+gate+eval (know/lookup/eval/permit)

(defstruct contract
  name
  requires   ; list of judgments — preconditions (must be confident-yes)
  class     ; :reversible | :irreversible
  yields)     ; judgment — effect (new knowledge after execution)

(defun check-requirements (reqs)
  "Returns: :ok | (:route j) | (:unmet j) — the first unmet precondition stops it."
  (dolist (j reqs :ok)
    (multiple-value-bind (a tr) (evaluate (list 'check j))
      (declare (ignore tr))
      (ecase (outcome a)
        (:confident-yes)                 ; holds — continue
        (:undecided    (return (list :route j)))
        (:confident-no (return (list :unmet j)))))))

(defun run-contract (contract action &key (f 0.85) (c 0.7))
  "Check preconditions → permission by class → run → effect into knowledge.
   action — a thunk (the real effect). Returns: (:done effect) | (:route j) | (:unmet j) | :denied."
  (let ((chk (check-requirements (contract-requires contract))))
    (cond
      ((not (eq chk :ok)) chk)         ; route / unmet — don't act
      (t (let* ((decision (make-natom (contract-yields contract) f c
                                 (format nil "action:~a" (contract-name contract))))
                (permission (permit decision (contract-class contract))))
           (case permission
             ((:allowed :fold-first)     ; allowed (or reversible with a snapshot)
              (funcall action)
              (know decision)                ; effect extends knowledge, with the action's provenance
              (list :done (contract-yields contract)))
             (:denied :denied)))))))
