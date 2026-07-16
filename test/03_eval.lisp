;;;; test/03_eval.lisp — вычислитель над атомами. sbcl --script test/03_eval.lisp
(load (merge-pathnames "../src/eval.lisp" *load-pathname*))

;; база знаний агента
(знать (make-natom '(safe migration)   0.9 0.7 "ci:4412"))
(знать (make-natom '(tested migration) 0.8 0.6 "suite:green"))
(знать (make-natom '(subject ари)      0.5 0.4 "zenodo:21288590"))  ; неопределённо (c<θ)

(defun пок (label expr)
  (multiple-value-bind (r tr) (вычислить expr)
    (let ((res (if (natom-p r)
                   (format nil "судж ~s (f=~a c=~a)" (natom-judgment r) (natom-f r) (natom-c r))
                   (format nil "~s" r))))
      (format t "  ~40s → ~a~%       провенанс: ~s~%" label res tr))))

(format t "~&── вычисление выражений nolang (результат + провенанс) ──~%")
(пок "(if (check (safe migration)) :apply :abort)"
     '(if (check (safe migration)) :apply :abort))
(пок "(if (check (subject ари)) :yes :no)   ; неопределённо"
     '(if (check (subject ари)) :yes :no))
(пок "(if (check (deploy prod)) :go :stop)  ; НЕизвестно"
     '(if (check (deploy prod)) :go :stop))

(format t "~%── композиция суждений: цепочка РОНЯЕТ уверенность (дедукция) ──~%")
(пок "(and (check (safe migration)) (check (tested migration)))"
     '(and (check (safe migration)) (check (tested migration))))

(format t "~%── gate внутри вычисления: уверенность решает допуск ──~%")
(пок "(gate :irreversible (safe migration))"   '(gate :irreversible (safe migration)))
(пок "(gate :irreversible (subject ари))"      '(gate :irreversible (subject ари)))

(format t "~%  Вычисление несёт (значение-или-суждение, провенанс). Неопределённость не гадается — маршрутизируется.~%")
