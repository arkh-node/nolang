;;;; test/99_theta.lisp — ПОРОГ ВЫВОДИТСЯ, А НЕ НАЗНАЧАЕТСЯ.
;;;; Run: sbcl --script test/99_theta.lisp
;;;;
;;;; ПОВОД (Невис, §4 записки 28.07): три линии отвечают на РАЗНЫЕ вопросы, а не спорят за одну роль.
;;;;   Arrow–Fisher (1974) — ЧТО ЗНАЧИТ порог (премия за необратимость).
;;;;   Conformal risk control — КАК ЕГО ВЫСТАВИТЬ, не веря своим числам.
;;;;   Chow (1970) — предок вопроса, но требует КАЛИБРОВАННОЙ вероятности; наша `c` не
;;;;     калибрована по построению (граница Эйн-Соф). В фундамент не берём.
(load (merge-pathnames "../src/nolang.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun ~= (a b &optional (eps 1e-3)) (< (abs (- a b)) eps))

(format t "~&── I. СМЫСЛ: пределы вывода ──~%")

;;; θ = L/(G(1−K)+L), K = δλ/(1−δ(1−λ)). Каждый предел проверяется отдельно —
;;; именно проверка пределов поймала ошибку в страже знаменателя при первом наброске.
(check "λ=0 (ожидание не приносит сведений) → классический L/(G+L)"
       (~= (theta-derived 1.0 1.0 0.0 0.9) 0.5))
(check "δ=0 (будущее ничего не стоит) → тот же классический порог"
       (~= (theta-derived 1.0 1.0 0.5 0.0) 0.5))
(check "🔴 λ=1, δ=1 (даровое точное знание) → θ=1: необратимое НЕ оправдано никогда"
       (~= (theta-derived 1.0 1.0 1.0 1.0) 1.0))
(check "L→0 (потеря ничтожна) → θ→0" (< (theta-derived 1.0 0.01 0.5 0.9) 0.06))
(check "L≫G (потеря велика) → θ→1" (> (theta-derived 1.0 20.0 0.3 0.9) 0.98))
(check "θ всегда в [0,1] (200 случайных наборов)"
       (let ((ok t))
         (dotimes (i 200)
           (let ((th (theta-derived (+ 0.1 (random 5.0)) (+ 0.1 (random 5.0))
                                    (random 1.0) (random 1.0))))
             (unless (and (<= 0 th) (<= th 1.0)) (setf ok nil))))
         ok))

(format t "~&── МОНОТОННОСТИ, которых требует смысл ──~%")

(check "растёт потеря — растёт порог"
       (let ((ok t))
         (loop for l from 0.5 to 5.0 by 0.5
               for prev = -1 then th
               for th = (theta-derived 1.0 l 0.4 0.9)
               do (when (< th prev) (setf ok nil)))
         ok))
(check "🔴 растёт ценность ожидания λ — растёт порог (вот она, премия за необратимость)"
       (let ((ok t))
         (loop for lam from 0.0 to 0.9 by 0.1
               for prev = -1 then th
               for th = (theta-derived 1.0 1.0 lam 0.9)
               do (when (< th prev) (setf ok nil)))
         ok))
(check "растёт выигрыш — падает порог (рисковать становится осмысленнее)"
       (> (theta-derived 1.0 1.0 0.4 0.9) (theta-derived 5.0 1.0 0.4 0.9)))

(format t "~&── ГРАНИЦА ЭЙН-СОФ РАБОТАЕТ И ЗДЕСЬ ──~%")

;;; b = f·c < 1 структурно (доказано, BeliefMass.agda: b<1). Значит θ=1 недостижим.
(check "θ=1 не может быть пройден ни одной верой: политика «ждать полной уверенности» не действует"
       (let ((th (theta-derived 1.0 1.0 1.0 1.0)))
         (every (lambda (fc) (< (* (first fc) (second fc)) th))
                '((0.999 0.999) (0.9999 0.9999) (1.0 0.99999)))))

(format t "~&── II. ПРОЦЕДУРА: conformal по журналу ──~%")

;;; 🔴 Гарантия conformal МАРГИНАЛЬНАЯ (в среднем по калибровочной выборке). Сравнивать
;;; голую долю с α нельзя — нужен допуск на случайность. Первая редакция этого теста
;;; объявила метод нарушенным при доле 0.0510 против α=0.05; это было 0.4σ, то есть ШУМ.
;;; Тест врал, не метод. Теперь допуск 3σ и он назван.
(defun доля-прошедших (alpha n-trials n-new)
  (let ((всего 0) (прошло 0))
    (dotimes (trial n-trials)
      (let* ((калибровка (loop repeat 60 collect (random 1.0)))
             (th (theta-conformal калибровка alpha)))
        (dotimes (i n-new) (incf всего) (when (>= (random 1.0) th) (incf прошло)))))
    (values (/ (float прошло) всего) всего)))

(dolist (alpha '(0.05 0.10 0.20))
  (multiple-value-bind (доля n) (доля-прошедших alpha 800 20)
    (let ((предел (+ alpha (* 3 (sqrt (/ (* alpha (- 1 alpha)) n))))))
      (check (format nil "α=~,2f: доля ложных, прошедших гейт = ~,4f ≤ 3σ-предела ~,4f"
                     alpha доля предел)
             (<= доля предел)))))

(check "🔴 пустая калибровка → θ=1: отказ, а не догадка"
       (~= (theta-conformal '() 0.1) 1.0))
(check "…и мало данных → тоже отказ (та же дисциплина, что у пустой посылочной базы: ∅↦⊥)"
       (~= (theta-conformal '(0.3 0.7) 0.05) 1.0))
(check "чем строже α, тем выше порог"
       (let ((выборка (loop for i from 1 to 100 collect (/ i 100.0))))
         (>= (theta-conformal выборка 0.05) (theta-conformal выборка 0.30))))

(format t "~&── III. ВМЕСТЕ: побеждает осторожнейший ──~%")

(check "theta-both берёт более строгий из двух"
       (let ((выборка (loop for i from 1 to 100 collect (/ i 100.0))))
         (~= (theta-both 1.0 1.0 0.4 0.9 выборка 0.05)
             (max (theta-derived 1.0 1.0 0.4 0.9) (theta-conformal выборка 0.05)))))

(format t "~&── IV. ЯЗЫК УМЕЕТ ОБЪЯВИТЬ ПОРОГ ВЫВОДИМЫМ ──~%")

(defparameter *исходник* "
irreversible action publish
  needs grade >= образ
  gated by belief >= derived gain 1 loss 4 learn 0.6 discount 0.9
  else fold
")

(check "derived-порог разбирается" (parse-ok? *исходник*))
(check "θ посчитан при разборе и совпадает с формулой"
       (~= (third (getf (cddr (first (parse *исходник*))) :requires))
           (theta-derived 1.0 4.0 0.6 0.9)))
(check "🔴 вывод ОСТАЁТСЯ в форме — читатель видит, из чего порог получился"
       (equal '(1 4 0.6 0.9) (getf (cddr (first (parse *исходник*))) :theta-from)))
(check "неполный вывод не разбирается: нельзя назвать выигрыш и умолчать о потере"
       (not (parse-ok? "irreversible action p needs grade >= образ gated by belief >= derived gain 1 else fold")))
(check "числом порог назначить по-прежнему можно — вывод не обязателен, а предпочтителен"
       (parse-ok? "irreversible action p needs grade >= образ gated by belief >= 0.9 else fold"))

(format t "~&── что видит читатель ──~%")
(format t "  gain 1 · loss 4 · learn 0.6 · discount 0.9  →  θ = ~,3f~%"
        (theta-derived 1.0 4.0 0.6 0.9))
(format t "  та же цена ошибки, но ожидание бесполезно (learn 0) →  θ = ~,3f~%"
        (theta-derived 1.0 4.0 0.0 0.9))
(format t "  разница ~,3f и есть премия за необратимость (Эрроу–Фишер)~%"
        (- (theta-derived 1.0 4.0 0.6 0.9) (theta-derived 1.0 4.0 0.0 0.9)))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
