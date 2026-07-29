;;;; test/80_coverage.lisp — ОХВАТ ВИДЕН. Печать как часть семантики.
;;;; Run: sbcl --script test/80_coverage.lisp
;;;;
;;;; ПОВОД (аудит 28.07, находка 8): машина хранила «где искали» и «почему пусто»,
;;;; типовой слой честно требовал молчание потребить — а показать его было НЕЧЕМ.
;;;; Охват потреблён и невидим: ровно то состояние, против которого заведена линейность.
;;;; Обзорная роль существует РАДИ ТОГО, чтобы читатель видел границу знания. Значит
;;;; печать охвата — не удобство, а условие того, что роль вообще имеет смысл.
(load (merge-pathnames "../src/reduce.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

(defun run-output (forms)
  "Прогнать и снять ВЕСЬ вывод показа в строку — так тест умеет падать по-настоящему."
  (multiple-value-bind (store ledger) (run-nolang forms)
    (with-output-to-string (*standard-output*) (show-run store ledger))))

(defparameter *прог*
  '((witness о-162 "…" :grade строго :f 0.9 :c 0.6)
    (ask т-273 :in (corpus library registry) :reason "записей об исходе 273 нет")
    (claim радость :grade строго (from о-162) (searched т-273))))

(format t "~&── ОБЗОРНЫЙ ОХВАТ ПЕЧАТАЕТСЯ ──~%")

(let ((out (run-output *прог*)))
  (check "в выводе есть слово «охват»" (search "охват" out))
  (check "напечатано ГДЕ искали — все три свода" 
         (and (search "CORPUS" out) (search "LIBRARY" out) (search "REGISTRY" out)))
  (check "напечатано ПОЧЕМУ пусто — причина дословно"
         (search "записей об исходе 273 нет" out))
  (check "охват привязан к молчанию по имени" (search "Т-273" out)))

;;; Тест обязан уметь падать: без обзорного молчания этих строк быть НЕ должно.
(let ((out (run-output '((witness о-162 "…" :grade строго :f 0.9 :c 0.6)
                         (claim радость :grade строго (from о-162))))))
  (check "без обзора охвата в выводе нет (тест не самоисполняющийся)"
         (not (search "REGISTRY" out)))
  (check "…но сказано, что охват НЕ ЗАЯВЛЕН — умолчание тоже видно"
         (search "охват не заявлен" out)))

(format t "~&── ОПОРА НА МОЛЧАНИЕ НАЗВАНА СЛОВАМИ ──~%")

;;; Степень падает до ⊥ — но читатель не обязан догадываться, ПОЧЕМУ.
(let ((out (run-output '((witness a "…" :grade строго :f 0.9 :c 0.6)
                         (ask пусто :in (corpus) :reason "традиция молчит")
                         (claim шаткое (from a пусто))))))
  (check "сказано, что утверждение ОПИРАЕТСЯ НА МОЛЧАНИЕ"
         (search "ОПИРАЕТСЯ НА МОЛЧАНИЕ" out))
  (check "назван аргумент от молчания как причина дна"
         (search "аргумент от молчания" out))
  (check "причина молчания приведена дословно" (search "традиция молчит" out))
  (check "степень действительно на дне" (search "⊥" out)))

(format t "~&── ДВЕ РОЛИ РАЗЛИЧИМЫ В ВЫВОДЕ ──~%")

;;; Одно и то же молчание в разных ролях обязано печататься ПО-РАЗНОМУ,
;;; иначе различие ролей существует только внутри и не доходит до читателя.
(let ((опора (run-output '((witness a "…" :grade строго :f 0.9 :c 0.6)
                           (ask s :in (corpus) :reason "пусто")
                           (claim c (from a s)))))
      (обзор (run-output '((witness a "…" :grade строго :f 0.9 :c 0.6)
                           (ask s :in (corpus) :reason "пусто")
                           (claim c (from a) (searched s))))))
  (check "опорное молчание помечено красным, обзорное — нет"
         (and (search "ОПИРАЕТСЯ НА МОЛЧАНИЕ" опора)
              (not (search "ОПИРАЕТСЯ НА МОЛЧАНИЕ" обзор))))
  (check "обзорное помечено как охват, опорное — не только им"
         (and (search "охват" обзор) (search "ОПИРАЕТСЯ" опора)))
  (check "и степени разные: опора роняет, обзор нет"
         (and (search "⊥" опора) (search "строго" обзор))))

(format t "~&── СВИДЕТЕЛЬ — НЕ ВЫВОД, у него охвата нет ──~%")

(let ((out (run-output '((witness одинокий "…" :grade строго :f 0.9 :c 0.6)))))
  (check "у свидетеля без основания строки про охват НЕТ (это не вывод)"
         (not (search "охват" out))))

(format t "~&── охват переживает ОТЗЫВ ──~%")

(let ((out (run-output '((witness a "…" :grade строго :f 0.9 :c 0.6)
                         (witness b "…" :grade строго :f 0.9 :c 0.6)
                         (ask s :in (registry) :reason "пусто")
                         (claim c :grade строго (from a b) (searched s))
                         (retract b :reason "подделка")))))
  (check "после пересчёта охват на месте — граница знания не теряется"
         (and (search "REGISTRY" out) (search "охват" out)))
  (check "…и основание сократилось" (search "на чём стоит: A" out)))

(format t "~&~%── как это выглядит целиком ──~%~a" (run-output *прог*))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
