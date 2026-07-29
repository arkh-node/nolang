;;;; test/A2_rules.lisp — ПОЛИМОРФИЗМ ПО СТЕПЕНЯМ через ПРАВИЛА.
;;;; Run: sbcl --script test/A2_rules.lisp
;;;;
;;;; ЗАДАЧА (ТИПЫ_v0 §8): `∀g₁g₂. Jud[g₁] → Jud[g₂] → Jud[g₁⊓g₂]`. Без этого библиотеку
;;;; не написать: всякий переиспользуемый вывод пришлось бы копировать под каждую степень.
;;;;
;;;; 🔴 РЕШЕНИЕ ОБ ОБЪЁМЕ: функций в языке нет и вводить их ради этого — расширение куда
;;;; большее, чем нужно. Носитель поменьше и достаточный — ПРАВИЛО, именованный вывод,
;;;; параметризованный посылками. Раскрывается подстановкой при разборе.
;;;;
;;;; 💎 И тогда «∀g» проверяется НЕ доверием, а ПЕРЕБОРОМ: решётка конечна, значит
;;;; квантор по степеням разрешим. Ниже он и перебирается — все 16 пар прелюдии.
(load (merge-pathnames "../src/nolang.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

(defparameter *степени* '("silence" "image" "tradition" "strict"))

(defun программа (g1 g2 &optional объявленная)
  (format nil "
rule corroborate(p, q) concludes from p, q
witness a : ~a says \"…\" source x evidence 8 for 1 against
witness b : ~a says \"…\" source y evidence 5 for 1 against
claim joy~@[ : ~a~] = corroborate(a, b)
" g1 g2 объявленная))

(format t "~&── ПРАВИЛО РАБОТАЕТ ──~%")

(check "объявление и применение разбираются" (parse-ok? (программа "strict" "image")))
(check "применение раскрывается в обычное утверждение"
       (equal '(claim joy (from a b))
              (car (last (parse (программа "strict" "image"))))))

(format t "~&── 🔴 ∀g₁∀g₂ ПЕРЕБОРОМ: 16 пар прелюдии ──~%")

;;; Утверждение: правило при ЛЮБЫХ степенях посылок даёт ровно их нижнюю грань.
;;; Решётка конечна ⇒ перебор есть доказательство, а не выборка.
(let ((ok t) (пар 0) (различных '()))
  (dolist (g1 *степени*)
    (dolist (g2 *степени*)
      (incf пар)
      (let* ((forms (parse (программа g1 g2)))
             (вышло (grade-of forms 'joy))
             (ждём (g-meet (parse-grade g1) (parse-grade g2))))
        (pushnew вышло различных)
        (unless (eq вышло ждём) (setf ok nil)))))
  (check "правило даёт g₁⊓g₂ на ВСЕХ 16 парах — квантор проверен перебором"
         (and ok (= пар 16)))
  (check "…и результаты действительно разные (перебор не вырожден)"
         (>= (length различных) 4)))

(format t "~&── 🔴 ПРАВИЛО НЕ ДАЁТ ПОДНЯТЬ СТЕПЕНЬ НИ ПРИ КАКОМ ПОДСТАВЛЕНИИ ──~%")

;;; Главное свойство. Если бы правило умело поднимать — оно поднимало бы ВЕЗДЕ, где применено.
(let ((поймано 0) (попыток 0))
  (dolist (g1 *степени*)
    (dolist (g2 *степени*)
      (dolist (объявл *степени*)
        (let ((ждём (g-meet (parse-grade g1) (parse-grade g2))))
          (unless (g<= (parse-grade объявл) ждём)     ; объявляем ВЫШЕ выведенного
            (incf попыток)
            (when (member :launder (errors-of (parse (программа g1 g2 объявл))))
              (incf поймано)))))))
  (check "каждая попытка объявить выше выведенного поймана как :launder"
         (and (= поймано попыток) (> попыток 20)))
  (format t "      [попыток отмывания через правило: ~a, поймано: ~a]~%" попыток поймано))

(format t "~&── 🔴 ПРАВИЛО НЕ МОЖЕТ ОБЪЯВИТЬ СТЕПЕНЬ ──~%")

;;; Не «нельзя и мы проверим», а НЕ РАЗБИРАЕТСЯ: одно правило со степенью отмывало бы
;;; везде, где применено, — объявленная однажды степень размножилась бы по всем употреблениям.
(check "rule со степенью не разбирается"
       (not (parse-ok? "rule bad(p, q) : strict concludes from p, q")))
(check "…и сообщение объясняет, почему именно"
       (search "размножилась бы" (parse-error-of "rule bad(p, q) : strict concludes from p, q")))

(format t "~&── ПРАВИЛО ЗАМКНУТО НА СВОИ ПАРАМЕТРЫ ──~%")

(check "тянуть свидетеля из окружения нельзя — не разбирается"
       (not (parse-ok? "rule sneak(p) concludes from p, посторонний")))
(check "…и сказано, что это прятало бы посылку от читателя"
       (search "прятать посылку" (parse-error-of "rule sneak(p) concludes from p, посторонний")))

(format t "~&── АРИТМЕТИКА ПРИМЕНЕНИЯ ──~%")

(check "неверное число посылок ловится при разборе"
       (not (parse-ok? "
rule pair(p, q) concludes from p, q
witness a : strict says \"…\" source x evidence 8 for 1 against
claim c = pair(a)")))
(check "неизвестное правило ловится при разборе"
       (not (parse-ok? "witness a : strict says \"…\" source x evidence 1 for 0 against
claim c = нетакого(a)")))

(format t "~&── ПРАВИЛО МОЖЕТ НЕСТИ И ОБЗОР ──~%")

(let ((src "
rule with-coverage(p, s) concludes from p searched s
witness a : strict says \"…\" source x evidence 8 for 1 against
ask пусто in corpus found nothing because \"не нашли\"
claim c = with-coverage(a, пусто)"))
  (check "правило с обзорным слотом разбирается и раскрывается" (parse-ok? src))
  (check "обзор доходит до утверждения — степень НЕ падает"
         (eq :strogo (grade-of (parse src) 'c)))
  (check "…и молчание считается потреблённым (линейность соблюдена)"
         (null (remove :runtime (errors-of (parse src))))))

(format t "~&── ПРАВИЛО НЕ ЛОМАЕТ ПРОГОН ──~%")

(let ((forms (parse (программа "strict" "tradition"))))
  (check "машина считает раскрытое утверждение как обычное"
         (eq (grade-of forms 'joy) (grade-at-runtime forms 'joy)))
  (check "форма rule до машины доходит и молча пропускается"
         (numberp (nth-value 2 (run-nolang forms)))))

(format t "~&── 🔴 G1. ОДНО ПРАВИЛО НА РАЗНЫХ РЕШЁТКАХ, БЕЗ ПЕРЕПИСЫВАНИЯ ──~%")
;;; Наказ Невис, G1: «правило, работающее для любой решётки, удовлетворяющей условию импорта».
;;; 💎 И вот что выяснилось делом: правила УЖЕ полиморфны — и не потому, что мы это строили,
;;; а потому, что правило НЕ МОЖЕТ ОБЪЯВИТЬ СТЕПЕНЬ (решение хода 11, принятое из совсем
;;; других соображений: объявленная однажды степень размножилась бы по всем применениям).
;;; 🔴 Ограничение купило общность. Форма, которой нечего сказать о конкретной решётке,
;;; работает на всякой — не по замыслу, а по невозможности сказать лишнее.
(defparameter *одно-и-то-же-правило* "rule подкрепить(p, q) concludes from p, q")

(defparameter *на-цепи*
  (format nil "lattice L = слабо < средне < сильно
~a
witness a : сильно says \"…\" source r1 evidence 5 for 0 against
witness b : средне says \"…\" source r2 evidence 5 for 0 against
claim вывод = подкрепить(a, b)" *одно-и-то-же-правило*))

(defparameter *на-произведении*
  (format nil "lattice ЧА = слабо < сильно
lattice ЧБ = шатко < твёрдо
lattice L = ЧА * ЧБ
~a
witness a : (сильно, твёрдо) says \"…\" source r1 evidence 5 for 0 against
witness b : (слабо, твёрдо) says \"…\" source r2 evidence 5 for 0 against
claim вывод = подкрепить(a, b)" *одно-и-то-же-правило*))

(check "🔴 текст правила в обеих программах ПОБУКВЕННО один"
       (and (search *одно-и-то-же-правило* *на-цепи*)
            (search *одно-и-то-же-правило* *на-произведении*)))
(check "на ЦЕПИ правило даёт верную грань"
       (eq :СРЕДНЕ (grade-at-runtime (parse *на-цепи*) 'вывод)))
(check "на ПРОИЗВЕДЕНИИ — то же правило даёт покомпонентную грань"
       (equal '(:СЛАБО :ТВЁРДО) (grade-at-runtime (parse *на-произведении*) 'вывод)))
(check "…и это РАЗНЫЕ ответы: полиморфизм не совпадение"
       (not (equal (grade-at-runtime (parse *на-цепи*) 'вывод)
                   (grade-at-runtime (parse *на-произведении*) 'вывод))))
(check "обе программы приняты проверяющим"
       (every (lambda (src) (null (set-difference (errors-of (parse src))
                                                  '(:runtime :gate-fail))))
              (list *на-цепи* *на-произведении*)))
(check "и статика сходится с прогоном на обеих"
       (every (lambda (src) (let ((f (parse src)))
                              (equal (grade-of f 'вывод) (grade-at-runtime f 'вывод))))
              (list *на-цепи* *на-произведении*)))

(format t "~&── …и ловится применение там, где условие НЕ выполняется ──~%")

(check "🔴 форма степени не по решётке — правило не спасает, ошибка приходит"
       ;; обе степени ОБЪЯВЛЕНЫ (иначе пришла бы :grade, «неизвестная степень»), но
       ;; действующая решётка ЛИНЕЙНА, а свидетель предъявил кортеж — это :grade-shape
       (member :grade-shape
               (errors-of (parse (format nil "lattice ЧБ = шатко < твёрдо
lattice L = слабо < средне < сильно
~a
witness a : (сильно, твёрдо) says \"…\" source r1 evidence 5 for 0 against
witness b : средне says \"…\" source r2 evidence 5 for 0 against
claim вывод = подкрепить(a, b)" *одно-и-то-же-правило*)))))
(check "🔴 правило поверх ДУРНОГО импорта: условие φ не выполнено — импорт отвергнут"
       (member :import
               (errors-of (parse (format nil "lattice ЧА = слабо < сильно
lattice ЧБ = шатко < твёрдо
lattice ИСТОЧНИК = ЧА * ЧБ
lattice L = молчание < образ < традиция < строго
import ЧУЖОЙ lattice ИСТОЧНИК via (слабо, шатко) -> молчание, (слабо, твёрдо) -> традиция,
                                  (сильно, шатко) -> образ, (сильно, твёрдо) -> строго
~a
witness a of ЧУЖОЙ : (сильно, твёрдо) says \"…\" source r1 evidence 5 for 0 against
witness b of ЧУЖОЙ : (слабо, твёрдо) says \"…\" source r2 evidence 5 for 0 against
claim вывод = подкрепить(a, b)" *одно-и-то-же-правило*)))))
(check "…а с ВЕРНЫМ φ то же правило поверх импорта проходит"
       (null (set-difference
              (errors-of (parse (format nil "lattice ЧА = слабо < сильно
lattice ЧБ = шатко < твёрдо
lattice ИСТОЧНИК = ЧА * ЧБ
lattice L = молчание < образ < традиция < строго
import ЧУЖОЙ lattice ИСТОЧНИК via (слабо, шатко) -> молчание, (слабо, твёрдо) -> молчание,
                                  (сильно, шатко) -> образ, (сильно, твёрдо) -> традиция
~a
witness a of ЧУЖОЙ : (сильно, твёрдо) says \"…\" source r1 evidence 5 for 0 against
witness b of ЧУЖОЙ : (слабо, твёрдо) says \"…\" source r2 evidence 5 for 0 against
claim вывод = подкрепить(a, b)" *одно-и-то-же-правило*)))
              '(:runtime :gate-fail))))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
