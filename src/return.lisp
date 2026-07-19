;;;; nolang src 02 — return. Bridge gate ↔ ilan. Implements return (roadmap: ilan fold/sprout).
;;;; :fold-first stops being a mere marker: under low confidence the agent FOLDS (ilan),
;;;; acts reversibly, and on refutation SPROUTS back — REMEMBERING the crossing (not amnesia).
;;;; Crossing memory (crossing = path class) is our contribution: sprout remembers it went, and won't blindly repeat.

(load (merge-pathnames "gate.lisp" *load-pathname*))          ; atom + gate
(load (merge-pathnames "../../ilan/ilan.lisp" *load-pathname*)) ; ilan: fold / sprout / sow / germinate

(defun crossings (agent)
  "Crossings the agent has already gone through (list of judgments of the unresolved)."
  (state (branch agent) :crossings '()))

(defun mark-crossing (agent a)
  "Record the crossing BEFORE the snapshot — then it enters the seed and survives the return."
  (setf (state (branch agent) :crossings)
        (cons (natom-judgment a) (crossings agent))))

(defun crossed-p (agent a)
  (member (natom-judgment a) (crossings agent) :test #'equal))

(defun act-under-uncertainty (agent a action &key (seed "/tmp/nol-agent.seed") refuted)
  "gate decides the action class. The return primitive in action:
   already crossed this path → don't guess again; confident-yes → irreversible; undecided → fold, reversible, on-refute sprout remembering."
  (cond
    ((crossed-p agent a) :already-crossed)          ; already crossed → don't blindly repeat
    (t (case (permit a :irreversible)
         (:allowed  (funcall action))               ; confident and holds → irreversible allowed
         (:denied   :aborted)                        ; confident it doesn't hold → refuse
         (:fold-first
          (mark-crossing agent a)                   ; mark crossing BEFORE fold (goes into the seed)
          (sow seed)                            ; ilan.fold → to disk (a way back exists)
          (let ((r (funcall action)))               ; reversible action
            (if (and refuted (funcall refuted r))
                (progn (germinate seed)                ; ilan.sprout ← return...
                       :sprouted-remembering)        ; ...but crossing already in the seed: I remember I went
                :kept)))))))
