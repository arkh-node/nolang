;;;; test/06_types.lisp — контракты действий. sbcl --script test/06_types.lisp
(load (merge-pathnames "../src/types.lisp" *load-pathname*))

;; контракт: применить миграцию — требует безопасности И теста; необратимо; даёт «применена»
(defparameter *применить*
  (make-контракт :имя 'apply-migration
                 :требует '((safe migration) (tested migration))
                 :класс :irreversible
                 :даёт '(applied migration)))

(defun прогон (label)
  (let ((r (выполнить-контракт *применить* (lambda () :migration-run))))
    (format t "  ~34a → ~s~%" label r)))

(format t "~&── контракт apply-migration (требует: safe И tested) ──~%")

(знать (make-natom '(safe migration)   0.9 0.7 "ci"))
(знать (make-natom '(tested migration) 0.8 0.6 "suite"))
(прогон "оба предусловия держатся")
(format t "     теперь известно: ~s~%" (multiple-value-list (вычислить '(check (applied migration)))))

;; убрать уверенность в тесте → предусловие undecided → route
(знать (make-natom '(tested migration) 0.8 0.3 "flaky"))   ; c<θ
(прогон "тест неуверен (c=0.3)")

;; тест ложен уверенно → unmet
(знать (make-natom '(tested migration) 0.1 0.8 "failed"))  ; уверены, что НЕ держится
(прогон "тест провален уверенно")

(format t "~%  Действие несёт контракт: незнание предусловия → route (не догадка); успех → эффект в знание.~%")
