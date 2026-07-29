;;;; nolang src — query. ЗАПРОСЫ К СКЛАДУ (ступень 3 роста; наказ Невис, раздел E).
;;;;
;;;; 🔴 ЗАЧЕМ ЭТО ЯЗЫКУ, А НЕ ПРОСМОТРЩИКУ. Склад хранит основание каждого утверждения —
;;;; но хранить и уметь СПРОСИТЬ суть разные вещи. Память, в которую нельзя послать вопрос,
;;;; есть архив, а не память. Пять вопросов ниже — те, что возникают у человека, который
;;;; собирается что-то сделать или что-то отозвать:
;;;;   1. на чём стоит X            — провенанс вниз, до корней
;;;;   2. что опирается на Y        — провенанс ВВЕРХ: цена отзыва, посчитанная ДО отзыва
;;;;   3. что осиротело             — где основание рухнуло ПОСЛЕ действия
;;;;   4. где опорное молчание      — где вывод стоит на «мы не нашли»
;;;;   5. какие корни повторяются   — где ложное усиление уже предотвращено свёрткой
;;;;
;;;; 🔴 ВЫВОД — ЧЕЛОВЕКУ, НЕ В JSON (её слово). Не из вкуса: ответ, годный машине, читают
;;;; глазами один раз и потом верят ему на слово. Ответ, написанный человеку, приходится
;;;; прочесть.
;;;;
;;;; 🔴 ЗАКОН ОХВАТА (E2): ВСЯКИЙ ответ обязан сказать, ГДЕ искал и ЧЕГО не нашёл.
;;;; Это тот же закон, что для утверждений, повёрнутый на сам вопросник. Пустой ответ без
;;;; охвата — худший вид лжи: «ничего нет» и «я не искал» выглядят одинаково. Поэтому
;;;; отдельного способа напечатать ответ БЕЗ охвата здесь нет и не будет.

(load (merge-pathnames "reduce.lisp" *load-pathname*))

(defstruct (ans (:constructor ans (вопрос строки где-искал чего-нет)))
  вопрос строки где-искал чего-нет)

(defun q-count (store pred)
  (let ((k 0)) (maphash (lambda (id v) (declare (ignore id)) (when (funcall pred v) (incf k))) store) k))

(defun q-judgements (store)
  (let ((out '()))
    (maphash (lambda (id v) (when (jv-p v) (push (cons id v) out))) store)
    (sort out #'string< :key (lambda (x) (string (car x))))))

;;; ── 1. НА ЧЁМ СТОИТ X ───────────────────────────────────────────────────────
(defun q-basis (store id &optional (глубина 0) (видели '()))
  "Провенанс вниз: посылки, их посылки, и так до корней и молчаний."
  (let ((v (gethash id store)) (отступ (make-string (* 2 глубина) :initial-element #\Space)))
    (cond
      ((null v) (list (format nil "~a~a — НЕТ В СКЛАДЕ" отступ id)))
      ((member id видели) (list (format nil "~a~a — уже показано выше" отступ id)))
      ((sv-p v) (list (format nil "~a~a : молчание, искали в ~{~a~^, ~} — ~a"
                              отступ id (sv-where v) (sv-why v))))
      ((jv-p v)
       (multiple-value-bind (f c) (jv-fc v)
         (cons (format nil "~a~a : [~a] b=~,3f~@[  ← корень ~a~]"
                       отступ id (g-ru (jv-grade v)) (* f c)
                       (and (null (jv-base v)) (jv-origin v)))
               (loop for p in (jv-base v)
                     append (q-basis store p (1+ глубина) (cons id видели))))))
      (t (list (format nil "~a~a — не суждение" отступ id))))))

(defun на-чём-стоит (store id)
  (ans (format nil "на чём стоит ~a" id)
       (q-basis store id)
       (format nil "склад: ~a значений" (hash-table-count store))
       (if (gethash id store) nil (format nil "~a в складе нет" id))))

;;; ── 2. ЧТО ОПИРАЕТСЯ НА Y — цена отзыва, посчитанная ДО отзыва ──────────────
(defun q-dependents (store y)
  "Все суждения, чей провенанс достигает Y (сам Y не считается)."
  (let ((out '()))
    (dolist (kv (q-judgements store) (nreverse out))
      (let ((id (car kv)))
        (unless (eq id y)
          (labels ((достаёт-p (x видели)
                     (and (not (member x видели))
                          (let ((v (gethash x store)))
                            (or (eq x y)
                                (and (jv-p v)
                                     (or (eq (jv-origin v) y)
                                         (some (lambda (p) (достаёт-p p (cons x видели)))
                                               (jv-base v)))))))))
            (when (достаёт-p id '()) (push id out))))))))

(defun что-опирается-на (store y)
  (let ((зав (q-dependents store y)))
    (ans (format nil "что опирается на ~a" y)
         (if зав
             (append (mapcar (lambda (id)
                               (let ((v (gethash id store)))
                                 (format nil "  ~a : [~a] b=~,3f" id (g-ru (jv-grade v))
                                         (jv-belief v))))
                             зав)
                     (list (format nil "  🔴 отзыв ~a заденет ~a вывод(ов) — цена известна ДО отзыва"
                                   y (length зав))))
             (list "  ничего не опирается"))
         (format nil "суждений просмотрено: ~a" (length (q-judgements store)))
         (if (gethash y store) nil
             (format nil "~a в складе нет — возможно, это КОРЕНЬ, а корни в складе не лежат" y)))))

;;; ── 3. ЧТО ОСИРОТЕЛО ────────────────────────────────────────────────────────
(defun что-осиротело (ledger)
  (let ((сироты (remove-if-not (lambda (e) (member (first e) '(:orphaned :irreparable))) ledger)))
    (ans "что осиротело"
         (if сироты
             (mapcar (lambda (e)
                       (destructuring-bind (kind a j &optional b thr &rest _) e
                         (declare (ignore _))
                         (format nil "  ~a ~a на основании ~a: вера ~,3f < порог ~,3f~a"
                                 (if (eq kind :irreparable) "✖ НЕПОПРАВИМО" "⚠ осиротело")
                                 a j (or b 0) (or thr 0)
                                 (if (eq kind :irreparable) " — возместить нечем" ""))))
                     сироты)
             (list "  сирот нет"))
         (format nil "журнал: ~a записей" (length ledger))
         (if сироты nil "ни одно совершённое действие не потеряло основания"))))

;;; ── 4. ГДЕ ОПОРНОЕ МОЛЧАНИЕ ─────────────────────────────────────────────────
(defun где-опорное-молчание (store)
  (let ((на-молчании (remove-if-not (lambda (kv) (jv-leaned (cdr kv))) (q-judgements store))))
    (ans "где опорное молчание"
         (if на-молчании
             (loop for kv in на-молчании
                   append (loop for l in (jv-leaned (cdr kv))
                                collect (format nil "  ~a стоит на молчании ~a: искали в ~{~a~^, ~} — ~a"
                                                (car kv) (first l) (second l) (third l))))
             (list "  ни одно утверждение не опирается на молчание"))
         (format nil "суждений просмотрено: ~a" (length (q-judgements store)))
         (let ((немые (remove-if-not (lambda (kv) (sv-p (cdr kv)))
                                     (let ((o '())) (maphash (lambda (k v) (push (cons k v) o)) store) o))))
           (if немые
               (format nil "молчаний в складе всего: ~a (остальные — обзорные)" (length немые))
               "молчаний в складе нет вовсе")))))

;;; ── 5. КАКИЕ КОРНИ ПОВТОРЯЮТСЯ ──────────────────────────────────────────────
(defun какие-корни-повторяются (store)
  (let ((счёт '()))
    (dolist (kv (q-judgements store))
      (let ((v (cdr kv)))
        (when (and (null (jv-base v)) (jv-origin v))
          (let ((cell (assoc (jv-origin v) счёт)))
            (if cell (push (car kv) (cdr cell)) (push (list (jv-origin v) (car kv)) счёт))))))
    (let ((повтор (remove-if-not (lambda (c) (cdr (cdr c))) счёт)))
      (ans "какие корни повторяются"
           (if повтор
               (mapcar (lambda (c)
                         (format nil "  корень ~a: ~a свидетел(ь/я) — ~{~a~^, ~}~%~
                                      ~4Tсложены БЫ как независимые, если бы не свёртка по корням"
                                 (first c) (length (rest c)) (reverse (rest c))))
                       повтор)
               (list "  повторяющихся корней нет — каждый свидетель самостоятелен"))
           (format nil "корней различных: ~a" (length счёт))
           (if повтор nil "ложного усиления через родословную здесь не было")))))

;;; ── ПЕЧАТЬ: единственный способ показать ответ, и он ВСЕГДА печатает охват ──
(defun show-ans (a &optional (s t))
  (format s "~&? ~a~%" (ans-вопрос a))
  (dolist (l (ans-строки a)) (format s "~a~%" l))
  ;; 🔴 ОХВАТ ОБЯЗАТЕЛЕН. Ответ без него неотличим от «я не искал».
  (format s "  ⌕ охват: ~a~@[; ~a~]~%" (ans-где-искал a) (ans-чего-нет a)))

(defun ask-store (store ledger вопрос &optional арг)
  "Единый вход. ВОПРОС — ключевое слово; печатает ответ человеку и возвращает структуру."
  (let ((a (ecase вопрос
             (:на-чём-стоит (на-чём-стоит store арг))
             (:что-опирается (что-опирается-на store арг))
             (:что-осиротело (что-осиротело ledger))
             (:опорное-молчание (где-опорное-молчание store))
             (:корни (какие-корни-повторяются store)))))
    (show-ans a)
    a))
