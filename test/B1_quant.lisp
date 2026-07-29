;;;; test/B1_quant.lisp — КВАНТИФИКАЦИЯ ПО КОРПУСУ.
;;;; Run: sbcl --script test/B1_quant.lisp
;;;;
;;;; ЗАЧЕМ (разбор 28.07, урок Rego): язык делает языком не управление потоком, а квантификация
;;;; по данным. Пока правило говорит о трёх поимённо названных свидетелях, это формат записи;
;;;; когда о ВСЕХ, удовлетворяющих условию, — язык.
;;;;
;;;; 🔴 ТРИ РЕШЕНИЯ, ПРИНЯТЫЕ ДО КОДА, И КАЖДОЕ ПРОВЕРЯЕТСЯ НИЖЕ:
;;;;  1. квантор бежит по ВСЕМУ корпусу, а не по объявленному выше — иначе рушится
;;;;     конфлюэнтность (доказанная `perm-inv`);
;;;;  2. отбор есть ВЕКТОР ЧЕРРИ-ПИКИНГА, запретить нельзя ⇒ отсев обязан быть ВИДЕН,
;;;;     а опасный отсев измеряется теоремой 5;
;;;;  3. требование к МНОЖЕСТВУ (N различных корней) не выполнено ⇒ дно, как пустая база.
(load (merge-pathnames "../src/nolang.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun ~= (a b &optional (eps 1e-4)) (< (abs (- a b)) eps))
(defun out-of (forms)
  (multiple-value-bind (st lg) (run-nolang forms)
    (with-output-to-string (*standard-output*) (show-run st lg))))

(defparameter *корпус*
  '((witness за-1   "…" :grade строго   :f 0.95 :c 0.6 :source (a))
    (witness за-2   "…" :grade строго   :f 0.95 :c 0.6 :source (b))
    (witness слабый "…" :grade образ    :f 0.90 :c 0.6 :source (c))
    (witness против "…" :grade образ    :f 0.05 :c 0.6 :source (d))))
;; ⚠️ Степени подобраны СЧЁТОМ: `против` сделан образом, чтобы отбор по `grade >= строго` его
;; ИСКЛЮЧАЛ — иначе теста на черри-пикинг не выйдет. Первая редакция дала ему строгую степень,
;; отбор его не трогал, и «отбор поднимает веру» упало. Машина была права, данные мои.

(defun с-корпусом (&rest claims) (append *корпус* claims))

(format t "~&── КВАНТОР БЕРЁТ КОРПУС ──~%")

(check "`from all` без условий берёт всех четверых"
       (= 4 (length (jv-base (gethash 'всё (run-nolang (с-корпусом '(claim всё (from-all)))))))))
(check "степень = нижняя грань по всем: есть образ ⇒ образ"
       (eq :obraz (grade-at-runtime (с-корпусом '(claim всё (from-all))) 'всё)))
(check "отбор по степени берёт только строгих (двое из четырёх)"
       (= 2 (length (jv-base (gethash 'стр (run-nolang
              (с-корпусом '(claim стр (from-all :grade>= строго)))))))))
(check "отбор по корню берёт ровно одного"
       (equal '(за-1) (jv-base (gethash 'один (run-nolang
              (с-корпусом '(claim один (from-all :root a))))))))
(check "отрицательный отбор по корню исключает ровно одного"
       (= 3 (length (jv-base (gethash 'без (run-nolang
              (с-корпусом '(claim без (from-all :not-root a)))))))))

;; 🔴 Отбор НЕ всегда черри-пикинг: он может и ПОНИЗИТЬ веру, исключив сторонника.
;; Ровно поэтому его нельзя запретить — можно только сделать видимым.
(check "отбор по степени может ПОНИЗИТЬ веру, если исключает сторонника"
       (let* ((к '((witness за-1 "…" :grade строго :f 0.95 :c 0.6 :source (a))
                   (witness за-2 "…" :grade строго :f 0.95 :c 0.6 :source (b))
                   (witness слабый "…" :grade образ :f 0.90 :c 0.6 :source (c))
                   (witness против "…" :grade строго :f 0.05 :c 0.6 :source (d))))
              (всё (belief-at-runtime (append к '((claim c (from-all)))) 'c))
              (отбор (belief-at-runtime (append к '((claim c (from-all :grade>= строго)))) 'c)))
         (< отбор всё)))

(format t "~&── 🔴 КОНФЛЮЭНТНОСТЬ УЦЕЛЕЛА: квантор не зависит от порядка ──~%")

;;; Если бы квантор брал «объявленных выше», перестановка меняла бы результат.
(let ((до (append *корпус* '((claim c (from-all :grade>= строго)))))
      (после (append (list (first *корпус*))
                     '((claim c (from-all :grade>= строго)))
                     (rest *корпус*))))
  (check "свидетель, объявленный ПОСЛЕ утверждения, всё равно попадает в квантор"
         (= (length (jv-base (gethash 'c (run-nolang до))))
            (length (jv-base (gethash 'c (run-nolang после))))))
  (check "…и вера та же — perm-inv не сломан"
         (~= (belief-at-runtime до 'c) (belief-at-runtime после 'c))))

(format t "~&── 🔴 ЧЕРРИ-ПИКИНГ ВИДЕН И ИЗМЕРЕН ──~%")

;;; Счётом: весь корпус даёт меньше, чем отбор согласных. Разница и есть выгода от отсева.
(let ((всё (belief-at-runtime (с-корпусом '(claim c (from-all))) 'c))
      (черри (belief-at-runtime (с-корпусом '(claim c (from-all :grade>= строго))) 'c)))
  (check "отбор поднимает веру — опасность настоящая, а не выдуманная" (> черри всё))
  (check "и поднимает существенно (> 0.05)" (> (- черри всё) 0.05)))

(let ((o (out-of (с-корпусом '(claim c (from-all :grade>= строго))))))
  (check "отсев напечатан с числом и именами"
         (and (search "отсеяно квантором" o) (search "СЛАБЫЙ" o)))
  (check "🔴 опасный отсев помечен ОТДЕЛЬНО"
         (search "частотой НИЖЕ полученной веры" o))
  (check "…и назван поимённо тот, чьё исключение подняло веру"
         (search "ПРОТИВ" o))
  (check "сказано, что это может быть черри-пикинг" (search "черри-пикинг" o)))

;;; Тест обязан уметь падать: безобидный отсев опасным НЕ помечается.
(let ((o (out-of (с-корпусом '(claim c (from-all :grade>= образ))))))
  (check "отсев, никого не исключивший, вовсе не печатается"
         (not (search "отсеяно квантором" o))))

(let ((o (out-of (list '(witness сильный "…" :grade строго :f 0.95 :c 0.6 :source (a))
                       '(witness тоже    "…" :grade образ  :f 0.95 :c 0.6 :source (b))
                       '(claim c (from-all :grade>= строго))))))
  (check "отсев СОГЛАСНОГО свидетеля опасным не помечен (его частота не ниже веры)"
         (and (search "отсеяно квантором" o)
              (not (search "частотой НИЖЕ" o)))))

(format t "~&── ТРЕБОВАНИЕ К МНОЖЕСТВУ ──~%")

(check "не хватает различных корней ⇒ степень на дне"
       (eq :silence (grade-at-runtime
                     (с-корпусом '(claim c (from-all :root a) (requiring-roots 2))) 'c)))
(check "хватает корней ⇒ степень выводится обычно"
       (eq :strogo (grade-at-runtime
                    (с-корпусом '(claim c (from-all :grade>= строго) (requiring-roots 2))) 'c)))
(check "недобор корней напечатан числом"
       (search "НЕДОБОР КОРНЕЙ: требовалось 2" 
               (out-of (с-корпусом '(claim c (from-all :root a) (requiring-roots 2))))))
(check "🔴 корни считаются РАЗЛИЧНЫЕ, а не документы: две копии одного корня — один корень"
       (eq :silence (grade-at-runtime
                     (list '(witness к1 "…" :grade строго :f 0.9 :c 0.6 :source (испытание-а))
                           '(witness к2 "…" :grade строго :f 0.9 :c 0.6 :source (испытание-а))
                           '(claim c (from-all) (requiring-roots 2)))
                     'c)))

(format t "~&── ПУСТОЙ ОТБОР И ОТЗЫВ ──~%")

(check "квантор не нашёл никого ⇒ пустая база ⇒ дно (правило уже было, работает и здесь)"
       (eq :silence (grade-at-runtime (с-корпусом '(claim c (from-all :root нет-такого))) 'c)))
(check "отозванные в квантор не попадают вовсе"
       (= 1 (length (jv-base (gethash 'c (run-nolang
              (с-корпусом '(claim c (from-all :grade>= строго))
                          '(retract за-1 :reason "подделка"))))))))
(check "отзыв КОРНЯ убирает всех его потомков и из квантора"
       (= 3 (length (jv-base (gethash 'c (run-nolang
              (append *корпус*
                      '((witness ещё "…" :grade строго :f 0.9 :c 0.6 :source (a))
                        (claim c (from-all))
                        (retract a :reason "свод под вопросом")))))))))

(format t "~&── 🔴 ЗДРАВОСТЬ: статика = прогон и на кванторе ──~%")

;;; Проверяющий и машина отбирают ОДНИМ предикатом (иначе разошлись бы), но обходят по-разному.
(let ((ok t) (видов '()))
  (dotimes (i 150)
    (let* ((k (+ 2 (random 4)))
           (ws (loop for j from 1 to k
                     collect (list (intern (format nil "W~a-~a" i j))
                                   (nth (random 3) '(образ традиция строго))
                                   (intern (format nil "R~a" (random 3))))))
           (forms (loop for (nm g r) in ws
                        collect `(witness ,nm "…" :grade ,g :f ,(+ 0.5 (random 0.45))
                                  :c ,(+ 0.1 (random 0.8)) :source (,r))))
           (spec (nth (random 3) '(() (:grade>= традиция) (:grade>= строго))))
           (cid (intern (format nil "C~a" i)))
           (prog* (append forms `((claim ,cid (from-all ,@spec))))))
      (pushnew (grade-at-runtime prog* cid) видов)
      (unless (eq (grade-of prog* cid) (grade-at-runtime prog* cid)) (setf ok nil))))
  (check "150 случайных программ с квантором: статика = прогон" ok)
  (check "…и результаты разнообразны (перебор не вырожден)" (>= (length видов) 3)))

(format t "~&── ГРАММАТИКА ──~%")

(check "`from all` разбирается"
       (parse-ok? "witness а : строго says \"…\" source з evidence 8 for 1 against
claim c from all"))
(check "`from all where grade >= степень` разбирается"
       (parse-ok? "witness а : строго says \"…\" source з evidence 8 for 1 against
claim c from all where grade >= традиция"))
(check "условия соединяются через and"
       (parse-ok? "witness а : строго says \"…\" source з evidence 8 for 1 against
claim c from all where grade >= строго and root not резонанс"))
(check "`requiring N roots` разбирается"
       (parse-ok? "witness а : строго says \"…\" source з evidence 8 for 1 against
claim c from all where grade >= строго requiring 2 roots"))
(check "🔴 отбор по ТЕКСТУ свидетельства не разбирается"
       (not (parse-ok? "witness а : строго says \"…\" source з evidence 8 for 1 against
claim c from all where says contains \"радость\"")))
(check "…и сказано, почему: такой отсев нечем измерить"
       (search "нечем измерить"
               (parse-error-of "witness а : строго says \"…\" source з evidence 1 for 0 against
claim c from all where says contains \"радость\"")))
(check "`requiring` считает КОРНИ — иначе не разбирается"
       (not (parse-ok? "witness а : строго says \"…\" source з evidence 8 for 1 against
claim c from all requiring 2 witnesses")))

(format t "~&~%── как это выглядит ──~%~a"
        (out-of (с-корпусом '(claim осторожно (from-all :grade>= строго) (requiring-roots 2)))))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
