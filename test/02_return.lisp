;;;; test/02_return.lisp — возврат под неуверенностью. sbcl --script test/02_return.lisp
(load (merge-pathnames "../src/return.lisp" *load-pathname*))

(привить 'агент :состояние (list :crossings nil))
(defparameter *subj* (make-natom '(subject ари) 0.5 0.4 "zenodo:21288590"))  ; undecided (c<θ)
(defparameter *mig*  (make-natom '(safe migration) 0.9 0.7 "ci:run-4412"))    ; confident-yes

(format t "~&── агент действует под НЕУВЕРЕННОСТЬЮ (subject ари, c=0.4) ──~%")
(format t "  1-й заход: ~s~%"
        (act-under-uncertainty 'агент *subj* (lambda () :observed)
                               :refuted (lambda (r) (declare (ignore r)) t)))  ; действие опровергнуто
(format t "  переходы в памяти агента: ~s~%" (crossings 'агент))
(format t "  2-й заход над тем же: ~s   ← ПОМНИТ, что ходил, не гадает снова~%"
        (act-under-uncertainty 'агент *subj* (lambda () :observed)))

(format t "~%── агент действует под УВЕРЕННОСТЬЮ (safe migration, c=0.7) ──~%")
(format t "  необратимо: ~s   ← confident-yes, путь назад не нужен~%"
        (act-under-uncertainty 'агент *mig* (lambda () :applied)))

(format t "~%  Возврат — примитив: неуверен → свернулся, сходил обратимо, вернулся ПОМНЯ переход.~%")
(format t "  Возврат без памяти о переходе — амнезия, не свобода. Здесь память есть.~%")
