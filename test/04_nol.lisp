;;;; test/04_nol.lisp — run .nol programs. sbcl --script test/04_nol.lisp
(load (merge-pathnames "../src/nol.lisp" *load-pathname*))

(run-nol (merge-pathnames "../examples/migration.nol" *load-pathname*))
(run-nol (merge-pathnames "../examples/subject.nol" *load-pathname*))

(format t "  nolang ran itself: the .nol programs were read and evaluated, each result with provenance.~%")
