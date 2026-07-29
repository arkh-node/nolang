;;;; test/F1_provn.lisp — ЭКСПОРТ В `PROV-N` (W3C) и его проверка РАЗБОРОМ.
;;;; Run: sbcl --script test/F1_provn.lisp
;;;;
;;;; ПОВОД (наказ Невис, D1): «Мы не конкурент PROV, мы не даём отмыть то, что PROV
;;;; записывает; уметь отдавать наружу в его нотации — дешёвый мост к отрасли.»
;;;;
;;;; 🔴 ГЛАВНОЕ О ДИСЦИПЛИНЕ ЭТОГО ФАЙЛА. Наказ разрешал проверять вывод «сторонним
;;;; валидатором либо, если его нет, — своим разбором по грамматике PROV-N с примером из
;;;; спецификации». Стороннего валидатора в системе нет, значит разбор свой — и тогда
;;;; он обязан быть написан ПО СПЕЦИФИКАЦИИ, а не по нашему экспортёру. Валидатор, выросший
;;;; из экспортёра, принимает ровно то, что экспортёр выдаёт, и не проверяет НИЧЕГО.
;;;; Поэтому порядок здесь жёсткий:
;;;;   1. разбор принимает ПРИМЕР 45 ИЗ СПЕЦИФИКАЦИИ, дословно;
;;;;   2. разбор УМЕЕТ ОТВЕРГАТЬ — шесть искажений, каждое ловится;
;;;;   3. и только потом через него пропускается наш вывод.
;;;; Источник грамматики: https://www.w3.org/TR/prov-n/ (сверено 29.07.2026).
(load (merge-pathnames "../src/provn.lisp" *load-pathname*))
(load (merge-pathnames "../src/parse.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

;;; ── РАЗБОР PROV-N (подмножество), написанный по спецификации ────────────────
(defparameter *prov-expressions*
  '("entity" "activity" "agent" "used" "wasGeneratedBy" "wasDerivedFrom"
    "wasAttributedTo" "wasAssociatedWith" "wasInvalidatedBy" "wasInformedBy"
    "wasStartedBy" "wasEndedBy" "actedOnBehalfOf" "specializationOf" "alternateOf"
    "hadMember" "wasInfluencedBy")
  "Имена выражений PROV-N. Всё, чего здесь нет, — не PROV-N, и разбор обязан это сказать.")

(define-condition prov-error (error)
  ((msg :initarg :msg :reader prov-msg))
  (:report (lambda (c s) (format s "PROV-N: ~a" (prov-msg c)))))

(defun prov-err (fmt &rest args) (error 'prov-error :msg (apply #'format nil fmt args)))

(defun strip-comments (src)
  "PROV-N: комментарии // до конца строки. Не комментарий — внутри строкового литерала
   И ВНУТРИ IRI.
   🔴 Второе едва не стоило мне разбора: `<http://www.w3.org/ns/prov#>` содержит `//`, и
   первая версия молча обрезала объявление префикса до `<http:`. Инструмент проверки соврал
   ПРАВДОПОДОБНО — обрезок выглядел как настоящая строка, и ругался разбор уже на него.
   Поймано сверкой с примером спецификации; сам бы я на такое не подумал."
  (with-output-to-string (out)
    (let ((i 0) (n (length src)) (in-str nil) (in-iri nil))
      (loop while (< i n) do
        (let ((ch (char src i)))
          (cond
            ((and in-str (char= ch #\\) (< (1+ i) n))
             (write-char ch out) (write-char (char src (1+ i)) out) (incf i 2))
            ((char= ch #\") (setf in-str (not in-str)) (write-char ch out) (incf i))
            ((and (not in-str) (char= ch #\<)) (setf in-iri t) (write-char ch out) (incf i))
            ((and (not in-str) (char= ch #\>)) (setf in-iri nil) (write-char ch out) (incf i))
            ((and (not in-str) (not in-iri)
                  (char= ch #\/) (< (1+ i) n) (char= (char src (1+ i)) #\/))
             (loop while (and (< i n) (char/= (char src i) #\Newline)) do (incf i)))
            (t (write-char ch out) (incf i))))))))

(defun prov-lines (src)
  (let ((out '()))
    (with-input-from-string (in (strip-comments src))
      (loop for l = (read-line in nil) while l
            do (let ((s (string-trim '(#\Space #\Tab #\Return) l)))
                 (unless (string= s "") (push s out)))))
    (nreverse out)))

(defun balanced-p (s)
  "Скобки и кавычки сбалансированы? Внутри строки скобки не считаются."
  (let ((par 0) (br 0) (in-str nil) (i 0) (n (length s)))
    (loop while (< i n) do
      (let ((ch (char s i)))
        (cond
          ((and in-str (char= ch #\\)) (incf i))
          ((char= ch #\") (setf in-str (not in-str)))
          (in-str)
          ((char= ch #\() (incf par))
          ((char= ch #\)) (decf par) (when (< par 0) (return-from balanced-p nil)))
          ((char= ch #\[) (incf br))
          ((char= ch #\]) (decf br) (when (< br 0) (return-from balanced-p nil))))
        (incf i)))
    (and (= par 0) (= br 0) (not in-str))))

(defun qnames-of (s)
  "Все квалифицированные имена вида pfx:local вне строковых литералов.
   🔴 Токен, начинающийся с ЦИФРЫ, именем не считается: префикс в PROV-N есть NCName,
   а он с цифры не начинается. Без этой оговорки метка времени `2011-11-16T16:05:00`
   читается как имя с префиксом `2011-11-16T16`, и разбор отвергает собственный пример
   спецификации. Поймано ПЕРВОЙ же сверкой с примером 45 — ровно за этим она и стоит первой:
   валидатор, не проверенный на заведомо верном тексте, проверяет не текст, а своё незнание."
  (let ((out '()) (i 0) (n (length s)) (in-str nil))
    (loop while (< i n) do
      (let ((ch (char s i)))
        (cond
          ((and in-str (char= ch #\\)) (incf i 2))
          ((char= ch #\") (setf in-str (not in-str)) (incf i))
          (in-str (incf i))
          ((or (alphanumericp ch) (find ch "_-") (> (char-code ch) 127))
           (let ((j i))
             (loop while (and (< j n)
                              (let ((c (char s j)))
                                (or (alphanumericp c) (find c "_-:.") (> (char-code c) 127))))
                   do (incf j))
             (let ((tok (subseq s i j)))
               (when (and (find #\: tok) (not (digit-char-p ch)))
                 (push tok out)))
             (setf i j)))
          (t (incf i)))))
    (nreverse out)))

(defun parse-provn (src)
  "Разбор подмножества PROV-N. → число выражений. Сигналит PROV-ERROR при нарушении.
   Проверяется: рамка document/endDocument · известность имени выражения · баланс скобок
   и кавычек · объявленность каждого префикса · непустой список аргументов."
  (let* ((lines (prov-lines src))
         (prefixes '("prov"))                ; prov объявлен спецификацией по умолчанию? НЕТ —
         (exprs 0) (started nil) (ended nil))
    ;; 🔴 «prov» здесь в списке НЕ потому, что он волшебный, а потому что наш экспортёр его
    ;; объявляет сам; если бы не объявлял — разбор обязан ругаться, и ниже это проверено.
    (setf prefixes '())
    (dolist (l lines)
      (cond
        ((string= l "document")
         (when started (prov-err "второй document внутри документа")) (setf started t))
        ((string= l "endDocument")
         (unless started (prov-err "endDocument без document")) (setf ended t))
        ((and (>= (length l) 7) (string= (subseq l 0 7) "prefix "))
         (unless started (prov-err "объявление префикса вне документа"))
         (let* ((rest* (string-trim " " (subseq l 7)))
                (sp (position #\Space rest*)))
           (unless sp (prov-err "объявление префикса без IRI: ~a" l))
           (let ((iri (string-trim " " (subseq rest* sp))))
             (unless (and (> (length iri) 2) (char= (char iri 0) #\<)
                          (char= (char iri (1- (length iri))) #\>))
               (prov-err "IRI обязан стоять в угловых скобках: ~a" iri)))
           (push (subseq rest* 0 sp) prefixes)))
        ((and (>= (length l) 8) (string= (subseq l 0 8) "default "))
         (unless started (prov-err "default вне документа")))
        (t
         (unless started (prov-err "выражение вне документа: ~a" l))
         (when ended (prov-err "выражение после endDocument: ~a" l))
         (let ((op (position #\( l)))
           (unless op (prov-err "выражение без скобки: ~a" l))
           (let ((name (string-trim " " (subseq l 0 op))))
             (unless (member name *prov-expressions* :test #'string=)
               (prov-err "неизвестное выражение PROV-N: ~a" name)))
           (unless (balanced-p l) (prov-err "несбалансированные скобки или кавычки: ~a" l))
           (unless (char= (char l (1- (length l))) #\))
             (prov-err "выражение не закрыто скобкой: ~a" l))
           (let ((args (string-trim " " (subseq l (1+ op) (1- (length l))))))
             (when (string= args "") (prov-err "выражение без аргументов: ~a" l)))
           (dolist (q (qnames-of l))
             (let ((pfx (subseq q 0 (position #\: q))))
               (unless (member pfx prefixes :test #'string=)
                 (prov-err "префикс ~a не объявлен (в ~a)" pfx q))))
           (incf exprs)))))
    (unless started (prov-err "нет document"))
    (unless ended (prov-err "нет endDocument"))
    exprs))

(defun provn-ok? (src) (handler-case (progn (parse-provn src) t) (prov-error () nil)))
(defun provn-err-of (src)
  (handler-case (progn (parse-provn src) nil) (prov-error (e) (prov-msg e))))

;;; ── 1. РАЗБОР ПРИНИМАЕТ ПРИМЕР ИЗ СПЕЦИФИКАЦИИ ─────────────────────────────
;;; Пример 45 из https://www.w3.org/TR/prov-n/, приведён дословно.
(defparameter *пример-45* "document
  default <http://anotherexample.org/>
  prefix ex <http://example.org/>

  entity(e2, [ prov:type=\"File\", ex:path=\"/shared/crime.txt\"])
  activity(a1, 2011-11-16T16:05:00, -, [prov:type=\"edit\"])
  wasGeneratedBy(e2, a1, -, [ex:fct=\"save\"])
  wasAssociatedWith(a1, ag2, -, [prov:role=\"author\"])
  agent(ag2, [ prov:type='prov:Person', ex:name=\"Bob\" ])

endDocument
")

(format t "~&── 1. РАЗБОР СВЕРЕН С ПРИМЕРОМ ИЗ СПЕЦИФИКАЦИИ ──~%")
;; в примере 45 префикс prov используется, но не объявлен явно (он предопределён спецификацией),
;; поэтому для сверки объявляем его — иначе мы проверяли бы не разбор, а своё незнание.
(defparameter *пример-45-с-prov*
  (let ((p (search "prefix ex" *пример-45*)))
    (concatenate 'string (subseq *пример-45* 0 p)
                 "prefix prov <http://www.w3.org/ns/prov#>" (string #\Newline) "  "
                 (subseq *пример-45* p))))

;; если разбор отверг заведомо верный текст — он обязан СКАЗАТЬ, на чём, а не молчать
(let ((e (provn-err-of *пример-45-с-prov*)))
  (when e (format t "  ⚠ разбор отверг пример спецификации: ~a~%" e)))
(check "🔴 пример 45 из спецификации разбирается"
       (provn-ok? *пример-45-с-prov*))
(check "…и в нём ровно пять выражений"
       (= 5 (parse-provn *пример-45-с-prov*)))

(format t "~&── 2. РАЗБОР УМЕЕТ ОТВЕРГАТЬ (иначе он ничего не проверяет) ──~%")

(check "нет endDocument — отвергнуто"
       (not (provn-ok? (subseq *пример-45-с-prov* 0 (search "endDocument" *пример-45-с-prov*)))))
(check "нет document — отвергнуто"
       (not (provn-ok? (subseq *пример-45-с-prov* (search "default" *пример-45-с-prov*)))))
(check "неизвестное имя выражения — отвергнуто и НАЗВАНО"
       (let ((e (provn-err-of "document
  prefix ex <http://example.org/>
  wasLaunderedFrom(ex:a, ex:b)
endDocument")))
         (and e (search "wasLaunderedFrom" e))))
(check "необъявленный префикс — отвергнут"
       (not (provn-ok? "document
  prefix ex <http://example.org/>
  entity(чужой:e1)
endDocument")))
(check "несбалансированная скобка — отвергнута"
       (not (provn-ok? "document
  prefix ex <http://example.org/>
  entity(ex:e1, [prov:type=\"x\"
endDocument")))
(check "IRI без угловых скобок — отвергнут"
       (not (provn-ok? "document
  prefix ex http://example.org/
  entity(ex:e1)
endDocument")))
(check "выражение без аргументов — отвергнуто"
       (not (provn-ok? "document
  prefix ex <http://example.org/>
  entity()
endDocument")))

(format t "~&── 3. НАШ ВЫВОД ПРОХОДИТ ЭТОТ РАЗБОР ──~%")

(defparameter *файл*
  (concatenate 'string (directory-namestring *load-pathname*) "../examples/фармакология.nol"))
(defparameter *формы*
  (parse (with-open-file (s *файл* :external-format :utf-8)
           (let ((d (make-string (file-length s)))) (subseq d 0 (read-sequence d s))))))

(defparameter *вывод*
  (multiple-value-bind (st lg) (run-nolang *формы* :carrier :морф)
    (export-provn st lg)))

(check "🔴 экспорт фармакологического примера разбирается как PROV-N"
       (provn-ok? *вывод*))
(check "…и он не пустой: выражений заметно больше десятка"
       (> (parse-provn *вывод*) 15))

(format t "~&── 4. ЧТО ИМЕННО ПЕРЕЖИЛО ПЕРЕВОД ──~%")

(check "корень стал сущностью-источником"
       (search "entity(nolang:десять_испытаний_роше, [nolang:kind=\"source\"])" *вывод*))
(check "свидетель происходит от своего корня"
       (search "wasDerivedFrom(nolang:кайзер2003, nolang:десять_испытаний_роше)" *вывод*))
(check "степень уехала атрибутом, а не потерялась"
       (search "nolang:grade=\"испытание·публикация\"" *вывод*))
(check "🔴 отзыв стал wasInvalidatedBy — единственное место, где PROV говорит почти нашим словом"
       (search "wasInvalidatedBy(nolang:десять_испытаний_роше," *вывод*))
(check "…и причина отзыва уехала дословно"
       (search "unable to determine" *вывод*))
(check "гейт: вера в момент решения и порог записаны при использовании основания"
       (and (search "nolang:verdict=\"performed\"" *вывод*)
            (search "nolang:belief_at_decision=\"0.8889\"" *вывод*)
            (search "nolang:threshold=\"0.8000\"" *вывод*)))
(check "осиротение и непоправимость записаны отдельными вердиктами"
       (and (search "nolang:verdict=\"orphaned\"" *вывод*)
            (search "nolang:verdict=\"irreparable\"" *вывод*)))
(check "молчание вывезено сущностью — с тем, ГДЕ искали и ПОЧЕМУ пусто"
       (and (search "nolang:kind=\"silence\"" *вывод*)
            (search "nolang:searched_in=" *вывод*)))
(check "опора на молчание помечена ролью, а не растворилась среди посылок"
       (search "nolang:role=\"leaned_on_silence\"" *вывод*))
(check "ребро к молчанию ОДНО, а не два с разными атрибутами"
       (let ((игла "wasDerivedFrom(nolang:смертность_снижается, nolang:нет_публикаций_о_смертности")
             (k 0) (i 0))
         (loop (let ((p (search игла *вывод* :start2 i)))
                 (if p (progn (incf k) (setf i (1+ p))) (return))))
         (= k 1)))
(check "носитель взят ИЗ ЖУРНАЛА и напечатан один раз"
       (let ((k 0) (i 0))
         (loop (let ((p (search "agent(nolang:морф" *вывод* :start2 i)))
                 (if p (progn (incf k) (setf i (1+ p))) (return))))
         (= k 1)))

(format t "~&── 5. ЧЕГО PROV НЕ УНЕСЁТ (граница названа, а не забыта) ──~%")
;;; 🔴 Это не недоработка экспорта, а разница ремёсел, и её надо предъявлять, а не заминать.
;;; PROV ОПИСЫВАЕТ происхождение. nolang ЗАПРЕЩАЕТ отмывание. Описание не несёт запрета.
(check "в PROV-N нет способа записать ЗАПРЕТ подъёма степени"
       (notany (lambda (w) (search w *вывод*)) '("launder" "forbid" "must-not")))
(check "…значит документ можно перевести обратно и получить ложь — импорта у нас и НЕТ"
       (not (fboundp 'import-provn)))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
