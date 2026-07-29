;;;; test/50_grammar.lisp — ГРАММАТИКА: что нельзя ЗАПИСАТЬ.
;;;; Run: sbcl --script test/50_grammar.lisp
;;;;
;;;; Грамматика окупает себя не красотой, а тем, сколько дурных состояний она уводит
;;;; с типового уровня на синтаксический. Здесь каждое такое состояние предъявлено
;;;; текстом, который обязан НЕ РАЗОБРАТЬСЯ — и сообщением, которое обязано объяснить.
(load (merge-pathnames "../src/parse.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

(defparameter *программа* "
lattice provenance = silence < image < tradition < strict

witness report-162 : strict
  says \"Испытание A: осложнений в группе лечения меньше, чем в контрольной.\"
  source trial-a
  evidence 8 for 1 against

witness report-159 : strict
  says \"Испытание A, вторичный анализ: направление эффекта то же…\"
  source trial-a
  evidence 6 for 1 against

ask registry-273
  in corpus, library, registry
  found nothing because \"записей об исходе 273 нет\"

claim benefit : strict
  from report-162, report-159
  searched registry-273

irreversible action publish
  gated by belief >= 0.7
  else fold

perform publish on benefit
")

(format t "~&── целая программа разбирается и проходит проверку ──~%")

(check "разбор без ошибок" (parse-ok? *программа*))

(multiple-value-bind (forms errs) (compile-nolang *программа*)
  (check "разобрано семь объявлений" (= 7 (length forms)))
  (check "проверяющий принимает разобранное" (null (remove :runtime (mapcar #'terr-code errs))))
  (check "решётка объявлена программой, не зашита в язык"
         (eq 'lattice (first (first forms)))))

(format t "~&── 1. НЕОБРАТИМОЕ БЕЗ ГЕЙТА — не разбирается ──~%")

(check "irreversible без `gated by` — ошибка разбора, а не типа"
       (not (parse-ok? "irreversible action publish")))
(check "…и сообщение показывает, что дописать"
       (search "gated by belief" (parse-error-of "irreversible action publish")))
(check "reversible без гейта — законно"
       (parse-ok? "reversible action note"))

(format t "~&── 2. ГЕЙТ НА ЧЁМ-ЛИБО КРОМЕ МАССЫ ВЕРЫ — не разбирается ──~%")

(check "`gated by confidence` не РАЗБИРАЕТСЯ (слово belief вшито в продукцию)"
       (not (parse-ok? "irreversible action p gated by confidence >= 0.9 else fold")))
(check "…и сообщение объясняет, почему именно произведение"
       (search "разорваны пополам"
               (parse-error-of "irreversible action p gated by confidence >= 0.9 else fold")))
(check "гейт без ветви отказа — не разбирается"
       (not (parse-ok? "irreversible action p gated by belief >= 0.9")))

(format t "~&── 3. COMPENSABLE БЕЗ КОМПЕНСАЦИИ — не разбирается ──~%")

(check "«возместимое» без указания, чем возмещать — пустое слово"
       (not (parse-ok? "compensable action send")))
(check "с компенсацией — законно"
       (parse-ok? "compensable action send compensated by cancel"))

(format t "~&── 4. ПУСТАЯ БАЗА ОБЯЗАНА БЫТЬ НАПИСАНА ──~%")

(check "claim без `from` — не разбирается"
       (not (parse-ok? "claim x")))
(check "`from nothing` пишется явно — и потому видно"
       (parse-ok? "claim x from nothing"))
(check "…и получает степень ⊥, как велит алгебра"
       (eq :silence (grade-of (parse "claim x from nothing") 'x)))

(format t "~&── 5. МОЛЧАНИЕ БЕЗ «ГДЕ» И «ПОЧЕМУ» — не разбирается ──~%")

(check "ask без `in` — не разбирается (где искал?)"
       (not (parse-ok? "ask s found nothing because \"пусто\"")))
(check "ask без `because` — не разбирается (почему пусто?)"
       (not (parse-ok? "ask s in corpus found nothing")))
(check "полное молчание — законно"
       (parse-ok? "ask s in corpus, library found nothing because \"пусто\""))

(format t "~&── свидетель обязан назвать речь, источник и ВЕС ──~%")

(check "witness без `says` — не разбирается"
       (not (parse-ok? "witness a : strict source trial-a evidence 8 for 1 against")))
(check "witness без `source` — не разбирается"
       (not (parse-ok? "witness a : strict says \"…\" evidence 8 for 1 against")))
(check "witness без `evidence` — не разбирается (голос без веса не тянет)"
       (not (parse-ok? "witness a : strict says \"…\" source trial-a")))

(format t "~&── поверхность берёт СЧЁТ свидетельств, а не (f,c) ──~%")

;; 8 за, 1 против → w=9, f=8/9≈0.889, c=9/10=0.9
(let* ((forms (parse "witness a : strict says \"…\" source z evidence 8 for 1 against"))
       (w (first forms)))
  (check "evidence 8 for 1 against → f ≈ 0.889"
         (< (abs (- (getf (cdddr w) :f) 0.8889)) 0.001))
  (check "…и c = 9/(9+1) = 0.9 ровно"
         (< (abs (- (getf (cdddr w) :c) 0.9)) 0.001)))

(format t "~&── типовые запреты грамматике НЕ достались (и это правильно) ──~%")

;; Отмывание синтаксически безупречно — его ловит только типовой слой.
(let ((src "witness r : image says \"137 = קבלה\" source resonance evidence 3 for 1 against
            claim m : strict from r"))
  (check "отмывание РАЗБИРАЕТСЯ (грамматике оно недоступно)" (parse-ok? src))
  (multiple-value-bind (forms errs) (compile-nolang src)
    (declare (ignore forms))
    (check "…но отвергается типами — разделение труда честное"
           (member :launder (mapcar #'terr-code errs)))))

;; Уроненное молчание — тоже линейность, тоже типы.
(let ((src "witness a : strict says \"…\" source z evidence 8 for 1 against
            ask s in corpus found nothing because \"пусто\"
            claim c : strict from a"))
  (check "уроненное молчание разбирается, но линейность ловит его типом"
         (and (parse-ok? src)
              (member :dropped (mapcar #'terr-code (nth-value 1 (compile-nolang src)))))))

(format t "~&── ОТЗЫВ: причина обязательна грамматикой ──~%")

(check "retract без `because` — не разбирается"
       (not (parse-ok? "retract report-159")))
(check "…и сообщение объясняет, почему причина обязательна"
       (search "отмыванием" (parse-error-of "retract report-159")))
(check "с причиной — законно"
       (parse-ok? "retract report-159 because \"рукопись признана подделкой\""))

(check "отзыв в полной программе: разбирается, проверяется, пересчитывает"
       (let ((src "
witness a : strict says \"…\" source z evidence 8 for 1 against
witness b : image  says \"…\" source r evidence 5 for 1 against
claim c from a, b
retract b because \"источник оказался поздней вставкой\"
"))
         (and (parse-ok? src)
              ;; было [строго]⊓[образ]=[образ]; после отзыва слабого стало [строго]
              (eq :strogo (grade-of (parse src) 'c)))))

(format t "~&── сообщения об ошибках указывают строку ──~%")

(check "номер строки в сообщении"
       (search "строка 3" (parse-error-of (format nil "reversible action a~%~%irreversible action b"))))

(format t "~&~%── как выглядит отказ разбора ──~%~%~a~%~%~a~%"
        (parse-error-of "irreversible action publish")
        (parse-error-of "irreversible action p gated by confidence >= 0.9 else fold"))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
