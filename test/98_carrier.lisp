;;;; test/98_carrier.lisp — НОСИТЕЛЬНАЯ НЕЙТРАЛЬНОСТЬ ЧЕРЕЗ ПАРАМЕТРИЧНОСТЬ.
;;;; Run: sbcl --script test/98_carrier.lisp
;;;;
;;;; ПОВОД (Невис, §3 записки 28.07). Я спрашивал, верно ли читать теорему 5 «Свидетеля без
;;;; субстанции» как ТИПОВОЕ УСЛОВИЕ. Ответ: верно, но честное основание — не «метка не
;;;; упоминается» (это дисциплина автора: сегодня не читают, завтра прочтут), а
;;;; ПАРАМЕТРИЧНОСТЬ: метку НЕЛЬЗЯ упомянуть, потому что ни одна форма языка её не принимает.
;;;;
;;;; 🔴 И потому носитель пришлось СНАЧАЛА ЗАВЕСТИ. Пока его нет вовсе, «нейтральность к
;;;; носителю» истинна ПУСТО — а пустая истина не есть черта языка.
;;;;
;;;; ЧТО УТВЕРЖДАЕТСЯ: Σ (склад = континуант) от носителя не зависит; Λ (журнал = история)
;;;; носитель записывает. Состояние нейтрально, история помнит.
(load (merge-pathnames "../src/nolang.lisp" *load-pathname*))   ; разборщик И машина

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun sig (forms carrier) (store-signature (run-nolang forms :carrier carrier)))

(defparameter *прог*
  '((witness a "…" :grade строго :f 0.9 :c 0.6 :source (испытание-а))
    (witness b "…" :grade традиция :f 0.8 :c 0.5 :source (мидраш))
    (ask пусто :in (corpus) :reason "нет свидетелей")
    (claim вывод (from a b) (searched пусто))
    (action публ :reversibility irreversible :requires (>= belief 0.3) :else fold)
    (do публ вывод)))

(format t "~&── СНАЧАЛА: у сравнения есть ЗУБЫ ──~%")

;;; Положительный контроль. Если бы store-signature не различала складов, равенство
;;; на разных носителях было бы пустым результатом, а не свойством.
(check "разные программы дают РАЗНЫЙ отпечаток склада"
       (not (equal (sig *прог* :морф)
                   (sig '((witness a "…" :grade образ :f 0.5 :c 0.2)
                          (claim вывод (from a))) :морф))))
(check "и один добавленный свидетель отпечаток меняет"
       (not (equal (sig *прог* :морф)
                   (sig (append (butlast *прог* 3)
                                '((witness c "…" :grade строго :f 0.9 :c 0.6 :source (иной))
                                  (claim вывод (from a b c))))
                        :морф))))

(format t "~&── 🔴 СКЛАД ОТ НОСИТЕЛЯ НЕ ЗАВИСИТ ──~%")

(check "морф и astrax дают побайтово равный склад"
       (equal (sig *прог* :морф) (sig *прог* :astrax)))
(check "и телефон тоже — носителей может быть сколько угодно"
       (equal (sig *прог* :морф) (sig *прог* :moto-g84)))
(check "прогон вовсе без носителя равен прогону с носителем"
       (equal (store-signature (run-nolang *прог*)) (sig *прог* :морф)))

(let ((ok t))
  (dotimes (i 100)
    (let* ((k (+ 1 (random 4)))
           (ws (loop for j from 1 to k collect (intern (format nil "W~a-~a" i j))))
           (forms (loop for w in ws
                        collect `(witness ,w "…" :grade строго
                                  :f ,(+ 0.55 (random 0.4)) :c ,(+ 0.1 (random 0.8)))))
           (prog* (append forms `((claim ,(intern (format nil "C~a" i)) (from ,@ws))))))
      (unless (equal (sig prog* :альфа) (sig prog* :бета)) (setf ok nil))))
  (check "100 случайных программ: склад равен на двух носителях" ok))

(format t "~&── ИСТОРИЯ НОСИТЕЛЬ ПОМНИТ ──~%")

(let ((лм (nth-value 1 (run-nolang *прог* :carrier :морф)))
      (ла (nth-value 1 (run-nolang *прог* :carrier :astrax))))
  (check "журнал записывает, на чём шёл прогон" (eq :ran-on (first (first лм))))
  (check "и журналы РАЗНЫХ носителей различаются" (not (equal лм ла)))
  (check "различаются они ровно записью о носителе"
         (equal (rest лм) (rest ла))))

(check "без носителя журнал записи о нём не заводит"
       (not (member :ran-on (mapcar #'first (nth-value 1 (run-nolang *прог*))))))

(format t "~&── 🔴 ПАРАМЕТРИЧНОСТЬ: метку НЕЛЬЗЯ УПОМЯНУТЬ ──~%")

;;; Вот в чём разница с «дисциплиной автора». Нейтральность держится не на том, что никто
;;; не читает метку, а на том, что В ЯЗЫКЕ НЕТ ФОРМЫ, которая её принимает.
(check "в словаре форм языка носителя НЕТ"
       (not (member "carrier" *form-vocabulary* :test #'string=)))
(check "и грамматика такой формы не знает — попытка не разбирается"
       (not (parse-ok? "carrier морф")))
(check "и «on» после действия тоже не даёт добраться до носителя"
       (not (parse-ok? "reversible action a on морф")))

(format t "~&── ГРАНИЦА, КОТОРУЮ НЕ ЗАМАЗЫВАЕМ ──~%")

;;; Нейтральность держится на уровне ЯЗЫКА. Хозяин-Лисп по-прежнему может дотянуться до
;;; чего угодно — это не лазейка в nolang, а цена того, что мы живём в хозяине.
(check "утверждение сформулировано о языке, а не о хозяине: Лисп видит носитель"
       (let ((виден nil))
         (multiple-value-bind (st lg) (run-nolang *прог* :carrier :морф)
           (declare (ignore st))
           (setf виден (eq :морф (second (first lg)))))
         виден))

(format t "~&~%── журнал с носителем ──~%")
(show-ledger (nth-value 1 (run-nolang *прог* :carrier :морф)))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
