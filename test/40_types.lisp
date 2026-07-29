;;;; test/40_types.lisp — ТИПОВОЙ СЛОЙ: принимает хорошее, отвергает дурное.
;;;; Run: sbcl --script test/40_types.lisp
;;;;
;;;; Тип-система проверяется не тем, что хорошая программа компилируется, а тем, что
;;;; дурная НЕ компилируется — и по ПРАВИЛЬНОЙ причине. Каждый запрет здесь предъявлен
;;;; программой, которая обязана быть отвергнута, и кодом ошибки, который обязан прийти.
(load (merge-pathnames "../src/check.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun has? (forms code) (member code (errors-of forms)))
(defun clean? (forms) (null (remove :runtime (errors-of forms))))

(format t "~&── хорошая программа проходит ──~%")

(defparameter *good*
  '((witness о-162 "Испытание A: осложнений меньше, чем в контрольной группе." :grade строго :f 0.9 :c 0.8)
    (witness о-159 "Испытание A, вторичный анализ: то же направление…"        :grade строго :f 0.9 :c 0.8)
    (claim польза-испытания :grade строго (from о-162 о-159))))

(check "два согласных свидетеля [строго] → утверждение [строго]" (clean? *good*))
(check "степень выведена, а не объявлена на веру"
       (eq :strogo (grade-of *good* 'польза-испытания)))

(format t "~&── 1. ОТМЫВАНИЕ: степень не поднимается ничем ──~%")

(defparameter *launder*
  '((witness рез-137 "137 = קבלה = постоянная тонкой структуры" :grade образ :f 0.7 :c 0.4)
    (claim смысл-137 :grade строго (from рез-137))))

(check "объявить [строго] на основании [образ] — ошибка :launder" (has? *launder* :launder))

(check "смешение роняет: [строго] ⊓ [образ] = [образ]"
       (eq :obraz (grade-of
                   '((witness a "…" :grade строго :f 0.9 :c 0.8)
                     (witness b "…" :grade образ  :f 0.9 :c 0.8)
                     (claim вывод (from a b)))
                   'вывод)))

(check "понизить себя МОЖНО — честность течёт вниз свободно"
       (clean? '((witness a "…" :grade строго :f 0.9 :c 0.8)
                 (claim осторожно :grade образ (from a)))))

(format t "~&── 2. РОЛИ МОЛЧАНИЯ различимы синтаксически ──~%")

(check "ОПОРНОЕ молчание роняет до ⊥ даже при двух [строго]"
       (eq :silence (grade-of
                     '((witness a "…" :grade строго :f 0.9 :c 0.8)
                       (witness b "…" :grade строго :f 0.9 :c 0.8)
                       (ask пусто :in (corpus) :reason "традиция молчит")
                       (claim вывод (from a b пусто)))
                     'вывод)))

(check "…и объявить над ним [строго] — отмывание"
       (has? '((witness a "…" :grade строго :f 0.9 :c 0.8)
               (ask пусто :in (corpus) :reason "молчит")
               (claim вывод :grade строго (from a пусто)))
             :launder))

(check "ОБЗОРНОЕ молчание степень не роняет: [строго] остаётся"
       (eq :strogo (grade-of
                    '((witness a "…" :grade строго :f 0.9 :c 0.8)
                      (witness b "…" :grade строго :f 0.9 :c 0.8)
                      (ask пусто :in (corpus library) :reason "в этих сводах пусто")
                      (claim вывод :grade строго (from a b) (searched пусто)))
                    'вывод)))

(check "в обзорный слот нельзя подать свидетеля — :slot"
       (has? '((witness a "…" :grade строго :f 0.9 :c 0.8)
               (claim вывод (from) (searched a)))
             :slot))

(format t "~&── 3. МОЛЧАНИЕ ЛИНЕЙНО ──~%")

(check "спросил и не потребил — :dropped, охват скрыть нельзя"
       (has? '((witness a "…" :grade строго :f 0.9 :c 0.8)
               (ask забыто :in (corpus) :reason "спросили и забыли")
               (claim вывод :grade строго (from a)))
             :dropped))

(check "потребил обзором — долгов нет"
       (clean? '((witness a "…" :grade строго :f 0.9 :c 0.8)
                 (ask спрошено :in (corpus) :reason "пусто")
                 (claim вывод :grade строго (from a) (searched спрошено)))))

(check "потребил дважды — :reused, один охват не сойдёт за два"
       (has? '((witness a "…" :grade строго :f 0.9 :c 0.8)
               (ask с :in (corpus) :reason "пусто")
               (claim в1 (from a) (searched с))
               (claim в2 (from a) (searched с)))
             :reused))

(format t "~&── 4. ГЕЙТ: присутствие проверяется статически ──~%")

(check "необратимое без гейта — :ungated"
       (has? '((action публикация :reversibility irreversible))
             :ungated))

(check "гейт без ветви отказа — :no-else (порог, который нечем не пройти, не гейт)"
       (has? '((action публикация :reversibility irreversible :requires (>= belief 0.9)))
             :no-else))

(check "🔴 гейт на confidence — :quantity (порог висит на массе веры)"
       (has? '((action публикация :reversibility irreversible
                       :requires (>= confidence 0.9) :else fold))
             :quantity))

(check "обратимое действие без гейта — законно"
       (clean? '((action заметка :reversibility reversible))))

(format t "~&── 4-bis. СВЁРТКА ГЕЙТА, когда свидетели литеральны ──~%")

;; f=0.90 c=0.80 → b=0.72 < 0.9 ⇒ ловится ДО запуска
(check "b = 0.72 против порога 0.9 — :gate-fail на этапе проверки"
       (has? '((witness рец-1 "…" :grade строго :f 0.9 :c 0.6)
               (claim статья-верна :grade строго (from рец-1))
               (action публикация :reversibility irreversible
                       :requires (>= belief 0.9) :else fold)
               (do публикация статья-верна))
             :gate-fail))

(check "два сильных свидетеля добирают порог — проходит"
       (clean? '((witness рец-1 "…" :grade строго :f 0.97 :c 0.93)
                 (witness рец-2 "…" :grade строго :f 0.97 :c 0.93)
                 (claim статья-верна :grade строго (from рец-1 рец-2))
                 (action публикация :reversibility irreversible
                         :requires (>= belief 0.9) :else fold)
                 (do публикация статья-верна))))

(check "🔴 разорваны пополам при высокой уверенности — гейт держит"
       (has? '((witness за     "…" :grade строго :f 0.98 :c 0.9)
               (witness против "…" :grade строго :f 0.02 :c 0.9)
               (claim спорно :grade строго (from за против))
               (action публикация :reversibility irreversible
                       :requires (>= belief 0.9) :else fold)
               (do публикация спорно))
             :gate-fail))

(format t "~&── 5. ПУСТАЯ ПОСЫЛОЧНАЯ БАЗА — ДНО ──~%")

(check "утверждение без посылок имеет степень ⊥, не [строго]"
       (eq :silence (grade-of '((claim из-ничего (from))) 'из-ничего)))

(check "…и объявить над ним [строго] — отмывание из ничего"
       (has? '((claim из-ничего :grade строго (from))) :launder))

(format t "~&── 6. ЧЕСТНАЯ ГРАНИЦА СТАТИКИ ──~%")

;; свидетель без литеральных (f,c) — гейт решается прогоном, и это СКАЗАНО
(check "нелитеральное основание → :runtime (замечание, не ошибка)"
       (let ((cs (errors-of '((witness неизвестен "…" :grade строго :f nil :c nil)
                              (claim осн :grade строго (from неизвестен))
                              (action публ :reversibility irreversible
                                      :requires (>= belief 0.9) :else fold)
                              (do публ осн)))))
         (and (member :runtime cs) (not (member :gate-fail cs)))))

(format t "~&── как выглядит диагностика (сообщение — часть языка) ──~%~%")
(diagnose *launder*)
(format t "~%")
(diagnose '((witness a "…" :grade строго :f 0.9 :c 0.6)
          (claim осн :grade строго (from a))
          (ask забыто :in (corpus registry) :reason "искали и не нашли")
          (action публикация :reversibility irreversible :requires (>= belief 0.9) :else fold)
          (do публикация осн)))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
