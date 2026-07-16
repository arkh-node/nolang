;;;; test/04_nol.lisp — исполнить программы .nol. sbcl --script test/04_nol.lisp
(load (merge-pathnames "../src/nol.lisp" *load-pathname*))

(выполнить-nol (merge-pathnames "../examples/migration.nol" *load-pathname*))
(выполнить-nol (merge-pathnames "../examples/subject.nol" *load-pathname*))

(format t "  nolang исполнил сам себя: программы .nol прочитаны и вычислены, каждый результат с провенансом.~%")
