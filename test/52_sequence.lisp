(load "/srv/langs/nolang/src/verdict.lisp")
(defun chk (name pred) (format t "~&~:[FAIL~;OK~] ~a~%" pred name))
(defun perf-p (ledger act)
  (find-if (lambda (e) (and (eq (first e) :performed) (same-name-p (second e) act))) ledger))
(defun fold-p (ledger act)
  (find-if (lambda (e) (and (eq (first e) :folded) (same-name-p (second e) act))) ledger))
(defun skip-p (ledger act)
  (find-if (lambda (e) (and (eq (first e) :skipped) (same-name-p (second e) act))) ledger))

(defparameter *base* "
lattice provenance = silence < image < tradition < strict
witness w1 : strict says \"крепко\" source s1 evidence 8 for 0 against
claim strong : strict from w1
witness w2 : strict says \"слабо\" source s2 evidence 1 for 0 against
claim weak : strict from w2
irreversible action x needs grade >= strict gated by belief >= 0.7 else fold
irreversible action y needs grade >= strict gated by belief >= 0.7 else fold
")

;; случай 1: x на strong (пройдёт) then y на strong → оба совершены
(multiple-value-bind (forms errs) (compile-nolang (concatenate 'string *base* "
perform x on strong then perform y on strong"))
  (chk "случай1: проверяющий принял seq" (null (remove :runtime (mapcar #'terr-code errs))))
  (multiple-value-bind (store ledger) (run-nolang forms)
    (declare (ignore store))
    (chk "случай1: x совершено" (perf-p ledger 'x))
    (chk "случай1: y совершено (шаг ПОСЛЕ passed)" (perf-p ledger 'y))))

;; случай 2: x на weak (свернётся) then y на strong → x folded, y SKIPPED
(multiple-value-bind (forms errs) (compile-nolang (concatenate 'string *base* "
perform x on weak then perform y on strong"))
  (declare (ignore errs))
  (multiple-value-bind (store ledger) (run-nolang forms)
    (declare (ignore store))
    (chk "случай2: x свёрнут (веры не хватило)" (fold-p ledger 'x))
    (chk "случай2: y ПРОПУЩЕН (предыдущее не passed)" (skip-p ledger 'y))
    (chk "случай2: y НЕ совершён" (not (perf-p ledger 'y)))))
