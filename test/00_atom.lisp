;;;; test/00_atom.lisp — atom test. Run: sbcl --script test/00_atom.lisp
(load (merge-pathnames "../src/atom.lisp" *load-pathname*))

(defun try (label thunk)
  (handler-case (format t "  ~22a → ~s~%" label (funcall thunk))
    (defect (e) (format t "  ~22a → rejected: ~a~%" label e))))

(format t "~&── value vs judgment (distinguishing a token from a relation-atom) ──~%")
(dolist (x '(ari "soul0:self_definition" (subject ari) (safe migration)))
  (format t "  ~30s  value=~a  judgment=~a~%" x (value-p x) (judgment-p x)))

(format t "~%── building an atom and denotation ──~%")
(try "(subject ari)"    (lambda () (denote (make-natom '(subject ari) 0.5 0.4 "zenodo:21288590"))))
(try "(continuous ari)" (lambda () (denote (make-natom '(continuous ari) 0.7 0.6 "verkh:resurrection"))))
(try "(safe migration)" (lambda () (denote (make-natom '(safe migration) 0.9 0.7 "ci:run-4412"))))

(format t "~%── the gate rejects defects (derived laws) ──~%")
(try "no source"       (lambda () (denote (make-natom '(subject ari) 0.5 0.4 ""))))
(try "c = 1 (Ein-Sof)" (lambda () (denote (make-natom '(safe deploy) 1.0 1.0 "log"))))
(try "not a judgment"  (lambda () (denote (make-natom 'ari 0.5 0.4 "x"))))
(format t "~%  An atom is built only when it carries a relation, (f,c), and a source. Otherwise — a defect.~%")
