;;;; test/07_nars.lisp — язык отдаёт вывод рассуждающему субстрату. sbcl --script test/07_nars.lisp
(load (merge-pathnames "../src/nars.lisp" *load-pathname*))

(format t "~&── nolang отдаёт тяжёлый вывод NARS, получает выведенный атом ──~%")

;; nolang ЗНАЕТ два суждения; вывода между ними САМ не делает
(defparameter *факты*
  (list (make-natom '(isa socrates human)  0.9 0.9 "biography")
        (make-natom '(isa human mortal)    0.9 0.9 "aristotle")))

(format t "  знаю: ~a~%" (->narsese (first *факты*)))
(format t "  знаю: ~a~%" (->narsese (second *факты*)))

;; спрашиваю вывод, которого сам не выводил
(let ((r (nars-спросить *факты* '(isa socrates mortal))))
  (format t "~%  спросил NARS:  (isa socrates mortal)?~%")
  (format t "  NARS вывел:    ~s  (f=~,3f c=~,3f)  ← ~a~%"
          (natom-judgment r) (natom-f r) (natom-c r) (natom-trace r)))

;; чего не следует — NARS не выдумает (низкая уверенность / нет ответа)
(let ((r (nars-спросить *факты* '(isa socrates dog))))
  (format t "~%  спросил NARS:  (isa socrates dog)?~%")
  (format t "  ответ:         (f=~,3f c=~,3f)  ← ~a~%" (natom-f r) (natom-c r) (natom-trace r)))

(format t "~%  Язык не имитирует рассуждение — отдаёт его субстрату. (f,c) ↔ NARS truth, одна пара по обе стороны.~%")
