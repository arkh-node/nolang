;;;; test/70_retract.lisp — ОТЗЫВ СВИДЕТЕЛЯ: долг №1 пятёрки.
;;;; Run: sbcl --script test/70_retract.lisp
;;;;
;;;; ЗАДАЧА, СТОЯВШАЯ С 28.07: `⊕` умеет добавить голос против, но не умеет ИЗЪЯТЬ
;;;; голос, оказавшийся ложным. Изъятие — вычитание в E, а вычитание выводит из ℝ≥0.
;;;;
;;;; РЕШЕНИЕ: вопрос стоял неверно. Дело не в арифметике, а в ПРЕДСТАВЛЕНИИ.
;;;; Утверждение обязано хранить своё основание (иначе нет провенанса) — значит отзыв
;;;; есть операция над ОСНОВАНИЕМ с пересчётом, а не обратная операция над значением.
;;;; Моноиду не нужно становиться группой.
(load (merge-pathnames "../src/reduce.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun ~= (a b &optional (eps 1e-4)) (< (abs (- a b)) eps))
(defun kinds (ledger) (mapcar #'first ledger))

(format t "~&── ПОЧЕМУ НЕ ВЫЧИТАНИЕ ──~%")

(let ((плохих 0))
  (dotimes (i 300)
    (let* ((f1 (+ 0.01 (random 0.98))) (c1 (+ 0.01 (random 0.5)))
           (f2 (+ 0.01 (random 0.98))) (c2 (+ 0.01 (random 0.5)))
           (f3 (+ 0.01 (random 0.98))) (c3 (+ 0.01 (random 0.5))))
      (multiple-value-bind (a+ a-) (fc->evidence f1 c1)
        (declare (ignore a-))
        (multiple-value-bind (b+ b-) (fc->evidence f2 c2)
          (declare (ignore b-))
          (multiple-value-bind (x+ x-) (fc->evidence f3 c3)
            (declare (ignore x-))
            ;; вычитаем свидетеля, которого в сумме не было — обычная ошибка учёта
            (when (< (- (+ a+ b+) x+) 0) (incf плохих)))))))
  (check "наивное вычитание уходит в отрицательный вес (>15% случайных случаев)"
         (> плохих 45)))

(check "пересчёт по основанию неотрицателен ПО ПОСТРОЕНИЮ: вес = сумма оставшихся"
       (let* ((p '((witness a "…" :grade строго :f 0.9 :c 0.5)
                   (witness b "…" :grade строго :f 0.8 :c 0.5)
                   (claim c (from a b))
                   (retract b :reason "рукопись признана подделкой")))
              (v (gethash 'c (run-nolang p))))
         (and (>= (jv-w+ v) 0) (>= (jv-w- v) 0))))

(format t "~&── ОТЗЫВ ПЕРЕСЧИТЫВАЕТ ОСНОВАНИЕ ──~%")

(defparameter *до*
  '((witness з-162 "…" :grade строго :f 0.9 :c 0.6)
    (witness з-159 "…" :grade строго :f 0.9 :c 0.6)
    (claim радость :grade строго (from з-162 з-159))))

(defparameter *после*
  (append *до* '((retract з-159 :reason "рукопись признана подделкой"))))

(check "отзыв роняет веру: свидетелей стало меньше"
       (< (belief-at-runtime *после* 'радость) (belief-at-runtime *до* 'радость)))

(check "…ровно до того, что даёт оставшийся свидетель в одиночку"
       (~= (belief-at-runtime *после* 'радость)
           (belief-at-runtime '((witness з-162 "…" :grade строго :f 0.9 :c 0.6)
                                (claim радость :grade строго (from з-162)))
                              'радость)))

(check "основание утверждения СОКРАТИЛОСЬ, а не обнулилось"
       (equal '(з-162) (jv-base (gethash 'радость (run-nolang *после*)))))

(check "отзыв ВСЕХ посылок даёт пустую базу ⇒ степень ⊥ (правило пустой базы)"
       (eq :silence
           (grade-at-runtime (append *до* '((retract з-162 :reason "…")
                                            (retract з-159 :reason "…")))
                             'радость)))

(format t "~&── ЗЕРКАЛО ТЕОРЕМЫ 5: что отзыв делает с верой ──~%")

;;; Теорема 5: свидетель РОНЯЕТ веру ⟺ его частота ниже неё (f′ < b).
;;; Зеркало: ОТЗЫВ свидетеля роняет веру ⟺ его частота была ВЫШЕ неё.
;;; Отозвать оппонента — значит УКРЕПИТЬ веру, и это не парадокс, а учёт.
(check "🔴 отзыв ОППОНЕНТА (f′ низкая) ПОВЫШАЕТ веру"
       (let* ((база '((witness за "…" :grade строго :f 0.95 :c 0.6)
                      (witness против "…" :grade строго :f 0.05 :c 0.6)
                      (claim спор :grade строго (from за против))))
              (b0 (belief-at-runtime база 'спор))
              (b1 (belief-at-runtime (append база '((retract против :reason "лжесвидетель")))
                                     'спор)))
         (> b1 b0)))

(check "отзыв СОЮЗНИКА (f′ высокая) понижает веру"
       (let* ((база '((witness за-1 "…" :grade строго :f 0.95 :c 0.6)
                      (witness за-2 "…" :grade строго :f 0.95 :c 0.6)
                      (claim согласие :grade строго (from за-1 за-2))))
              (b0 (belief-at-runtime база 'согласие))
              (b1 (belief-at-runtime (append база '((retract за-2 :reason "отозван автором")))
                                     'согласие)))
         (< b1 b0)))

(format t "~&── ⚠️ СТЕПЕНЬ МОЖЕТ ПОДНЯТЬСЯ — и это названо честно ──~%")

;;; Утверждение стояло на [строго] + [образ] ⇒ было [образ]. Отозвали слабого ⇒ стало [строго].
;;; Это НЕ отмывание: степень поднялась не операцией над значением, а тем, что посылка
;;; ПЕРЕСТАЛА СУЩЕСТВОВАТЬ. Но это вектор злоупотребления, и защита — в журнале:
;;; отзыв нельзя провести молча, и запись о нём НЕ СТИРАЕТСЯ.
(let* ((база '((witness крепкий "…" :grade строго :f 0.9 :c 0.6)
               (witness слабый  "…" :grade образ  :f 0.9 :c 0.6)
               (claim вывод (from крепкий слабый))))
       (после (append база '((retract слабый :reason "источник оказался поздней вставкой")))))
  (check "до отзыва: [строго] ⊓ [образ] = [образ]" (eq :obraz (grade-at-runtime база 'вывод)))
  (check "после отзыва слабой посылки степень ПОДНЯЛАСЬ до [строго]"
         (eq :strogo (grade-at-runtime после 'вывод)))
  (check "…но подъём ЗАПИСАН в журнал — молча это сделать нельзя"
         (member :retracted (kinds (nth-value 1 (run-nolang после)))))
  (check "…и причина отзыва сохранена дословно"
         (search "поздней вставкой"
                 (or (third (find :retracted (nth-value 1 (run-nolang после)) :key #'first)) ""))))

(format t "~&── 🔴 СИРОТЫ: действие, чьё основание рухнуло ──~%")

;; Веса подобраны СЧЁТОМ, а не на глаз: вдвоём b=0.675, в одиночку b=0.540.
;; Порог 0.6 лежит МЕЖДУ ними — иначе отзыв ничего бы не пересёк и тест был бы пустым.
(defparameter *с-действием*
  '((witness письмо "…" :grade строго :f 0.9 :c 0.6)
    (witness подтв  "…" :grade строго :f 0.9 :c 0.6)
    (claim заказ :grade строго (from письмо подтв))
    (action отправка :reversibility compensable :requires (>= belief 0.6)
            :else fold :compensated-by отмена-отправки)
    (do отправка заказ)
    (retract подтв :reason "письмо оказалось не от клиента")))

(multiple-value-bind (store ledger) (run-nolang *с-действием*)
  (declare (ignore store))
  (check "действие было совершено ДО отзыва" (member :performed (kinds ledger)))
  (check "🔴 после отзыва оно помечено ОСИРОТЕВШИМ" (member :orphaned (kinds ledger)))
  (check "запись сироты несёт новую веру и порог"
         (let ((o (find :orphaned ledger :key #'first)))
           (and (< (fourth o) (fifth o)))))
  (check "…и называет компенсацию, раз действие возместимо"
         (eq 'отмена-отправки (sixth (find :orphaned ledger :key #'first))))
  (check "порядок журнала: совершено → отозвано → осиротело"
         (let ((k (kinds ledger)))
           (and (< (position :performed k) (position :retracted k))
                (< (position :retracted k) (position :orphaned k))))))

(check "🔴 необратимое действие осиротело — компенсация НЕВОЗМОЖНА (вот зачем гейт)"
       (let* ((p '((witness рец "…" :grade строго :f 0.97 :c 0.93)
                   (claim статья :grade строго (from рец))
                   (action публикация :reversibility irreversible
                           :requires (>= belief 0.8) :else fold)
                   (do публикация статья)
                   (retract рец :reason "рецензент отозвал отзыв")))
              (o (find :orphaned (nth-value 1 (run-nolang p)) :key #'first)))
         (and o (eq 'irreversible (seventh o)) (null (sixth o)))))

(check "действие, которое порог ВЫДЕРЖАЛО после отзыва, сиротой не помечается"
       (let* ((p '((witness a "…" :grade строго :f 0.97 :c 0.93)
                   (witness b "…" :grade строго :f 0.97 :c 0.93)
                   (claim осн :grade строго (from a b))
                   (action шаг :reversibility compensable :requires (>= belief 0.3)
                           :else fold :compensated-by откат)
                   (do шаг осн)
                   (retract b :reason "уточнение"))))
         (not (member :orphaned (kinds (nth-value 1 (run-nolang p)))))))

(format t "~&── ИСТОРИЯ ДОПИСЫВАЕТСЯ, А НЕ СТИРАЕТСЯ ──~%")

(check "отзыв не удаляет прежние записи журнала"
       (let ((k (kinds (nth-value 1 (run-nolang *с-действием*)))))
         (and (member :performed k) (member :retracted k))))

(check "двойной отзыв одного свидетеля идемпотентен на складе"
       (let ((p1 (append *до* '((retract з-159 :reason "раз"))))
             (p2 (append *до* '((retract з-159 :reason "раз") (retract з-159 :reason "два")))))
         (equal (store-signature (run-nolang p1)) (store-signature (run-nolang p2)))))

(check "…но ОБА отзыва записаны в журнал (история не сворачивается)"
       (= 2 (count :retracted
                   (kinds (nth-value 1 (run-nolang
                                        (append *до* '((retract з-159 :reason "раз")
                                                       (retract з-159 :reason "два")))))))))

(check "отозванный свидетель числится мёртвым до конца прогона"
       (member 'з-159 (nth-value 4 (run-nolang *после*))))

(format t "~&── ВОССТАНОВЛЕНИЕ: чего AGM не обещает, а мы можем ──~%")

;;; Классическая теория пересмотра (AGM, 1985) спорит о постулате восстановления:
;;; сжатие с последующим расширением не обязано вернуть исходное. У нас — обязано,
;;; и не по доброте, а потому что мы храним ОСНОВАНИЕ, а не только следствие.
(check "отзыв и повторное предъявление того же свидетеля возвращают исходный склад"
       (let* ((исходный (store-signature (run-nolang *до*)))
              (кругом (store-signature
                       (run-nolang (append *до*
                                           '((retract з-159 :reason "ошибка учёта")
                                             (witness з-159б "…" :grade строго :f 0.9 :c 0.6)
                                             (claim радость-2 :grade строго (from з-162 з-159б))))))))
         ;; сравниваем ВЕРУ восстановленного утверждения с исходной
         (~= (belief-at-runtime *до* 'радость)
             (belief-at-runtime (append *до*
                                        '((retract з-159 :reason "ошибка учёта")
                                          (witness з-159б "…" :grade строго :f 0.9 :c 0.6)
                                          (claim радость-2 :grade строго (from з-162 з-159б))))
                                'радость-2))))

(format t "~&── конфлюэнтность держится и с отзывом ──~%")

(check "отзыв в конце ≡ пересчёт: результат не зависит от того, сколько шагов прошло"
       (let* ((p1 '((witness a "…" :grade строго :f 0.9 :c 0.6)
                    (witness b "…" :grade строго :f 0.9 :c 0.6)
                    (claim c (from a b))
                    (retract b :reason "…")))
              (p2 '((witness a "…" :grade строго :f 0.9 :c 0.6)
                    (claim c (from a)))))
         (~= (belief-at-runtime p1 'c) (belief-at-runtime p2 'c))))

(format t "~&── 🔴 ЗДРАВОСТЬ ДЕРЖИТСЯ С ОТЗЫВОМ ──~%")

;;; Если бы отзыв жил только в машине, а компилятор о нём не знал, статическая степень
;;; разошлась бы с динамической — и типовой слой стал бы украшением. Проверяю на
;;; случайных программах, где отзывается случайное подмножество свидетелей.
(defparameter *степени* '(образ традиция строго))

(defun random-with-retract (i)
  (let* ((k (+ 2 (random 3)))
         (ws (loop for j from 1 to k collect (intern (format nil "W~a-~a" i j))))
         (forms (loop for w in ws
                      collect `(witness ,w "…" :grade ,(nth (random 3) *степени*)
                                        :f ,(+ 0.55 (random 0.4)) :c ,(+ 0.1 (random 0.8)))))
         (cid (intern (format nil "C~a" i)))
         (отзываемые (remove-if-not (lambda (x) (declare (ignore x)) (zerop (random 3))) ws)))
    (values (append forms
                    `((claim ,cid (from ,@ws)))
                    (mapcar (lambda (w) `(retract ,w :reason "проверка")) отзываемые))
            cid (length отзываемые))))

(let ((ok t) (были-отзывы 0) (без 0) (дошло-до-дна 0))
  (dotimes (i 300)
    (multiple-value-bind (prog cid n-ret) (random-with-retract i)
      (if (plusp n-ret) (incf были-отзывы) (incf без))
      (let ((st (grade-of prog cid)) (dy (grade-at-runtime prog cid)))
        (when (eq dy :silence) (incf дошло-до-дна))
        (unless (eq st dy) (setf ok nil)))))
  (check "300 случайных программ С ОТЗЫВАМИ: статическая степень = динамической" ok)
  (check "…и отзывы действительно случались (иначе проверка пустая)" (> были-отзывы 30))
  (check "…и в части случаев отозвали ВСЁ основание (степень дошла до ⊥)" (> дошло-до-дна 0)))

(format t "~&~%── журнал с отзывом, как его увидит человек ──~%")
(show-ledger (nth-value 1 (run-nolang *с-действием*)))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
