;;;; test/H1_decide.lisp — ТОЧКА РЕШЕНИЯ КАК API (наказ Невис, раздел F).
;;;; Run: sbcl --script test/H1_decide.lisp
;;;;
;;;; 🔴 ПРОВЕРЯЕТСЯ ГЛАВНОЕ ТРЕБОВАНИЕ F2: вердикт НИКОГДА не голое «да/нет». Всегда
;;;; основание, степень, вера, порог и недостача (или запас). Поэтому здесь проверяется
;;;; не только «что ответил», но и «чего в ответе не может не быть».
(load (merge-pathnames "../src/decide.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

(defun решить (src) (with-output-to-string (*standard-output*) (decide-and-show src)))

;;; ── три программы: прошло · свернулось · решений нет ────────────────────────
(defparameter *прошло* "
lattice честность = молчание < образ < традиция < строго
witness сильный : строго says \"…\" source родник evidence 9 for 1 against
claim основание from сильный
irreversible action шаг gated by belief >= 0.5 else свернуть
perform шаг on основание
")

(defparameter *свернулось* "
lattice честность = молчание < образ < традиция < строго
witness слабый : образ says \"…\" source родник evidence 1 for 3 against
claim основание from слабый
irreversible action шаг gated by belief >= 0.9 else свернуть
perform шаг on основание
")

(defparameter *без-решений* "
lattice честность = молчание < образ < традиция < строго
witness кто-то : строго says \"…\" source родник evidence 5 for 0 against
claim основание from кто-то
")

(defparameter *отклонено* "
lattice честность = молчание < образ < традиция < строго
witness слабый : образ says \"…\" source родник evidence 3 for 1 against
claim высокое : строго from слабый
")

(format t "~&── F1. ОДИН ВХОД: ПРОГРАММА → ВЕРДИКТ ──~%")

(check "прошедшее решение даёт вердикт СОВЕРШЕНО"
       (search "СОВЕРШЕНО" (решить *прошло*)))
(check "не прошедшее даёт СВЁРНУТО — и это ЗНАЧЕНИЕ, а не ошибка"
       (let ((s (решить *свернулось*)))
         (and (search "СВЁРНУТО" s) (search "значение, а не ошибка" s))))
(check "🔴 программа без действий отвечает СЛОВАМИ, а не молчанием"
       (let ((s (решить *без-решений*)))
         (and (search "НИ ОДНОГО РЕШЕНИЯ" s)
              (search "не отказ и не разрешение" s))))
(check "отклонённая проверяющим программа названа отклонённой, а не свёрнутой"
       (let ((s (решить *отклонено*)))
         (and (search "ОТКЛОНЕНА ПРОВЕРЯЮЩИМ" s) (search "LAUNDER" s))))
(check "вердикты возвращаются структурами, а не только печатаются"
       (let ((v (first (decide *прошло*))))
         (and (verdict-p v) (eq (verdict-kind v) :performed))))
(check "журнал возвращается тем же вызовом"
       (nth-value 1 (decide *прошло*)))

(format t "~&── F2. 🔴 ВЕРДИКТ НИКОГДА НЕ ГОЛОЕ «ДА/НЕТ» ──~%")

(check "в положительном вердикте есть ОСНОВАНИЕ"
       (search "основание: ОСНОВАНИЕ" (решить *прошло*)))
(check "…и степень"
       (search "степень: [строго]" (решить *прошло*)))
(check "…и вера с порогом"
       (let ((s (решить *прошло*))) (and (search "вера 0." s) (search "порог 0." s))))
(check "…и ЗАПАС числом, а не словом «прошло»"
       (search "запас 0." (решить *прошло*)))
(check "🔴 в отрицательном вердикте есть НЕДОСТАЧА числом"
       (let ((s (решить *свернулось*)))
         (and (search "НЕДОСТАЧА" s) (search "не хватило" s))))
(check "…и недостача названа ЗАКАЗОМ на работу, а не приговором"
       (search "вот размер недостающего свидетельства" (решить *свернулось*)))
(check "🔴 нет ни одного вердикта без основания — проверено по всем трём программам"
       (every (lambda (src)
                (let ((vs (decide src)))
                  (every (lambda (v) (and (verdict-basis v) (verdict-action v))) vs)))
              (list *прошло* *свернулось* *без-решений*)))
(check "охват печатается и когда его НЕ заявили"
       (search "охват не заявлен" (решить *прошло*)))

(format t "~&── СТЕПЕНЬ НАЗЫВАЕТСЯ РЯДОМ С ВЕРОЙ (ответ на находку второго домена) ──~%")

(defparameter *файл*
  (concatenate 'string (directory-namestring *load-pathname*) "../examples/фармакология.nol"))
(defparameter *фарма*
  (with-open-file (s *файл* :external-format :utf-8)
    (let ((d (make-string (file-length s)))) (subseq d 0 (read-sequence d s)))))

(check "🔴 когда степень основания — ДНО, вердикт говорит это отдельной строкой"
       (search "СТЕПЕНЬ ОСНОВАНИЯ — ДНО РЕШЁТКИ" (решить *фарма*)))
(check "…и объясняет, ПОЧЕМУ гейт всё равно пропустил"
       (search "он стоит на массе" (решить *фарма*)))
(check "🔴 но семантика гейта НЕ изменена: действие всё равно совершено"
       (let ((v (find :performed (decide *фарма*) :key #'verdict-kind)))
         (and v (>= (verdict-belief v) (verdict-threshold v)))))
(check "степень взята в решётке ПРОГРАММЫ, а не прелюдии"
       (let ((v (find :performed (decide *фарма*) :key #'verdict-kind)))
         (and v (search "недоступно" (verdict-grade-text v))
              (verdict-grade-bottom-p v))))
(check "свёрток не удвоен: он лежит и на складе, и в журнале, а вердикт о нём один"
       (= 1 (count :folded (decide *свернулось*) :key #'verdict-kind)))
(check "осиротение и непоправимость — РАЗНЫЕ вердикты об одном действии"
       (let ((vs (decide *фарма*)))
         (and (find :orphaned vs :key #'verdict-kind)
              (find :irreparable vs :key #'verdict-kind))))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
