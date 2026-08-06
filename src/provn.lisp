;;;; nolang src — provn. ЭКСПОРТ СКЛАДА И ЖУРНАЛА В `PROV-N` (W3C).
;;;;
;;;; 🔴 ЗАЧЕМ ЭТО И ЧЕГО ЭТО НЕ ЗНАЧИТ (слово Невис, наказ D1).
;;;; Мы НЕ конкурент PROV. Разница между нами и им проходит ровно по одной черте:
;;;;   PROV ОПИСЫВАЕТ происхождение — он умеет записать, что откуда взялось.
;;;;   nolang ЗАПРЕЩАЕТ отмывание — он умеет сделать нечестный ход НЕВЫРАЗИМЫМ.
;;;; Описание и запрет — разные ремёсла. Поэтому мост наружу ОДНОСТОРОННИЙ: свою запись мы
;;;; умеем отдать в их нотации, но их нотация не унесёт с собой запрета. Импорта из PROV-N
;;;; здесь нет и не будет: принять чужой провенанс значило бы принять степени, которые
;;;; никто не гейтировал, — ровно то, против чего заведён язык.
;;;;
;;;; Дешевизна этого моста и есть его довод: полдня работы снимают целый класс возражений
;;;; («а почему не PROV?») и дают выход в экосистему, не тронув ни одного нашего закона.
;;;;
;;;; Синтаксис взят из спецификации W3C PROV-N (https://www.w3.org/TR/prov-n/), сверен
;;;; с примером 45 оттуда же; проверяющий разбор — в test/F1_provn.lisp, и он написан
;;;; ОТДЕЛЬНО от этого файла по грамматике спецификации. Если бы валидатор рос из
;;;; экспортёра, он принимал бы ровно то, что экспортёр выдаёт, и не проверял бы ничего.
;;;;
;;;; ЧТО ЧЕМ СТАНОВИТСЯ (и что при этом ТЕРЯЕТСЯ — сказано вслух):
;;;;   свидетель        → entity + wasDerivedFrom(свидетель, корень)
;;;;   корень/источник  → entity
;;;;   утверждение      → entity + wasDerivedFrom(утверждение, посылка) на каждую посылку
;;;;   молчание         → entity [nolang:kind="silence"] — 🔴 У PROV НЕТ ПОНЯТИЯ «искали и
;;;;                      не нашли». Мы вывозим его как сущность со своими атрибутами; чужой
;;;;                      читатель увидит сущность, но не увидит, что она ЛИНЕЙНА.
;;;;   действие         → activity
;;;;   совершение       → used(действие, основание) + атрибуты веры и порога
;;;;   свёрток          → activity [nolang:verdict="fold", nolang:lack=…] — отказ как ЗНАЧЕНИЕ
;;;;   отзыв            → wasInvalidatedBy(сущность, отзыв-как-activity)
;;;;   осиротение       → атрибуты на действии. 🔴 PROV не умеет сказать «основание рухнуло
;;;;                      ПОСЛЕ действия»: у него нет порога, значит нет и его непрохождения.

(load (merge-pathnames "reduce.lisp" *load-pathname*))

(defparameter *provn-iri* "https://github.com/arkh-node/nolang#"
  "IRI нашего словаря. Настоящий адрес репозитория: ссылка, которую можно открыть.")

(defun pn-name (sym)
  "Символ нолanga → локальное имя PROV-N. Русские буквы допустимы: PROV-N берёт IRI-символы."
  (substitute #\_ #\Space (string-downcase (string sym))))

(defun pn-id (prefix sym) (format nil "~a:~a" prefix (pn-name sym)))

(defun pn-str (x)
  "Строковый литерал PROV-N. Кавычка внутри строки сломала бы разбор — экранируем."
  (with-output-to-string (s)
    (write-char #\" s)
    (loop for ch across (princ-to-string x)
          do (case ch
               (#\" (write-string "\\\"" s))
               (#\\ (write-string "\\\\" s))
               (#\Newline (write-string " " s))
               (t (write-char ch s))))
    (write-char #\" s)))

(defun pn-attrs (pairs)
  "Список атрибутов PROV-N: [k=\"v\", …]. Пустой список НЕ печатаем — спецификация
   разрешает опустить, а лишняя пустая скобка только шумит."
  (let ((live (remove-if (lambda (p) (null (cdr p))) pairs)))
    (if (null live)
        ""
        (format nil ", [~{~a~^, ~}]"
                (mapcar (lambda (p) (format nil "~a=~a" (car p) (pn-str (cdr p)))) live)))))

;; 🔴 НОСИТЕЛЯ ПАРАМЕТРОМ ЗДЕСЬ НЕТ, И ЭТО НЕ УПУЩЕНИЕ. По разделению назначений (РЕДУКЦИЯ §4.2)
;; склад от носителя НЕ зависит, а журнал его ЗАПИСЫВАЕТ. Значит и экспорт обязан брать носитель
;; из журнала, а не из своего вызова: иначе появился бы второй источник правды о том, где это
;; происходило, и однажды они разошлись бы.
(defun export-provn (store ledger &key (prefix "nolang") (sources *sources*))
  "Склад и журнал → документ PROV-N (строка).
   🔴 Экспорт НИЧЕГО не пересчитывает: он только перекладывает уже посчитанное.
   Стоит ему начать считать — и наружу пойдёт вторая семантика, расходящаяся с первой.

   🔴 ИСТОЧНИКИ (05.08.2026, B5). Объявленный источник несёт класс, происхождение и отпечаток.
   Наружу они идут атрибутами сущности, а происхождение — их же конструкцией `wasDerivedFrom`:
   наш `from` и их `wasDerivedFrom` — одно и то же отношение, и это единственное место, где
   чужая нотация ложится на нашу без натяжки.
   Отпечаток вывозится как есть и НИЧЕГО здесь не проверяет: проверка — этап D (re-entry).
   Сейчас его работа одна — дожить до журнала неизменным, чтобы было с чем сверять потом."
  (with-output-to-string (out)
    (format out "document~%")
    (format out "  prefix ~a <~a>~%" prefix *provn-iri*)
    (format out "  prefix prov <http://www.w3.org/ns/prov#>~%~%")

    ;; ── корни: сущности-источники, на которые ссылаются свидетели ──
    (let ((roots '()))
      (maphash (lambda (k v)
                 (declare (ignore k))
                 (when (and (jv-p v) (jv-origin v)) (pushnew (jv-origin v) roots)))
               store)
      ;; объявленные источники выводим целиком, даже если на них никто не сослался:
      ;; мера существует независимо от того, воспользовались ею или нет
      (dolist (pair sources) (pushnew (car pair) roots))
      (dolist (r (sort roots #'string< :key #'string))
        (let* ((rec (cdr (assoc r sources)))
               (cls (and rec (getf rec :grade)))
               (fp  (and rec (getf rec :fingerprint)))
               (says (and rec (getf rec :says))))
          (format out "  entity(~a~a)~%" (pn-id prefix r)
                  (pn-attrs (append `(("nolang:kind" . "source"))
                                    (when cls  `(("nolang:class" . ,(g-ru cls))))
                                    (when fp   `(("nolang:fingerprint" . ,fp)))
                                    (when says `(("prov:label" . ,says))))))))
      ;; происхождение источника от источника — их же отношение, без натяжки
      (dolist (pair sources)
        (let ((from (getf (cdr pair) :from)))
          (when from
            (format out "  wasDerivedFrom(~a, ~a)~%"
                    (pn-id prefix (car pair)) (pn-id prefix from))))))

    ;; ── значения склада ──
    (let ((keys '()))
      (maphash (lambda (k v) (push (cons k v) keys)) store)
      (setf keys (sort keys #'string< :key (lambda (x) (string (car x)))))
      (dolist (kv keys)
        (let ((id (car kv)) (v (cdr kv)))
          (cond
            ;; свидетель или утверждение
            ((jv-p v)
             (multiple-value-bind (f c) (jv-fc v)
               (format out "  entity(~a~a)~%" (pn-id prefix id)
                       (pn-attrs `(("nolang:kind" . ,(if (jv-base v) "claim" "witness"))
                                   ("nolang:grade" . ,(g-ru (jv-grade v)))
                                   ("nolang:frequency" . ,(format nil "~,4f" f))
                                   ("nolang:confidence" . ,(format nil "~,4f" c))
                                   ("nolang:belief" . ,(format nil "~,4f" (* f c)))
                                   ("nolang:weight_for" . ,(format nil "~,1f" (jv-w+ v)))
                                   ("nolang:weight_against" . ,(format nil "~,1f" (jv-w- v)))
                                   ;; 🔴 ДВА ВРЕМЕНИ (D4). `nolang:at` — когда свидетельство
                                   ;; относится к МИРУ (объявлено данными, не вызовом часов:
                                   ;; иначе возврат перестал бы воспроизводиться). Время
                                   ;; ФИКСАЦИИ отдельным полем не пишется — им служит порядок
                                   ;; в журнале, и он уже детерминирован.
                                   ;; Противоречие «знал тогда / знаю теперь» становится двумя
                                   ;; фактами с разными `at`, а не затиранием одного другим.
                                   ,@(when (jv-at v)
                                       `(("nolang:at" . ,(format nil "~a" (jv-at v)))))))))
             ;; свидетель происходит от своего корня
             (when (and (jv-origin v) (not (jv-base v)))
               (format out "  wasDerivedFrom(~a, ~a)~%"
                       (pn-id prefix id) (pn-id prefix (jv-origin v))))
             ;; утверждение происходит от КАЖДОЙ посылки — здесь и виден провенанс.
             ;; 🔴 Опорные молчания входят и в основание, и в `leaned`. Ребро печатаем ОДНО,
             ;; но с ролью: два ребра между теми же узлами с разными атрибутами читались бы
             ;; как два разных происхождения, а происхождение одно — просто у него есть род.
             (let ((leaned (mapcar #'first (jv-leaned v))))
               (dolist (p (jv-base v))
                 (unless (member p leaned)
                   (format out "  wasDerivedFrom(~a, ~a)~%" (pn-id prefix id) (pn-id prefix p))))
               (dolist (l leaned)
                 (format out "  wasDerivedFrom(~a, ~a~a)~%"
                         (pn-id prefix id) (pn-id prefix l)
                         (pn-attrs `(("nolang:role" . "leaned_on_silence"))))))
             ;; охват — граница знания; в PROV она не выразима, вывозим ролью на связи
             (dolist (cv (jv-cover v))
               (format out "  wasDerivedFrom(~a, ~a~a)~%"
                       (pn-id prefix id) (pn-id prefix (first cv))
                       (pn-attrs `(("nolang:role" . "searched"))))))
            ;; молчание
            ((sv-p v)
             (format out "  entity(~a~a)~%" (pn-id prefix id)
                     (pn-attrs `(("nolang:kind" . "silence")
                                 ("nolang:searched_in"
                                  . ,(format nil "~{~a~^, ~}" (sv-where v)))
                                 ("nolang:reason" . ,(sv-why v))))))
            ;; действие
            ((av-p v)
             (format out "  activity(~a, -, -~a)~%" (pn-id prefix id)
                     (pn-attrs `(("nolang:kind" . "action")
                                 ("nolang:reversibility" . ,(string-downcase (string (av-rev v))))
                                 ("nolang:threshold" . ,(and (av-thr v)
                                                             (format nil "~,4f" (av-thr v))))
                                 ("nolang:compensated_by" . ,(and (av-comp v)
                                                                  (pn-name (av-comp v))))))))
            ;; свёрток: отказ гейта — ЗНАЧЕНИЕ, и наружу он идёт значением
            ((fv-p v)
             (format out "  activity(~a, -, -~a)~%" (pn-id prefix id)
                     (pn-attrs `(("nolang:kind" . "fold")
                                 ("nolang:verdict" . "fold")
                                 ("nolang:lack" . ,(format nil "~,4f" (fv-lack v))))))
             (format out "  used(~a, ~a, -)~%" (pn-id prefix id) (pn-id prefix (fv-on v))))))))

    ;; ── журнал ──
    (let ((n 0))
      (dolist (e ledger)
        (destructuring-bind (kind a j &optional b thr lack els) e
          (declare (ignore lack els))
          (incf n)
          (case kind
            (:performed
             (format out "  used(~a, ~a, -~a)~%" (pn-id prefix a) (pn-id prefix j)
                     (pn-attrs `(("nolang:verdict" . "performed")
                                 ("nolang:belief_at_decision" . ,(and b (format nil "~,4f" b)))
                                 ("nolang:threshold" . ,(and thr (format nil "~,4f" thr)))))))
            (:folded
             (format out "  used(~a, ~a, -~a)~%" (pn-id prefix a) (pn-id prefix j)
                     (pn-attrs `(("nolang:verdict" . "fold")
                                 ("nolang:belief_at_decision" . ,(and b (format nil "~,4f" b)))
                                 ("nolang:threshold" . ,(and thr (format nil "~,4f" thr)))))))
            ;; 🔴 ОТЗЫВ — единственное место, где PROV говорит нашим языком почти дословно:
            ;; wasInvalidatedBy есть ровно «сущность перестала быть годной». Причина уходит
            ;; атрибутом, потому что у PROV для причины места нет.
            (:retracted
             (let ((act (format nil "~a:retraction_~a" prefix n)))
               (format out "  activity(~a, -, -~a)~%" act
                       (pn-attrs `(("nolang:kind" . "retraction")
                                   ("nolang:reason" . ,j))))
               (format out "  wasInvalidatedBy(~a, ~a, -)~%" (pn-id prefix a) act)))
            (:orphaned
             (format out "  used(~a, ~a, -~a)~%" (pn-id prefix a) (pn-id prefix j)
                     (pn-attrs `(("nolang:verdict" . "orphaned")
                                 ("nolang:belief_now" . ,(and b (format nil "~,4f" b)))
                                 ("nolang:threshold" . ,(and thr (format nil "~,4f" thr)))))))
            (:irreparable
             (format out "  used(~a, ~a, -~a)~%" (pn-id prefix a) (pn-id prefix j)
                     (pn-attrs `(("nolang:verdict" . "irreparable")
                                 ("nolang:belief_now" . ,(and b (format nil "~,4f" b)))
                                 ("nolang:threshold" . ,(and thr (format nil "~,4f" thr)))))))
            (:compensating
             (format out "  used(~a, ~a, -~a)~%" (pn-id prefix a) (pn-id prefix j)
                     (pn-attrs `(("nolang:verdict" . "compensating")))))
            (:ran-on
             (format out "  agent(~a~a)~%" (pn-id prefix a)
                     (pn-attrs `(("nolang:kind" . "carrier")))))))))
    (format out "endDocument~%")))
