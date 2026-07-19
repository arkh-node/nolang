;;;; nolang src 01 — gate. Implements spec/01_gate.md.
;;;; (f,c) DECIDES the action class. Three-valued if. Monotonic in c. Loads atom.

(load (merge-pathnames "atom.lisp" *load-pathname*))

(defparameter *theta* 0.5 "confidence threshold: c >= theta = 'confident'. Monotonicity makes the choice safe.")

(defun outcome (a &optional (theta *theta*))
  "Three-valued outcome over an atom: :confident-yes | :confident-no | :undecided."
  (let ((c (natom-c a)) (f (natom-f a)))
    (cond
      ((< c theta) :undecided)        ; not sure → third branch (no guess)
      ((>= f 0.5)  :confident-yes)     ; confident and holds
      (t           :confident-no))))  ; confident and doesn't hold

(defun nif (a &key yes no undecided (theta *theta*))
  "Three-valued if of nolang. undecided does NOT guess — it routes to another check."
  (ecase (outcome a theta)
    (:confident-yes (if yes (funcall yes) :yes))
    (:confident-no  (if no (funcall no) :no))
    (:undecided     (if undecided (funcall undecided) :route))))

(defun permit (a action-class &optional (theta *theta*))
  "Permission for an action class given the atom's confidence (capability effect).
   :reversible always; :irreversible only when confident-yes; when undecided → :fold-first (snapshot, reversible)."
  (case action-class
    (:reversible :allowed)
    (:irreversible
     (ecase (outcome a theta)
       (:confident-yes :allowed)
       (:undecided     :fold-first)   ; not a ban — class downgrade: ilan.fold, then reversible
       (:confident-no  :denied)))
    (t (error 'defect :why (format nil "unknown action class: ~s" action-class)))))
