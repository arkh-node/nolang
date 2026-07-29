;;;; test/C1_modules.lisp — МОДУЛИ: импорт корпуса с чужой шкалой.
;;;; Run: sbcl --script test/C1_modules.lisp
;;;;
;;;; ПОВОД (наказ Невис 29.07, раздел A). Когда корпус становится импортируемой библиотекой,
;;;; встаёт вопрос: чья решётка главная. Ответ: степень назначает ИСТОЧНИК, импортёр объявляет
;;;; отображение `φ` и может только понижать. Она же доказала (formal/ModuleImport.agda), ЧТО
;;;; именно обязано выполняться для φ: сохранение грани и дна — причём сохранение грани
;;;; РАВНОСИЛЬНО перестановочности «отобразить/свернуть», а не просто достаточно для неё.
;;;;
;;;; 🔴 ЦЕНА, КОТОРУЮ ЗДЕСЬ НАДО НАЗВАТЬ ВСЛУХ (её слова, и тест их проверяет СЧЁТОМ):
;;;; пока решётка ЛИНЕЙНА, условие выполняется даром — в линейном порядке грань есть минимум,
;;;; и всякое монотонное отображение её сохраняет. Условие начинает резать ровно тогда, когда
;;;; решётки стали ПРОИЗВЕДЕНИЯМИ. Это цена за произведение, а не подарок.
;; нужны ОБА слоя: разбор (A1 — незаписываемость импорта без φ) и машина (A3, A4)
(load (merge-pathnames "../src/reduce.lisp" *load-pathname*))
(load (merge-pathnames "../src/parse.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun ~= (a b &optional (eps 1e-4)) (< (abs (- a b)) eps))
(defun imp-errs (forms) (errors-of forms '(:import)))
(defun out-of (forms)
  (multiple-value-bind (st lg) (run-nolang forms)
    (with-output-to-string (*standard-output*) (show-run st lg))))

;;; ── общая обстановка: чужая шкала МЕД, своя ЧЕСТНОСТЬ ───────────────────────
(defparameter *прелюдия*
  '((lattice мед ничего слабое среднее сильное)
    (lattice честность молчание образ традиция строго)))

(defparameter *φ-верное*
  '((ничего . молчание) (слабое . образ) (среднее . традиция) (сильное . строго)))

(defun с-импортом (phi &rest формы)
  (append *прелюдия* (list `(import испытания :lattice мед :phi ,phi)) формы))

(format t "~&── A1. СИНТАКСИС: импорт без φ НЕЗАПИСЫВАЕМ ──~%")

(defparameter *текст*
  "lattice MED = ничего < слабое < среднее < сильное
lattice HON = молчание < образ < традиция < строго
import ИСПЫТАНИЯ lattice MED via ничего -> молчание, слабое -> образ,
                                 среднее -> традиция, сильное -> строго
witness t1 of ИСПЫТАНИЯ : сильное says \"рандомизированное\" source кокрейн
  evidence 9 for 1 against
claim вывод from t1")

(check "программа с двумя решётками и импортом разбирается" (parse-ok? *текст*))
(check "🔴 импорт БЕЗ φ — ошибка РАЗБОРА, а не проверки"
       (not (parse-ok? "lattice MED = a < b
import M lattice MED")))
(check "…и ошибка говорит про `via`, а не про абстрактный синтаксис"
       (search "via" (parse-error-of "lattice MED = a < b
import M lattice MED")))
(check "импорт без имени решётки источника — тоже ошибка разбора"
       (not (parse-ok? "lattice MED = a < b
import M via a -> образ")))
(check "φ разбирается в таблицу пар"
       (let ((imp (find-if (lambda (f) (string= (head-of f) "import")) (parse *текст*))))
         (and imp (= 4 (length (kw imp :phi)))
              (equal '(ничего . молчание)
                     (let ((r (first (kw imp :phi))))
                       (cons (intern (string (car r))) (intern (string (cdr r)))))))))
(check "`witness … of МОДУЛЬ` несёт метку модуля"
       (let ((w (find-if (lambda (f) (string= (head-of f) "witness")) (parse *текст*))))
         (string-equal (string (kw w :module)) "ИСПЫТАНИЯ")))
(check "свидетель без `of` метки не несёт — импорт не навязывается всем"
       (null (kw (first (parse "witness w : образ says \"…\" source s evidence 1 for 0 against"))
                 :module)))

(format t "~&── A2. УСЛОВИЯ φ ПРОВЕРЯЮТСЯ ПЕРЕБОРОМ ──~%")

(check "верное φ принимается: ни одной ошибки импорта"
       (null (imp-errs (с-импортом *φ-верное*))))
(check "🔴 неполная таблица отвергается (степень без образа)"
       (member :import (imp-errs (с-импортом (rest *φ-верное*)))))
(check "…и называет ПРОПУЩЕННУЮ степень"
       (let ((e (first (nth-value 1 (check-program (с-импортом (rest *φ-верное*)))))))
         (search "ничего" (terr-text e))))
(check "чужой ключ в таблице отвергается"
       (member :import (imp-errs (с-импортом (cons '(лишнее . образ) *φ-верное*)))))
(check "значение вне решётки импортёра отвергается"
       (member :import (imp-errs (с-импортом (substitute '(сильное . сильное)
                                                         '(сильное . строго)
                                                         *φ-верное* :test #'equal)))))
(check "🔴 φ, не сохраняющее ДНО, отвергается"
       (member :import (imp-errs (с-импортом (substitute '(ничего . образ) '(ничего . молчание)
                                                         *φ-верное* :test #'equal)))))
(check "…и объясняет ИМЕННО дно, а не грань"
       (let ((e (first (nth-value 1 (check-program
                                     (с-импортом (substitute '(ничего . образ) '(ничего . молчание)
                                                             *φ-верное* :test #'equal)))))))
         (search "дно" (terr-text e))))
(check "🔴 φ ПОДНИМАЮЩЕЕ (не монотонное) отвергается"
       (member :import (imp-errs (с-импортом '((ничего . молчание) (слабое . строго)
                                               (среднее . традиция) (сильное . образ))))))
(check "…и называет ПАРУ, на которой сломалось"
       (let ((e (find :import (nth-value 1 (check-program
                                            (с-импортом '((ничего . молчание) (слабое . строго)
                                                          (среднее . традиция) (сильное . образ)))))
                      :key #'terr-code)))
         (and (search "паре" (terr-text e)) (search "слабое" (terr-text e)))))
(check "необъявленная решётка источника — ошибка с указанием порядка"
       (let ((e (find :import (nth-value 1 (check-program
                                            (append *прелюдия*
                                                    '((import м :lattice нетуть
                                                              :phi ((a . образ)))))))
                      :key #'terr-code)))
         (and e (search "ДО импорта" (terr-text e)))))
(check "🔴 импорт решётки в неё же — пойман как ошибка ПОРЯДКА"
       (let ((e (find :import (nth-value 1 (check-program
                                            (list '(lattice честность молчание образ традиция строго)
                                                  '(lattice мед ничего слабое среднее сильное)
                                                  `(import испытания :lattice мед :phi ,*φ-верное*))))
                      :key #'terr-code)))
         (and e (search "ПОСЛЕДНЯЯ объявленная" (terr-text e)))))
(check "свидетель из неимпортированного модуля — ошибка"
       (member :import (imp-errs
                        (append *прелюдия*
                                '((witness w "…" :grade строго :f 0.9 :c 0.6
                                   :source (кокрейн) :module призрак)
                                  (claim вывод (from w)))))))
(check "степень свидетеля не из решётки модуля — ошибка степени"
       (member :grade (errors-of (с-импортом *φ-верное*
                                             '(witness w "…" :grade строго :f 0.9 :c 0.6
                                               :source (кокрейн) :module испытания)
                                             '(claim вывод (from w)))
                                 '(:grade))))

(format t "~&── A2-bis. ЦЕНА ПРОИЗВЕДЕНИЯ, ПОСЧИТАННАЯ ──~%")
;;; Прямой перебор, НЕ через проверяющий: здесь проверяется математическое утверждение
;;; Невис, а не наша реализация. Если бы считал тот же код, что проверяет, счёт был бы
;;; пустым — он подтверждал бы сам себя.
(defun чепь (n) (list :linear (loop for i below n collect (intern (format nil "G~a" i) :keyword))))
(defun все-отображения (src dst)
  "Все φ: элементы src → элементы dst, сохраняющие дно. → список таблиц."
  (let* ((se (lat-elements src)) (de (lat-elements dst))
         (bot-s (g-bot-of src)) (bot-d (g-bot-of dst))
         (свободные (remove bot-s se :test #'equal)))
    (labels ((rec (xs)
               (if (null xs)
                   (list (list (cons bot-s bot-d)))
                   (loop for tl in (rec (rest xs))
                         append (loop for v in de collect (cons (cons (first xs) v) tl))))))
      (rec свободные))))
(defun φ-таб (phi g) (cdr (assoc g phi :test #'equal)))
(defun монотонно-p (src dst phi)
  (let ((se (lat-elements src)))
    (every (lambda (a)
             (every (lambda (b)
                      (or (not (equal (g-meet-in src a b) a))       ; a ⊑ b ?
                          (equal (g-meet-in dst (φ-таб phi a) (φ-таб phi b)) (φ-таб phi a))))
                    se))
           se)))
(defun грань-сохраняет-p (src dst phi)
  (let ((se (lat-elements src)))
    (every (lambda (a)
             (every (lambda (b)
                      (equal (φ-таб phi (g-meet-in src a b))
                             (g-meet-in dst (φ-таб phi a) (φ-таб phi b))))
                    se))
           se)))

(let* ((линейная (чепь 3)) (цель (чепь 4))
       (моно (remove-if-not (lambda (p) (монотонно-p линейная цель p))
                            (все-отображения линейная цель)))
       (сохр (remove-if-not (lambda (p) (грань-сохраняет-p линейная цель p)) моно)))
  (check "🔴 на ЛИНЕЙНОЙ решётке условие даром: ВСЕ монотонные φ сохраняют грань"
         (and (> (length моно) 1) (= (length моно) (length сохр))))
  (format t "      [линейная 3→4: монотонных ~a, из них сохраняют грань ~a]~%"
          (length моно) (length сохр)))

(let* ((произв (list :product (чепь 2) (чепь 2))) (цель (чепь 4))
       (моно (remove-if-not (lambda (p) (монотонно-p произв цель p))
                            (все-отображения произв цель)))
       (сохр (remove-if-not (lambda (p) (грань-сохраняет-p произв цель p)) моно)))
  (check "🔴 на ПРОИЗВЕДЕНИИ условие РЕЖЕТ: монотонности уже недостаточно"
         (and (> (length моно) (length сохр)) (> (length сохр) 0)))
  (format t "      [произведение 2×2→4: монотонных ~a, из них сохраняют грань ~a — ~
                    отсекается ~a]~%"
          (length моно) (length сохр) (- (length моно) (length сохр))))

;;; …и то же самое на языке, а не на голой решётке: монотонное, но не сохраняющее грань φ
;;; обязано быть отвергнуто проверяющим.
(defparameter *произведение*
  '((lattice сила слабо сильно)
    (lattice передача шатко твёрдо)
    (lattice источник :product сила передача)
    (lattice честность молчание образ традиция строго)))
(defun с-произведением (phi &rest формы)
  (append *произведение* (list `(import корпус :lattice источник :phi ,phi)) формы))

(defparameter *φ-пары-верное*                      ; φ(a,b) = min(f a, g b) — грань сохраняет
  '(((слабо шатко) . молчание) ((слабо твёрдо) . молчание)
    ((сильно шатко) . образ)   ((сильно твёрдо) . строго)))
(defparameter *φ-пары-монотонное-но-ложное*        ; монотонно, грань НЕ сохраняет
  '(((слабо шатко) . молчание) ((слабо твёрдо) . традиция)
    ((сильно шатко) . образ)   ((сильно твёрдо) . строго)))

(check "на произведении верное φ принимается"
       (null (imp-errs (с-произведением *φ-пары-верное*))))
(check "🔴 монотонное, но не сохраняющее грань φ — ОТВЕРГНУТО проверяющим"
       (member :import (imp-errs (с-произведением *φ-пары-монотонное-но-ложное*))))
(check "…и это то же самое φ, что прошло бы на линейной решётке (проверено выше счётом)"
       (монотонно-p (list :product '(:linear (:СЛАБО :СИЛЬНО)) '(:linear (:ШАТКО :ТВЁРДО)))
                    '(:linear (:МОЛЧАНИЕ :ОБРАЗ :ТРАДИЦИЯ :СТРОГО))
                    '(((:СЛАБО :ШАТКО) . :МОЛЧАНИЕ) ((:СЛАБО :ТВЁРДО) . :ТРАДИЦИЯ)
                      ((:СИЛЬНО :ШАТКО) . :ОБРАЗ)   ((:СИЛЬНО :ТВЁРДО) . :СТРОГО))))

(format t "~&── A3. КОРЕНЬ ГРАНИЦУ ПРОХОДИТ НЕИЗМЕННЫМ ──~%")

(defparameter *один-свой*
  (с-импортом *φ-верное*
              '(witness свой "…" :grade строго :f 0.9 :c 0.6 :source (кокрейн))
              '(claim вывод (from свой))))
(defparameter *свой+чужой-один-корень*
  (с-импортом *φ-верное*
              '(witness свой  "…" :grade строго  :f 0.9 :c 0.6 :source (кокрейн))
              '(witness чужой "…" :grade сильное :f 0.9 :c 0.6 :source (кокрейн)
                :module испытания)
              '(claim вывод (from свой чужой))))
(defparameter *свой+чужой-разные-корни*
  (с-импортом *φ-верное*
              '(witness свой  "…" :grade строго  :f 0.9 :c 0.6 :source (кокрейн))
              '(witness чужой "…" :grade сильное :f 0.9 :c 0.6 :source (эмбейз)
                :module испытания)
              '(claim вывод (from свой чужой))))

(check "🔴 свой и импортированный свод ОДНОГО корня складываются РОВНО ОДИН раз"
       (~= (belief-at-runtime *свой+чужой-один-корень* 'вывод)
           (belief-at-runtime *один-свой* 'вывод)))
(check "…а разные корни через границу усиливают, как и должны"
       (> (belief-at-runtime *свой+чужой-разные-корни* 'вывод)
          (belief-at-runtime *один-свой* 'вывод)))
(check "тест не пустой: разница между случаями существенна"
       (> (- (belief-at-runtime *свой+чужой-разные-корни* 'вывод)
             (belief-at-runtime *свой+чужой-один-корень* 'вывод))
          0.05))
(check "имя корня φ не переименовала: в свёртке стоит ИСХОДНЫЙ источник"
       (let ((v (gethash 'вывод (run-nolang *свой+чужой-разные-корни*))))
         (and (member 'кокрейн (jv-roots v)) (member 'эмбейз (jv-roots v)))))
(check "φ понизила степень чужого свидетеля по таблице, а не по имени"
       (eq (grade-at-runtime (с-импортом *φ-верное*
                                         '(witness чужой "…" :grade среднее :f 0.9 :c 0.6
                                           :source (эмбейз) :module испытания)
                                         '(claim вывод (from чужой)))
                             'вывод)
           :ТРАДИЦИЯ))
(check "статика и прогон на импорте сходятся"
       (eq (grade-of *свой+чужой-разные-корни* 'вывод)
           (grade-at-runtime *свой+чужой-разные-корни* 'вывод)))

(format t "~&── A4. РАСХОЖДЕНИЕ МЕЖДУ КОРПУСАМИ — ОТДЕЛЬНАЯ ЗАПИСЬ ──~%")

(defparameter *спор-между-корпусами*
  (с-импортом *φ-верное*
              '(witness свой  "…" :grade строго  :f 0.9 :c 0.6 :source (кокрейн))
              '(witness чужой "…" :grade сильное :f 0.4 :c 0.6 :source (кокрейн)
                :module испытания)
              '(claim вывод (from свой чужой))))
(defparameter *спор-внутри-корпуса*
  (с-импортом *φ-верное*
              '(witness чужой1 "…" :grade сильное :f 0.9 :c 0.6 :source (кокрейн)
                :module испытания)
              '(witness чужой2 "…" :grade сильное :f 0.4 :c 0.6 :source (кокрейн)
                :module испытания)
              '(claim вывод (from чужой1 чужой2))))

(defun метки (forms)
  (mapcar #'second (jv-collapsed (gethash 'вывод (run-nolang forms)))))

(check "🔴 расхождение в корне МЕЖДУ корпусами помечено спорной передачей"
       (member :спорная-передача (метки *спор-между-корпусами*)))
(check "…и НЕ помечено обычным расхождением: случаи не слиты"
       (not (member :расхождение (метки *спор-между-корпусами*))))
(check "расхождение внутри ОДНОГО корпуса остаётся обычным расхождением"
       (and (member :расхождение (метки *спор-внутри-корпуса*))
            (not (member :спорная-передача (метки *спор-внутри-корпуса*)))))
(check "запись называет ОБА корпуса, а не только чужой"
       (let ((cl (find :спорная-передача (jv-collapsed (gethash 'вывод (run-nolang
                                                                       *спор-между-корпусами*)))
                       :key #'second)))
         (and (member 'испытания (fourth cl)) (member :здешний (fourth cl)))))
(check "и это ВИДНО в печати, а не только в структуре"
       (search "СПОРНАЯ ПЕРЕДАЧА" (out-of *спор-между-корпусами*)))
(check "согласные своды одного корня спорной передачей НЕ объявляются"
       (not (member :спорная-передача (метки *свой+чужой-один-корень*))))

(format t "~&── ИМПОРТ НЕ ЛОМАЕТ ДОКАЗАННОГО ──~%")

(check "🔴 перестановка объявлений склада не меняет (perm-inv через границу модуля)"
       (let* ((хвост '((witness свой  "…" :grade строго  :f 0.9 :c 0.6 :source (кокрейн))
                       (witness чужой "…" :grade сильное :f 0.8 :c 0.5 :source (эмбейз)
                        :module испытания)
                       (ask пусто :in (реестр) :reason "не искали дальше")
                       (claim вывод (from свой чужой) (searched пусто))))
              (голова (append *прелюдия* (list `(import испытания :lattice мед
                                                        :phi ,*φ-верное*))))
              (a (store-signature (run-nolang (append голова хвост))))
              (b (store-signature (run-nolang (append голова (list (second хвост) (first хвост)
                                                                   (third хвост) (fourth хвост)))))))
         (equal a b)))

(let ((ok t) (сошлось 0))
  (dotimes (i 120)
    (let* ((степени '(ничего слабое среднее сильное))
           (ws (loop for k below (1+ (mod i 3))
                     collect `(witness ,(intern (format nil "W~a" k))
                                       "…" :grade ,(nth (mod (+ i k) 4) степени)
                                       :f ,(/ (+ 3 (mod (* 7 (+ i k)) 7)) 10.0) :c 0.6
                                       :source (,(intern (format nil "R~a" (mod (+ i k) 2))))
                                       :module испытания)))
           (cid (intern (format nil "C~a" i)))
           (prog* (append (с-импортом *φ-верное*) ws
                          (list `(claim ,cid (from ,@(mapcar #'second ws)))))))
      (if (eq (grade-of prog* cid) (grade-at-runtime prog* cid))
          (incf сошлось)
          (setf ok nil))))
  (check "120 случайных программ с импортом: статика = прогон" ok)
  (check "…и все 120 действительно прогнаны (счётом в этом же прогоне)"
         (progn (format t "      [сошлось: ~a из 120]~%" сошлось) (= сошлось 120))))

(format t "~&~%── как это выглядит ──~%~a" (out-of *спор-между-корпусами*))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
