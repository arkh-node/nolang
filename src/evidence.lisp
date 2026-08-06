;;;; nolang src — evidence. (f,c) <-> evidence counts; honest truth-combination.
;;;; Fixes the eval.lisp gap: `combine 'and` was used where REVISION was meant.
;;;; Foundations: NARS truth-value functions (Wang) ≅ Beta-opinion (Jøsang). Loads atom.
;;;;
;;;; Evidence view of a judgment: w+ (positive), w- (negative), w = w+ + w-.
;;;;   f = w+ / w                    frequency (how far it holds)
;;;;   c = w / (w + k)               confidence (how much evidence, vs horizon k)
;;;;   u = k / (w + k) > 0 always    ignorance — the Ein-Sof bound: c<1 is structural,
;;;;                                  only the Infinite is certain (finite evidence; cf. Wang's AIKR).

(load (merge-pathnames "atom.lisp" *load-pathname*))

(defparameter *k* 1.0
  "Evidential horizon (Beta prior weight). u = k/(w+k) > 0 ⇒ c<1 forever = the Ein-Sof bound (cf. Wang's AIKR).")

;; ── Bridge: (f,c) ↔ evidence ────────────────────────────────────────────────
(defun fc->evidence (f c &optional (k *k*))
  "(f,c) → (values w+ w-).  w = k·c/(1-c);  w+ = f·w;  w- = (1-f)·w."
  (assert (< c 1) () "Ein-Sof bound: confidence must be < 1 (got ~a)" c)
  (let* ((w  (/ (* k c) (- 1 c)))
         (w+ (* f w)))
    (values w+ (- w w+))))

(defun evidence->fc (w+ w- &optional (k *k*))
  "(w+,w-) → (values f c).  f = w+/w;  c = w/(w+k).  No evidence ⇒ (0.5, 0)."
  (let ((w (+ w+ w-)))
    (if (zerop w)
        (values 0.5 0.0)
        (values (/ w+ w) (/ w (+ w k))))))

;; ── КРЕДАЛЬНАЯ ГРАНИЦА: вера как ИНТЕРВАЛ, а не точка ───────────────────────
;; 🔴 ЗАЧЕМ (Дверь 2, 05.08.2026). `belief = f·c` схлопывает две независимые величины
;; в одну, и на гейте они становятся неразличимы:
;;     f=0.9, c=0.5  → b=0.45   «скорее так, но данных мало»
;;     f=0.45, c=1.0 → b=0.45   «примерно поровну, данных много»
;; Одно число — два разных состояния мира, и порог `b ≥ θ` не отличает их ничем.
;;
;; ЧТО ЗДЕСЬ СДЕЛАНО. Ничего не добавлено в носитель: (w+, w-, k) уже счётный и уже
;; правильный. Перестаём схлопывать его в точку и берём ОБЕ границы:
;;     низ  = w+ / (w + k)        если ВСЁ неизвестное окажется против
;;     верх = (w+ + k) / (w + k)  если ВСЁ неизвестное окажется за
;; Ширина = k/(w+k) = `u` — то самое незнание, что уже было в шапке файла как
;; граница Эйн-Соф. Оно перестаёт быть комментарием и становится величиной.
;;
;; 🔴 СОВМЕСТИМОСТЬ ПОЛНАЯ, и это не совпадение: b = f·c = (w+/w)·(w/(w+k)) = w+/(w+k),
;; то есть НЫНЕШНИЙ belief И ЕСТЬ нижняя граница. Гейт, смотрящий на `b`, смотрит на
;; низ интервала — самую осторожную оценку. Ничего не ломается; появляется то, чего
;; не было: ширина, которую можно спросить отдельно.
;;
;; Основание — imprecise beta model (Walley): для бинарного суждения кредальное
;; множество эквивалентно отрезку, а концы суть дроби с натуральными числителем и
;; знаменателем. Инвариант «ни одного вещественного» держится (АЛГЕБРА §1.1).

(defun %exact (x)
  "Точное представление: целое или дробь. Float переводим в рациональное — иначе
   интервал унаследует ошибку округления от носителя (см. ниже)."
  (if (floatp x) (rational x) x))

(defun belief-interval (w+ w- &optional (k *k*))
  "(w+,w-) → (values низ верх ширина). Вера как отрезок: положение И незнание.

   🔴 СЧИТАЕТСЯ ТОЧНО, В РАЦИОНАЛЬНЫХ. Найдено при вводе (05.08.2026): тождество
   `belief = f·c = w+/(w+k)` алгебраически ВЕРНО, но в одинарной точности расходится
   на 6·10⁻⁸ уже при w+=100, w-=3 — потому что `belief` считается в два действия через
   float, а граница в одно. Разница мала и потому опасна: она накапливается молча.
   Модель в Agda живёт на парах весов в ℕ и вещественных не знает; реализация до сих пор
   считала во float. Здесь носитель приводится к тому, чем он объявлен."
  (let* ((w+ (%exact w+)) (w- (%exact w-)) (k (%exact k))
         (w (+ w+ w-))
         (lo (/ w+ (+ w k)))
         (hi (/ (+ w+ k) (+ w k))))
    (values lo hi (- hi lo))))

(defun ignorance (w+ w- &optional (k *k*))
  "Ширина кредального отрезка = k/(w+k). Сколько ещё может изменить неизвестное.
   Точное рациональное: ширина — величина, по которой судят, а не украшение вывода."
  (let ((w+ (%exact w+)) (w- (%exact w-)) (k (%exact k)))
    (/ k (+ w+ w- k))))

(defun belief-exact (w+ w- &optional (k *k*))
  "Нынешний belief, посчитанный ТОЧНО: f·c = w+/(w+k) без промежуточного float."
  (let ((w+ (%exact w+)) (w- (%exact w-)) (k (%exact k)))
    (/ w+ (+ w+ w- k))))

;; ── ВИД ОТКАЗА: доберёшь или не доберёшь ────────────────────────────────────
;; 🔴 ЗАЧЕМ. `fold` несёт недостачу — СКОЛЬКО не хватило. Но не говорит главного:
;; можно ли добрать вообще. Два состояния дают одинаково низкую веру и требуют
;; ПРОТИВОПОЛОЖНЫХ действий:
;;     нет данных         [0.000, 1.000]  → искать ещё, порог достижим
;;     спор, 50 на 50     [0.495, 0.505]  → искать бесполезно, верх ниже порога
;; Сейчас гейт видит у обоих b≈0 и отвечает одно и то же. Агент, получивший такой
;; отказ, не знает — идти за свидетельствами или прекратить. Верхняя граница отвечает.
;;
;; Это прямое следствие того, что вера стала отрезком: нижняя граница решает,
;; ПРОЙДЕН ли порог; верхняя — МОЖЕТ ЛИ он быть пройден.

(defun threshold-verdict (w+ w- thr &optional (k *k*))
  "→ :passed | :reachable | :unreachable. ВСЕ ТРИ — о СОСТОЯНИИ ЗНАНИЯ, не о мире.

   :passed      — нижняя граница не ниже порога (решение прежнее, без изменений);
   :reachable   — порог между границами: довершение неизвестного может его взять;
   :unreachable — верхняя граница ниже порога: НИКАКАЯ доводка неизвестного в пределах
                  горизонта k не даст порога. Собранное исчерпано.

   🔴 ЧЕГО :unreachable НЕ ЗНАЧИТ — поправка к первой редакции (05.08, поймано проверкой
   собственной формулировки). Сперва здесь стояло «не помогут НИКАКИЕ свидетельства, сколько
   бы их ни пришло». Это неверно и проверяется за минуту: спор 50 на 50 при пороге 0.9 даёт
   :unreachable, но +500 свидетельств за дают [0.915, 0.917] и :passed.

   Верхняя граница — предел при благоприятном довершении ТОГО, ЧТО ЕСТЬ, а не пророчество о
   будущем. Правильное чтение: «на этих данных порог не берётся ни при какой допустимой
   интерпретации; нужны НОВЫЕ свидетельства, и в количестве, сравнимом с уже собранным».
   Практический смысл остаётся и даже становится точнее: не «прекрати искать», а
   «этот канал исчерпан — нужен другой источник или порядок величины больше того же»."
  (multiple-value-bind (lo hi) (belief-interval w+ w- k)
    (cond ((>= lo thr) :passed)
          ((< hi thr)  :unreachable)
          (t           :reachable))))

;; ── REVISION: pool independent evidence for the SAME judgment ───────────────
;; The operator that was missing. Two agreeing sources MUST raise confidence.
(defun t-revise (fa ca fb cb &optional (k *k*))
  "Revision: sum the evidence of two sources of one judgment. (values f c).
   c strictly exceeds each input's c when both carry evidence — the fix."
  (multiple-value-bind (wa+ wa-) (fc->evidence fa ca k)
    (multiple-value-bind (wb+ wb-) (fc->evidence fb cb k)
      (evidence->fc (+ wa+ wb+) (+ wa- wb-) k))))

;; ── DEDUCTION: chain a syllogism (A→B, B→C ⊢ A→C). Confidence falls. ────────
(defun t-deduce (fa ca fb cb)
  "NARS deduction (strong syllogism): f = fa·fb ; c = fa·fb·ca·cb."
  (values (* fa fb) (* fa fb ca cb)))

;; ── CONJUNCTION (and, distinct facts): NARS intersection ────────────────────
(defun t-and (fa ca fb cb)
  "f = fa·fb ; c = ca·cb.  (Correct for independent conjunction — NOT revision.)"
  (values (* fa fb) (* ca cb)))

;; ── DISJUNCTION (or): NARS union ────────────────────────────────────────────
(defun t-or (fa ca fb cb)
  "f = 1-(1-fa)(1-fb) ; c = ca·cb."
  (values (- 1 (* (- 1 fa) (- 1 fb))) (* ca cb)))

;; ── Atom-level helpers (compound judgments; %make-natom skips base-atom check) ─
(defun revise-atoms (a b)
  "Revision of two atoms asserting the SAME judgment. Raises confidence."
  (multiple-value-bind (f c) (t-revise (natom-f a) (natom-c a) (natom-f b) (natom-c b))
    (%make-natom :judgment (natom-judgment a) :f f :c c
                 :trace (format nil "revise(~a,~a)" (natom-trace a) (natom-trace b)))))
