;;;; Э2/Ш2.3 — обратная связь NARS→(f,c) сдвигает вердикт кредального gate. Emits OK/FAIL.
;;;; gate = threshold-verdict (тот же, что в operator_agent_loop и в C1_credal): :passed|:reachable|:unreachable.
;;;; Сценарий: слабое прямое суждение (socrates mortal, c=0.4) → вердикт :reachable (порог не взят).
;;;; NARS независимой цепочкой (socrates→human→mortal) выводит то же → ревизуем НЕЗАВИСИМЫМ корнем
;;;; → c растёт → вердикт :passed. Сдвиг измерен счётом, и он случается ТОЛЬКО из-за NARS.
(load (merge-pathnames "../../src/prelude.lisp" *load-pathname*))

(defun atom-verdict (a thr)
  "Кредальный вердикт атома по его (f,c): переводим в свидетельства и судим порогом."
  (multiple-value-bind (w+ w-) (fc->evidence (natom-f a) (natom-c a))
    (threshold-verdict w+ w- thr)))

(defun chk (name pred) (format t "~&~:[FAIL~;OK~] ~a~%" pred name))

(let* ((thr 7/10)
       (weak  (make-natom '(isa socrates mortal) 1.0 0.4 "one-weak-witness"))
       (facts (list (make-natom '(isa socrates human) 1.0 0.9 "given-a")
                    (make-natom '(isa human mortal)   1.0 0.9 "given-b")))
       (v-without (atom-verdict weak thr))
       (revised   (nars-revise weak facts))
       (v-with    (atom-verdict revised thr)))
  (format t "~&без NARS: c=~,3f → вердикт=~a~%" (float (natom-c weak) 1.0) v-without)
  (format t "с NARS:   c=~,3f → вердикт=~a~%" (float (natom-c revised) 1.0) v-with)
  (chk "слабое суждение под порогом → вердикт :reachable (порог не взят)"
       (eq v-without :reachable))
  (chk "NARS-корень поднял c (независимая цепочка → c растёт по разному корню)"
       (> (natom-c revised) (natom-c weak)))
  (chk "NARS-обратная-связь СДВИНУЛА вердикт gate :reachable -> :passed"
       (eq v-with :passed))
  (chk "сдвиг случился ИМЕННО от NARS: без ревизии вердикт остаётся :reachable"
       (and (eq v-without :reachable) (eq v-with :passed) (not (eq v-without v-with)))))
