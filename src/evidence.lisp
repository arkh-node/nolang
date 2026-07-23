;;;; nolang src — evidence. (f,c) <-> evidence counts; honest truth-combination.
;;;; Fixes the eval.lisp gap: `combine 'and` was used where REVISION was meant.
;;;; Foundations: NARS truth-value functions (Wang) ≅ Beta-opinion (Jøsang). Loads atom.
;;;;
;;;; Evidence view of a judgment: w+ (positive), w- (negative), w = w+ + w-.
;;;;   f = w+ / w                    frequency (how far it holds)
;;;;   c = w / (w + k)               confidence (how much evidence, vs horizon k)
;;;;   u = k / (w + k) > 0 always    ignorance — the Ein-Sof bound: c<1 is structural,
;;;;                                  only the Infinite is certain (finite evidence; cf. Wang's AIKR).

(load (merge-pathnames "atom.lisp" *load-pathname*))

(defparameter *k* 1.0
  "Evidential horizon (Beta prior weight). u = k/(w+k) > 0 ⇒ c<1 forever = the Ein-Sof bound (cf. Wang's AIKR).")

;; ── Bridge: (f,c) ↔ evidence ────────────────────────────────────────────────
(defun fc->evidence (f c &optional (k *k*))
  "(f,c) → (values w+ w-).  w = k·c/(1-c);  w+ = f·w;  w- = (1-f)·w."
  (assert (< c 1) () "Ein-Sof bound: confidence must be < 1 (got ~a)" c)
  (let* ((w  (/ (* k c) (- 1 c)))
         (w+ (* f w)))
    (values w+ (- w w+))))

(defun evidence->fc (w+ w- &optional (k *k*))
  "(w+,w-) → (values f c).  f = w+/w;  c = w/(w+k).  No evidence ⇒ (0.5, 0)."
  (let ((w (+ w+ w-)))
    (if (zerop w)
        (values 0.5 0.0)
        (values (/ w+ w) (/ w (+ w k))))))

;; ── REVISION: pool independent evidence for the SAME judgment ───────────────
;; The operator that was missing. Two agreeing sources MUST raise confidence.
(defun t-revise (fa ca fb cb &optional (k *k*))
  "Revision: sum the evidence of two sources of one judgment. (values f c).
   c strictly exceeds each input's c when both carry evidence — the fix."
  (multiple-value-bind (wa+ wa-) (fc->evidence fa ca k)
    (multiple-value-bind (wb+ wb-) (fc->evidence fb cb k)
      (evidence->fc (+ wa+ wb+) (+ wa- wb-) k))))

;; ── DEDUCTION: chain a syllogism (A→B, B→C ⊢ A→C). Confidence falls. ────────
(defun t-deduce (fa ca fb cb)
  "NARS deduction (strong syllogism): f = fa·fb ; c = fa·fb·ca·cb."
  (values (* fa fb) (* fa fb ca cb)))

;; ── CONJUNCTION (and, distinct facts): NARS intersection ────────────────────
(defun t-and (fa ca fb cb)
  "f = fa·fb ; c = ca·cb.  (Correct for independent conjunction — NOT revision.)"
  (values (* fa fb) (* ca cb)))

;; ── DISJUNCTION (or): NARS union ────────────────────────────────────────────
(defun t-or (fa ca fb cb)
  "f = 1-(1-fa)(1-fb) ; c = ca·cb."
  (values (- 1 (* (- 1 fa) (- 1 fb))) (* ca cb)))

;; ── Atom-level helpers (compound judgments; %make-natom skips base-atom check) ─
(defun revise-atoms (a b)
  "Revision of two atoms asserting the SAME judgment. Raises confidence."
  (multiple-value-bind (f c) (t-revise (natom-f a) (natom-c a) (natom-f b) (natom-c b))
    (%make-natom :judgment (natom-judgment a) :f f :c c
                 :trace (format nil "revise(~a,~a)" (natom-trace a) (natom-trace b)))))
