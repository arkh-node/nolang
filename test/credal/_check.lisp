(load (merge-pathnames "../../src/evidence.lisp" *load-pathname*))
(defun ~= (a b) (< (abs (- a b)) 1e-9))
(defun chk (cond* msg) (format t "~&~a ~a~%" (if cond* "OK" "FAIL") msg))

;; 1. нижняя граница ЕСТЬ нынешний belief — совместимость, не совпадение
(let ((allsame t))
  (dolist (c '((0 0) (5 5) (1 0) (9 1) (20 0) (1 1) (3 7) (100 3)))
    (destructuring-bind (wp wm) c
      (multiple-value-bind (lo hi wd) (belief-interval wp wm)
        (declare (ignore hi wd))
        ;; сверяем с ТОЧНЫМ belief: во float тождество расходится на 6e-8 уже при (100,3)
        (unless (= (belief-exact wp wm) lo) (setf allsame nil)))))
  (chk allsame "нижняя граница = belief, посчитанный точно (тождество, а не совпадение)"))

;; 1b. и то же самое — против нынешнего float-belief, с допуском на его погрешность
(let ((worst 0))
  (dolist (c '((0 0) (5 5) (9 1) (20 0) (3 7) (100 3) (1000 7)))
    (destructuring-bind (wp wm) c
      (multiple-value-bind (f cc) (evidence->fc wp wm)
        (multiple-value-bind (lo) (belief-interval wp wm)
          (setf worst (max worst (abs (- (* f cc) (float lo 1.0)))))))))
  (chk (< worst 1e-6)
       (format nil "старый float-belief отличается от точного не более чем на ~,1e — это его погрешность, не наша" worst)))

;; 1c. 🔴 РЕЗУЛЬТАТ ОБЯЗАН БЫТЬ ТОЧНЫМ ЧИСЛОМ, а не float.
;; Найдено мутацией 05.08: убрал приведение к рациональным — тест прошёл, потому что
;; сверял ДВЕ функции между собой, а обе портились одинаково. Сторож обязан ловить то,
;; ради чего заведён, а не то, что удобно сравнить.
(let ((all-exact t))
  (dolist (c '((0 0) (5 5) (100 3) (1000 7)))
    (destructuring-bind (wp wm) c
      (multiple-value-bind (lo hi wd) (belief-interval wp wm)
        (unless (and (rationalp lo) (rationalp hi) (rationalp wd))
          (setf all-exact nil)))))
  (chk all-exact "границы и ширина — ТОЧНЫЕ рациональные, не float (носитель = пары весов)"))

;; 2. РАЗЛИЧЕНИЕ: одинаковый belief, разные интервалы
(multiple-value-bind (lo1 hi1) (belief-interval 1 0)      ; «скорее так, мало данных»
  (multiple-value-bind (lo2 hi2) (belief-interval 5 5)    ; «поровну, много данных»
    (declare (ignore lo1 lo2))
    (chk (not (~= hi1 hi2))
         "«мало данных» и «поровну» различимы верхней границей (0.5 vs 5/11 низа при разных верхах)")))

;; 3. незнание падает с ростом свидетельств — и только так
(let ((prev 2.0) (mono t))
  (dolist (w '(0 1 2 5 10 50))
    (let ((u (ignorance w 0)))
      (unless (< u prev) (setf mono nil))
      (setf prev u)))
  (chk mono "ширина строго убывает с ростом свидетельств"))

;; 4. «не знаю ничего» даёт весь отрезок
(multiple-value-bind (lo hi) (belief-interval 0 0)
  (chk (and (~= lo 0.0) (~= hi 1.0)) "пустое свидетельство → [0,1]: незнание не притворяется нулём"))

;; 5. граница Эйн-Соф: ширина НИКОГДА не ноль
(let ((zero nil))
  (dolist (w '(0 1 10 100 10000))
    (when (~= (ignorance w 0) 0.0) (setf zero t)))
  (chk (not zero) "ширина > 0 при любом конечном свидетельстве (c<1 структурно, AIKR)"))

;; ── ВИД ОТКАЗА ──────────────────────────────────────────────────────────────
;; Ради этого различия вера и стала отрезком: два одинаково низких результата
;; требуют противоположных действий — искать ещё или прекратить.
(chk (eq (threshold-verdict 0 0 9/10) :reachable)
     "нет данных → порог ДОСТИЖИМ (искать ещё)")
(chk (eq (threshold-verdict 50 50 9/10) :unreachable)
     "спор 50 на 50 → :unreachable (собранное исчерпано)")
;; 🔴 и сразу — чего :unreachable НЕ значит. Первая редакция утверждала «не помогут никакие
;; свидетельства»; проверка опровергла это за минуту, и теперь опровержение стоит в батарее,
;; чтобы формулировка не поехала обратно.
(chk (eq (threshold-verdict 550 50 9/10) :passed)
     ":unreachable — про СОСТОЯНИЕ ЗНАНИЯ, а не про мир: +500 свидетельств берут тот же порог")
(chk (eq (threshold-verdict 50 3 9/10) :passed)
     "хватило → :passed, решение прежнее")
(chk (eq (threshold-verdict 1 1 9/10) :unreachable)
     "спор при малых данных тоже недостижим: верх 2/3 < 9/10")
;; 🔴 и главное: старое решение НЕ ИЗМЕНИЛОСЬ ни на одном случае
(let ((same t))
  (dolist (c '((0 0) (1 0) (5 5) (9 1) (20 0) (50 3) (100 3)))
    (destructuring-bind (wp wm) c
      (let ((old (>= (belief-exact wp wm) 9/10))
            (new (eq (threshold-verdict wp wm 9/10) :passed)))
        (unless (eq old new) (setf same nil)))))
  (chk same "вид отказа НЕ МЕНЯЕТ того, кто проходит порог — только объясняет отказ"))
