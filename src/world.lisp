;;;; nolang src 05 — world. Implements spec/05_world.md.
;;;; True rollback: under low confidence the WORLD-SIDE trace + agent state roll back together. Irreversible-without-confidence is blocked.

(load (merge-pathnames "return.lisp" *load-pathname*))   ; atom+gate+ilan+return

(defstruct effect
  description
  run    ; fn: changes the world
  undo)  ; fn: restores the world. nil ⇒ effect is IRREVERSIBLE

(defun act-in-world (agent a effect &key refuted (seed "/tmp/nol-agent.seed"))
  "gate + a real world effect with rollback. Returns: an outcome symbol."
  (cond
    ((crossed-p agent a) :already-crossed)
    (t (case (permit a :irreversible)
         (:allowed (funcall (effect-run effect)) :done-irreversibly)  ; confident → irreversibly
         (:denied  :aborted)
         (:fold-first
          (cond
            ((null (effect-undo effect)) :blocked-irreversible)  ; no undo under low confidence → protected
            (t (mark-crossing agent a)
               (sow seed)                          ; state snapshot (ilan)
               (funcall (effect-run effect))        ; run the world effect (reversible — undo exists)
               (cond
                 ((and refuted (funcall refuted))
                  (funcall (effect-undo effect))    ; ← first roll back the WORLD-SIDE trace
                  (germinate seed)                          ; ← then roll back state, remembering the crossing
                  :rolled-back-world-and-self)
                 (t :kept)))))))))
