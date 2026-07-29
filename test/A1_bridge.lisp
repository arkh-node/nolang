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

(format t "~&~%── журнал возмещения ──~%")
(show-ledger (ledger-of *возместимое*))
(format t "~%── журнал непоправимого ──~%")
(show-ledger (ledger-of *необратимое*))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
