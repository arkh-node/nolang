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

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
