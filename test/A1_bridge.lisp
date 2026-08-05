;;;; test/A1_bridge.lisp — КОМПЕНСАЦИЯ КАК ДЕЙСТВИЕ · МОСТ НАРУЖУ ОДНОСТОРОННИЙ.
;;;; Run: sbcl --script test/A1_bridge.lisp
;;;;
;;;; ДВА ДОЛГА ИЗ РЕДУКЦИИ §6, закрытые вместе:
;;;;   «компенсация НАЗЫВАЕТСЯ, но не совершается» — теперь совершается и попадает в журнал;
;;;;   «побочных эффектов нет; мост — одна строка в R-DO-PASS» — мост есть, и он ОДНОСТОРОННИЙ.
;;;;
;;;; 🔴 Почему односторонний — решение, а не удобство. Обработчик зовётся ПОСЛЕ решения гейта,
;;;; и его возврат отбрасывается. Иначе внешний мир менял бы провенанс задним числом:
;;;; «действие удалось, значит основание было хорошим» — отмывание через результат.
(load (merge-pathnames "../src/nolang.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun kinds (l) (mapcar #'first l))
(defun ledger-of (p) (nth-value 1 (run-nolang p)))

;;; Веса подобраны СЧЁТОМ: вдвоём b=0.675, в одиночку 0.540, порог 0.6 лежит МЕЖДУ.
(defparameter *возместимое*
  '((witness письмо "…" :grade строго :f 0.9 :c 0.6 :source (клиент))
    (witness подтв  "…" :grade строго :f 0.9 :c 0.6 :source (склад))
    (claim заказ :grade строго (from письмо подтв))
    (action отправка :reversibility compensable :requires (>= belief 0.6)
            :else fold :compensated-by отмена-отправки)
    (do отправка заказ)
    (retract подтв :reason "подтверждение оказалось не оттуда")))

(defparameter *необратимое*
  '((witness рец "…" :grade строго :f 0.9 :c 0.6 :source (журнал))
    (witness рец2 "…" :grade строго :f 0.9 :c 0.6 :source (второй))
    (claim статья :grade строго (from рец рец2))
    (action публикация :reversibility irreversible :requires (>= belief 0.6) :else fold)
    (do публикация статья)
    (retract рец2 :reason "рецензент отозвал отзыв")))

(format t "~&── КОМПЕНСАЦИЯ ТЕПЕРЬ СОВЕРШАЕТСЯ, А НЕ НАЗЫВАЕТСЯ ──~%")

(let ((k (kinds (ledger-of *возместимое*))))
  (check "действие совершено, потом осиротело" 
         (and (member :performed k) (member :orphaned k)))
  (check "🔴 и породило ШАГ ВОЗМЕЩЕНИЯ в журнале" (member :compensating k))
  (check "порядок: совершено → отозвано → осиротело → возмещено"
         (and (< (position :performed k) (position :retracted k))
              (< (position :orphaned k) (position :compensating k)))))

(check "возмещение названо тем именем, что объявлено в compensated by"
       (eq 'отмена-отправки (second (find :compensating (ledger-of *возместимое*) :key #'first))))

(format t "~&── НЕОБРАТИМОЕ ВОЗМЕЩЕНИЮ НЕ ПОДЛЕЖИТ ──~%")

(let ((k (kinds (ledger-of *необратимое*))))
  (check "осиротело — и помечено НЕПОПРАВИМЫМ" (member :irreparable k))
  (check "🔴 шага возмещения НЕТ: возмещать нечем (тест умеет падать)"
         (not (member :compensating k))))

(check "действие, выдержавшее порог после отзыва, ни сиротой, ни возмещением не становится"
       (let ((k (kinds (ledger-of
                        '((witness a "…" :grade строго :f 0.97 :c 0.93 :source (x))
                          (witness b "…" :grade строго :f 0.97 :c 0.93 :source (y))
                          (claim осн :grade строго (from a b))
                          (action шаг :reversibility compensable :requires (>= belief 0.3)
                                  :else fold :compensated-by откат)
                          (do шаг осн)
                          (retract b :reason "уточнение"))))))
         (and (not (member :orphaned k)) (not (member :compensating k)))))

(format t "~&── МОСТ: обработчик зовётся ──~%")

(let ((вызовы '()))
  (let ((*action-handler* (lambda (kind a basis b thr)
                            (push (list kind a basis b thr) вызовы))))
    (run-nolang *возместимое*))
  (setf вызовы (nreverse вызовы))
  (check "обработчик позван на совершённом действии"
         (eq :performed (first (first вызовы))))
  (check "…и на возмещении тоже"
         (member :compensating (mapcar #'first вызовы)))
  (check "ему передано имя, основание, вера и порог"
         (let ((з (first вызовы)))
           (and (eq 'отправка (second з)) (eq 'заказ (third з))
                (numberp (fourth з)) (numberp (fifth з))))))

(check "🔴 БЕЗ обработчика ядро чисто: тот же журнал, никаких эффектов"
       (equal (ledger-of *возместимое*)
              (let ((*action-handler* nil)) (ledger-of *возместимое*))))

(format t "~&── 🔴 МОСТ ОДНОСТОРОННИЙ ──~%")

;;; Обработчик возвращает что угодно и делает что угодно — склад и журнал не меняются.
(let* ((чисто-склад (store-signature (run-nolang *возместимое*)))
       (чисто-журнал (ledger-of *возместимое*))
       (с-обработчиком
         (let ((*action-handler* (lambda (k a b bel thr)
                                   (declare (ignore k a b bel thr))
                                   ;; пытаемся «сообщить об успехе» и повлиять на вывод
                                   :всё-прошло-отлично)))
           (multiple-value-list (run-nolang *возместимое*)))))
  (check "возврат обработчика ОТБРОШЕН: склад не изменился"
         (equal чисто-склад (store-signature (first с-обработчиком))))
  (check "…и журнал не изменился" (equal чисто-журнал (second с-обработчиком))))

(check "🔴 упавший обработчик не ломает прогон и не меняет исход"
       (let ((с-падением
               (let ((*action-handler* (lambda (&rest _) (declare (ignore _))
                                         (error "внешний мир упал"))))
                 (multiple-value-list (run-nolang *возместимое*)))))
         (and (equal (ledger-of *возместимое*) (second с-падением))
              (equal (store-signature (run-nolang *возместимое*))
                     (store-signature (first с-падением))))))

(format t "~&── 🔴 G2. ВОЗМЕЩЕНИЕ — ДЕЙСТВИЕ СО СВОИМ ГЕЙТОМ И СВОИМИ КОРНЯМИ ──~%")
;;; Наказ Невис, G2: «необратимое нельзя отменить — но можно совершить ВТОРОЕ действие,
;;; названное возмещением, со своим основанием и своим гейтом».
;;; 🔴 Ключевое: возмещение проходит СВОЙ порог, а не порог того, что рухнуло. Иначе оно
;;; наследовало бы чужое условие и совершалось бы «за компанию» — а у него другая цена
;;; ошибки. И возмещение может НЕ пройти: тогда это отдельная запись, а не тишина.
(defparameter *с-возмещением*
  '((witness письмо "…" :grade строго :f 0.9 :c 0.6 :source (клиент))
    (witness подтв  "…" :grade строго :f 0.9 :c 0.6 :source (склад))
    (claim заказ :grade строго (from письмо подтв))
    (action отмена-отправки :reversibility reversible :requires (>= belief 0.2) :else fold)
    (action отправка :reversibility compensable :requires (>= belief 0.6)
            :else fold :compensated-by отмена-отправки)
    (do отправка заказ)
    (retract подтв :reason "подтверждение оказалось не оттуда")))

(defparameter *возмещение-не-прошло*
  (substitute '(action отмена-отправки :reversibility reversible
                :requires (>= belief 0.95) :else fold)
              '(action отмена-отправки :reversibility reversible
                :requires (>= belief 0.2) :else fold)
              *с-возмещением* :test #'equal))

(let ((лог (ledger-of *с-возмещением*)))
  (check "возмещение — ОТДЕЛЬНАЯ запись в журнале"
         (find :compensating лог :key #'first))
  (check "🔴 …и в ней СВОЙ порог возмещения (0.2), а не порог упавшего действия (0.6)"
         (let ((e (find :compensating лог :key #'first)))
           (and e (< (fifth e) 0.6))))
  (check "🔴 …и СВОИ корни основания названы поимённо"
         (let ((e (find :compensating лог :key #'first)))
           (and e (member 'клиент (seventh e)))))
  (check "…и своя вера на момент возмещения"
         (let ((e (find :compensating лог :key #'first))) (and e (numberp (fourth e)))))
  (check "запись о сиротстве стоит РЯДОМ, а не стирается возмещением"
         (find :orphaned лог :key #'first)))

(let ((лог (ledger-of *возмещение-не-прошло*)))
  (check "🔴 возмещение, не прошедшее СВОЙ гейт, записано отдельно — а не пропущено молча"
         (find :compensation-folded лог :key #'first))
  (check "…с недостачей числом: сколько веры не хватило ИМЕННО ему"
         (let ((e (find :compensation-folded лог :key #'first)))
           (and e (> (sixth e) 0))))
  (check "…и совершённым оно при этом НЕ числится"
         (not (find :compensating лог :key #'first))))

(check "🔴 возмещение через НЕобъявленное действие — ошибка: имя ≠ действие"
       (member :unknown
               (errors-of '((witness w "…" :grade строго :f 0.9 :c 0.6 :source (r))
                            (claim c :grade строго (from w))
                            (action шаг :reversibility compensable
                                    :requires (>= belief 0.5) :else fold
                                    :compensated-by призрак)
                            (do шаг c)))))

(let ((лог (ledger-of *необратимое*)))
  (check "🔴 у НЕОБРАТИМОГО возмещения нет и не может быть: «НЕПОПРАВИМО» стоит одно"
         (and (find :irreparable лог :key #'first)
              (not (find :compensating лог :key #'first))
              (not (find :compensation-folded лог :key #'first)))))

(format t "~&── 🔴 G3. ДВА ОБРАБОТЧИКА — ПОБАЙТНО ОДИН ВЕРДИКТ ──~%")
;;; Наказ Невис, G3: ядро без эффектов, всё внешнее уходит в обработчик, который язык
;;; ВЫЗЫВАЕТ, но не СОДЕРЖИТ. Проверка сильная и простая: тот же пример под тихим и под
;;; печатающим обработчиком обязан дать один и тот же вердикт — **побайтно**.
;;; 🔴 Почему побайтно, а не «по смыслу»: сравнение по смыслу пришлось бы кому-то определять,
;;; и это определение стало бы вторым местом, где живёт семантика. Байты определять не надо.
(defparameter *след* '())

(defun вердикт-под (обработчик src)
  "Текст вердиктов при заданном обработчике. Обработчик пишет в сторону — в СЛЕД, не в склад."
  (let ((*action-handler* обработчик))
    (with-output-to-string (*standard-output*)
      (multiple-value-bind (st lg) (run-nolang src)
        (show-run st lg)))))

(let* ((тихо (вердикт-под nil *возместимое*))
       (шумно (вердикт-под (lambda (вид действие основание вера порог)
                             (push (list вид действие основание вера порог) *след*)
                             (format *error-output* "внешний мир: ~a ~a~%" вид действие)
                             :этот-возврат-будет-отброшен)
                           *возместимое*)))
  (check "🔴 вердикт под тихим и под печатающим обработчиком СОВПАДАЕТ побайтно"
         (string= тихо шумно))
  (check "…и это не пустая строка (сравнивать было что)"
         (> (length тихо) 200))
  (check "обработчик ДЕЙСТВИТЕЛЬНО звался — иначе сравнение ничего не стоит"
         (plusp (length *след*)))
  (check "…и звался на совершении и на возмещении, а не только на одном"
         (> (length (remove-duplicates (mapcar #'first *след*))) 1))
  (check "🔴 возврат обработчика отброшен: склад от него не зависит"
         (let ((*action-handler* (lambda (&rest _) (declare (ignore _)) :ложь-снаружи)))
           (string= тихо (вердикт-под (lambda (&rest _) (declare (ignore _)) :ложь-снаружи)
                                      *возместимое*)))))

(check "🔴 УПАВШИЙ внешний мир не меняет вывод — устойчивость здесь ЧЕСТНОСТЬ, не надёжность"
       (string= (вердикт-под nil *возместимое*)
                (вердикт-под (lambda (&rest _) (declare (ignore _))
                               (error "внешний мир упал"))
                             *возместимое*)))

(format t "~&~%── журнал возмещения ──~%")
(show-ledger (ledger-of *возместимое*))
(format t "~%── журнал непоправимого ──~%")
(show-ledger (ledger-of *необратимое*))

(format t "~&── 🔴 РАЗРЕШЕНИЕ И ЕГО ОТЗЫВ: ТРЕТЬЯ ОСЬ, ЧЕТВЁРТЫЙ СТАТУС ──~%")
;;; Разрешение НЕ на решётке основания: свидетельство отвечает «что есть», разрешение —
;;; «что можно». Отзыв права основания не трогает: вера прежняя, свидетели целы, а действие
;;; стало НЕПРАВОМЕРНЫМ. Доказано: `formal/Act.agda` — `revoke-keeps-typing`, `orphan-outranks`,
;;; `no-perm-never-unauthorized`.
(defparameter *с-правом*
  '((witness w "…" :grade строго :f 0.9 :c 0.6 :source (r1))
    (witness w2 "…" :grade строго :f 0.9 :c 0.6 :source (r2))
    (claim осн :grade строго (from w w2))
    ;; 🔴 С 30.07 объявление действия несёт ТРЕБОВАНИЕ права («кто вправе»), а само право
    ;; предъявляется в программе формой `permit` — симметрично `revoke`, который всегда там
    ;; и жил. Проверяемое свойство прежнее: отзыв даёт ЧЕТВЁРТЫЙ статус, не осиротение.
    (action пуш :reversibility irreversible :needs-grade строго
            :needs-permission Алексей
            :requires (>= belief 0.5) :else fold)
    (permit пуш :quote "пуш разрешаю" :who Алексей :at "2026-07-29T01:37 стр.12")
    (do пуш осн)
    (revoke Алексей :reason "передумал")))

(let ((лог (ledger-of *с-правом*)))
  (check "🔴 отзыв права даёт ЧЕТВЁРТЫЙ статус — неправомерность"
         (find :unauthorized лог :key #'first))
  (check "…и это НЕ осиротение: основание цело"
         (not (find :orphaned лог :key #'first)))
  (check "…вера в вердикте прежняя, выше порога — рухнуло ПРАВО, а не опора"
         (let ((e (find :unauthorized лог :key #'first)))
           (and e (>= (fourth e) (fifth e)))))
  (check "…и цитата, на которую ссылались, названа"
         (search "пуш разрешаю"
                 (with-output-to-string (*standard-output*) (show-ledger лог))))
  (check "запись об отзыве права стоит отдельно от записи о совершении"
         (and (find :revoked лог :key #'first) (find :performed лог :key #'first))))

(format t "~&── проверки на отзыв: три случая ──~%")

(check "(1) отзыв того, чего никто не давал — :unknown"
       (member :unknown (errors-of '((revoke Алексей :reason "…")))))
(check "🔴 (2) отзыв ЧУЖОГО разрешения — НЕ :unknown, а отдельная ошибка права"
       (member :authority
               (errors-of (append (butlast *с-правом* 2)
                                  '((revoke Эмма :reason "…"))))))
(check "…и сообщение объясняет, что право распоряжаться чужим словом само есть право"
       (let ((e (find :authority (nth-value 1 (check-program
                                              (append (butlast *с-правом* 2)
                                                      '((revoke Эмма :reason "…")))))
                      :key #'terr-code)))
         (and e (search "кто дал, тот и отзывает" (terr-text e)))))
(check "🔴 (3) отзыв ПОСЛЕ совершения назван фактом о прошлом, а не запретом"
       (let ((e (find :runtime (nth-value 1 (check-program *с-правом*)) :key #'terr-code)))
         (and e (search "факт о прошлом" (terr-text e))
              (search "Основание при этом ЦЕЛО" (terr-text e)))))
(check "наружу без разрешения не разбирается вовсе (11-е незаписываемое состояние)"
       (not (parse-ok? "lattice L = a < b
irreversible outward action пуш needs grade >= b gated by belief >= 0.5 else fold")))
(check "…а внутрь — законно без разрешения"
       (parse-ok? "lattice L = a < b
irreversible internal action ротация needs grade >= b gated by belief >= 0.5 else fold"))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
