;;;; nolang src — subject. СЕРИАЛИЗАЦИЯ СУБЪЕКТА И ВОЗВРАТ В СЕБЯ (этап D, 05.08.2026).
;;;;
;;;; 🔴 ЗАЧЕМ. `Obj0 math = projection + invariant + re-entry` — закон формализации, из которого
;;;; вырос язык. Проекция сделана (степени), инвариант доказан (степень не поднимается), а
;;;; ТРЕТИЙ ПРИМИТИВ отсутствовал: как идентичность возвращается после разрыва. Ради него
;;;; затевалась вся линия; без него агент, прерванный на середине, начинается заново.
;;;;
;;;; 🔴 ГЛАВНОЕ РЕШЕНИЕ: ВОССТАНОВЛЕНИЕ ЕСТЬ ВОСПРОИЗВЕДЕНИЕ, А НЕ ЗАГРУЗКА.
;;;; Соблазн — сохранить состояние (склад, веса, степени) и поднять его обратно. Так делают
;;;; все, и так делать нельзя: поднятое состояние надо принять НА ВЕРУ, а язык заведён ровно
;;;; против этого. Вместо этого сохраняются ПОСЫЛКИ (сцена + формы), а вывод при возврате
;;;; ВЫЧИСЛЯЕТСЯ ЗАНОВО и сверяется с записанным итогом.
;;;;
;;;; Отсюда три следствия, каждое даром:
;;;;   1. подделка не проходит — изменённые посылки дают другой итог, и это видно;
;;;;   2. изменившаяся сцена не проходит — другой горизонт или решётка дают другой итог;
;;;;   3. никаких новых гарантий изобретать не пришлось: проверяет тот же прогон,
;;;;      что и всегда, теми же типами и тем же гейтом.
;;;;
;;;; Что сериализуется (D1, состав якоря по `aObj0/02_agent_world/001_memory_trace_continuation`):
;;;;   СЦЕНА  — горизонт · решётка · источники с классами и отпечатками. Всё из прелюдии,
;;;;            то есть зафиксировано ДО того, как стало известно, что судят.
;;;;   СЛЕД   — формы программы: свидетели с их речью, молчания, утверждения, действия.
;;;;   ПЕЧАТЬ — журнал прогона: что было сделано, что свёрнуто, с какой верой.
;;;;
;;;; Чего здесь НЕТ намеренно: прозы, настроения, сводки «что я понял». Запрет aObj0 —
;;;; `continuation by mood only` и «путать personal warmth with structural return». Вывод не
;;;; хранится: хранятся посылки и их происхождение, а вывод восстанавливается прогоном.
;;;; Иначе при возврате мы поверили бы прошлому себе на слово.

(load (merge-pathnames "verdict.lisp" *load-pathname*))

(defparameter *subject-version* 1)

;;; ── СЕРИАЛИЗАЦИЯ ────────────────────────────────────────────────────────────

(defun scene-forms (forms)
  "Формы СЦЕНЫ: то, чем судят. Порядок сохраняется — решётка объявляется до произведения."
  (remove-if-not (lambda (f)
                   (and (consp f)
                        (member (head-of f) '("horizon" "lattice" "source" "import" "action")
                                :test #'string=)))
                 forms))

(defun trace-forms (forms)
  "Формы СЛЕДА: что намеряли. Всё, что не сцена."
  (remove-if (lambda (f)
               (and (consp f)
                    (member (head-of f) '("horizon" "lattice" "source" "import" "action")
                            :test #'string=)))
             forms))

(defun scene-digest (scene)
  "Отпечаток сцены: устойчивая строка из форм, чем судили.

   🔴 ЗАЧЕМ ОТДЕЛЬНО ОТ ВОСПРОИЗВЕДЕНИЯ. Найдено при первой же проверке (05.08): подмена
   сцены проходит незамеченной, если она НЕ ВЛИЯЕТ на вывод. Подняли класс источника с
   `abstract` до `full_report` — потолок стал выше, свидетель как был `abstract`, так и
   остался, журнал совпал, возврат прошёл. Воспроизведение сверяет ПОСЛЕДСТВИЯ, а сцена
   есть то, ЧЕМ судят: её надо сверять прямо, а не по следам.

   ⚠️ ГРАНИЦА, названная вслух: отпечаток лежит в той же записи, что и сцена. Он ловит
   НЕБРЕЖНУЮ подделку (изменили сцену, забыли пересчитать) и не ловит тщательную (изменили
   и то и другое). Против тщательной нужен внешний якорь — подпись или хранение отпечатка
   отдельно от записи. Это этап D5, и до него говорить «подделка обнаруживается» нельзя."
  (let ((*print-pretty* nil) (*print-readably* nil) (*package* (find-package :cl-user)))
    (format nil "~a" (sxhash (format nil "~s" scene)))))

(defun serialize-subject (forms ledger &key (carrier nil))
  "Формы + журнал → запись субъекта (список). Читаемо и печатаемо `prin1`.

   🔴 Пишутся ФОРМЫ, а не значения. Значение при возврате будет вычислено заново — в этом
   вся защита: сохранённому итогу не верят, его ПЕРЕПРОВЕРЯЮТ."
  (let ((scene (scene-forms forms)))
    (list :subject *subject-version*
          :carrier carrier
          :scene   scene
          :scene-digest (scene-digest scene)
          :trace   (trace-forms forms)
          :seal    ledger)))

(defun subject-scene (s)   (getf (cddr s) :scene))
(defun subject-trace (s)   (getf (cddr s) :trace))
(defun subject-seal (s)    (getf (cddr s) :seal))
(defun subject-carrier (s) (getf (cddr s) :carrier))
(defun subject-scene-digest (s) (getf (cddr s) :scene-digest))

;;; ── ВОЗВРАТ ────────────────────────────────────────────────────────────────

(defun ledger-equal (a b)
  "Журналы совпадают? Сравнение структурное, а не по печати: печать может расходиться
   пробелами и порядком ключей, а вывод — нет."
  (equal a b))

(defun re-enter (s)
  "Возврат в субъекта: прогнать записанные посылки заново и сверить с печатью.
   → (values успех новый-журнал причина).

   Причины расхождения различаются, потому что требуют разного:
     :scene-differs  — сцена не сходится с объявленным отпечатком ЛИБО не складывается вовсе:
                       это не тот же субъект, продолжающий работу, а другой, читающий чужой
                       журнал. Проверяется ПЕРВЫМ и отдельно от вывода;
     :trace-differs  — посылки не типизируются в этой сцене;
     :seal-differs   — посылки те же, вывод другой. Либо подделана печать, либо изменилось
                       то, на что посылки опираются. И то и другое — повод остановиться."
  ;; 🔴 СНАЧАЛА сцена, потом воспроизведение. Порядок несущий: сцена есть то, ЧЕМ судят,
  ;; и её подмена может не отразиться на выводе вовсе (найдено проверкой 05.08).
  (let ((declared (subject-scene-digest s)))
    (when (and declared (not (string= declared (scene-digest (subject-scene s)))))
      (return-from re-enter (values nil nil :scene-differs))))
  (let ((forms (append (subject-scene s) (subject-trace s))))
    (handler-case
        (with-prelude
          (multiple-value-bind (env errs) (check-program forms)
            (declare (ignore env))
            (if errs
                (values nil nil :trace-differs)
                (multiple-value-bind (store lg) (run-nolang forms :carrier (subject-carrier s))
                  (declare (ignore store))
                  (if (ledger-equal lg (subject-seal s))
                      (values t lg nil)
                      (values nil lg :seal-differs))))))
      (error () (values nil nil :scene-differs)))))

(defun subject-write (s path)
  "Запись субъекта на диск. Печатается как s-выражение: язык умеет себя читать."
  (with-open-file (out path :direction :output :if-exists :supersede
                            :external-format :utf-8)
    (let ((*print-readably* nil) (*print-circle* nil) (*print-length* nil)
          (*print-level* nil) (*package* (find-package :cl-user)))
      (prin1 s out)
      (terpri out)))
  path)

(defun subject-read (path)
  "Чтение субъекта с диска."
  (with-open-file (in path :external-format :utf-8)
    (let ((*package* (find-package :cl-user)))
      (read in))))


;;; ── ПРОДОЛЖЕНИЕ: `continue from` ───────────────────────────────────────────

(defun continue-form-p (f)
  (and (consp f) (string= (head-of f) "continue")))

(defun resolve-continuation (forms)
  "Если программа начинается с `continue from \"путь\"` — восстановить прежнего субъекта и
   вернуть ПОЛНЫЙ список форм: его сцена + его след + новые формы.
   → (values формы ошибка).

   🔴 ПОЧЕМУ ВОССТАНОВЛЕННЫЕ ФОРМЫ ИДУТ ПЕРВЫМИ И ЦЕЛИКОМ. Соблазн — взять из прежнего
   субъекта «итоги» и продолжить с них. Тогда новые свидетельства встретились бы с ВЫВОДАМИ,
   а не с посылками, и прежняя работа стала бы неоспоримой: её не из чего оспорить. Здесь
   вместо этого подставляются посылки, и весь прогон идёт заново — новое свидетельство
   спорит со старым на равных, отзыв работает через всю историю, а не только по свежей части.
   Цена — прогон длиннее. Плата за то, что прошлое остаётся оспоримым.

   Сцена берётся ТОЛЬКО из записи: продолжение не вправе объявить свою меру поверх прежней.
   Если оно попробует — столкнётся с `chk-unique` и не соберётся, как и положено."
  (let ((head (first forms)))
    (if (not (continue-form-p head))
        (values forms nil)
        (let* ((path (getf (cdr head) :from))
               (s (handler-case (subject-read path)
                    (error () nil))))
          (cond
            ((null s) (values nil :subject-unreadable))
            (t (multiple-value-bind (ok lg why) (re-enter s)
                 (declare (ignore lg))
                 (if (not ok)
                     (values nil (or why :re-entry-failed))
                     (values (append (subject-scene s)
                                     (subject-trace s)
                                     (rest forms))
                             nil)))))))))
