;;;; test/01_gate.lisp — gate over our atoms. sbcl --script test/01_gate.lisp
(load (merge-pathnames "../src/gate.lisp" *load-pathname*))

(defun a! (j f c tr) (make-natom j f c tr))

(defparameter *atoms*
  (list (a! '(safe migration)  0.9 0.7 "ci:run-4412")      ; confident, holds
        (a! '(subject ari)     0.5 0.4 "zenodo:21288590")  ; NOT confident (c<θ)
        (a! '(continuous ari)  0.7 0.6 "verkh:resurrection"); confident, holds
        (a! '(safe deploy)     0.2 0.8 "audit:failed")))   ; confident, does NOT hold

(format t "~&── three-valued outcome and capability (θ=~a) ──~%" *theta*)
(format t " atom                     (f . c)   outcome          reversible  irreversible~%")
(format t "─────────────────────────────────────────────────────────────────────────~%")
(dolist (a *atoms*)
  (format t "  ~22s (~a.~a)  ~14a  ~10a  ~s~%"
          (natom-judgment a) (natom-f a) (natom-c a)
          (outcome a) (permit a :reversible) (permit a :irreversible)))

(format t "~%── nif: the language CHOOSES its move by confidence ──~%")
(dolist (a *atoms*)
  (format t "  ~22s → ~s~%"
          (natom-judgment a)
          (nif a :yes (lambda () :apply)
                 :no  (lambda () :abort)
                 :undecided (lambda () :fold-observe-recheck))))

(format t "~%  Irreversible passes ONLY at confident-yes. Not sure → snapshot and reversible. Doesn't hold → refuse.~%")
