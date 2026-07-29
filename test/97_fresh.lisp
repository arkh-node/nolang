;;;; test/97_fresh.lisp — СВЕЖИЙ ОТЗЫВ НЕ ТОПЛИВО ДЛЯ НЕОБРАТИМОГО.
;;;; Run: sbcl --script test/97_fresh.lisp
;;;;
;;;; ПОВОД (Невис, §2 записки 28.07, «одно, чего ты не просил, а надо»): для необратимого
;;;; действия одной ЗАПИСИ об отзыве мало. Отзыв может ПОДНЯТЬ веру — зеркало теоремы 5:
;;;; отозвать оппонента значит укрепить веру. Отсюда атака:
;;;;   вера ниже порога → отозвать неудобного свидетеля → вера прыгнула → публиковать.
;;;;
;;;; 🔴 РЕШЕНИЕ: запрет ставится не на отзыв (иначе ломается добросовестный случай), а на
;;;; использование его КАК ТОПЛИВА. Гейт необратимого берёт ХУДШЕЕ из «до отзывов» и «после».
;;;; Правило верно в обе стороны, и здесь это проверяется обеими.
(load (merge-pathnames "../src/reduce.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun kinds (l) (mapcar #'first l))
(defun ledger-of (p) (nth-value 1 (run-nolang p)))

;;; Веса подобраны СЧЁТОМ: до отзыва b=0.412, после b=0.665. Порог 0.5 лежит МЕЖДУ —
;;; иначе тест был бы пустым: атака не пересекала бы гейт и без правила.
(defparameter *основание*
  '((witness за     "…" :grade строго :f 0.95 :c 0.7 :source (a))
    (witness против "…" :grade строго :f 0.05 :c 0.7 :source (b))
    (claim спорно :grade строго (from за против))))

(format t "~&── ЦИФРЫ, НА КОТОРЫХ СТОИТ ТЕСТ ──~%")

(let ((b-до (belief-at-runtime *основание* 'спорно))
      (b-после (belief-at-runtime (append *основание* '((retract против :reason "…"))) 'спорно)))
  (check "отзыв оппонента ПОДНИМАЕТ веру (иначе атаки бы не было)" (> b-после b-до))
  (check "порог 0.5 лежит между: до 0.412 < 0.5 < после 0.665"
         (and (< b-до 0.5) (> b-после 0.5))))

(format t "~&── 🔴 АТАКА ОТБИТА: необратимое ──~%")

(defparameter *атака*
  (append *основание*
          '((action публикация :reversibility irreversible :requires (>= belief 0.5) :else fold)
            (retract против :reason "мне не нравится этот свидетель")
            (do публикация спорно))))

(check "необратимое СВЁРНУТО, хотя после отзыва вера выше порога"
       (eq :folded (first (find :folded (ledger-of *атака*) :key #'first))))
(check "…и сказано прямо, что связал свежий отзыв"
       (eq :свежий-отзыв-не-в-счёт (seventh (find :folded (ledger-of *атака*) :key #'first))))
(check "в журнале нет :performed — действие не состоялось"
       (not (member :performed (kinds (ledger-of *атака*)))))

(format t "~&── ДОБРОСОВЕСТНЫЙ ОТЗЫВ ПРАВИЛО НЕ ЛОМАЕТ ──~%")

;;; Снимаем СОЮЗНИКА (подделка): вера падает 0.782 → 0.665. Минимум = 0.665, то есть
;;; послеотзывная правда. Порог 0.7 обязан заблокировать — и блокирует по ПРАВИЛЬНОЙ причине.
(defparameter *честный*
  '((witness a "…" :grade строго :f 0.95 :c 0.7 :source (x))
    (witness b "…" :grade строго :f 0.95 :c 0.7 :source (y))
    (claim осн :grade строго (from a b))
    (action публикация :reversibility irreversible :requires (>= belief 0.7) :else fold)
    (retract b :reason "рукопись признана подделкой")
    (do публикация осн)))

(check "честный отзыв понижает веру, и гейт держит по послеотзывной правде"
       (let ((f (find :folded (ledger-of *честный*) :key #'first)))
         (and f (< (abs (- (fourth f) 0.665)) 0.01))))
(check "…и это НЕ помечено как свежий отзыв — связала настоящая вера, а не защита"
       (not (eq :свежий-отзыв-не-в-счёт
                (seventh (find :folded (ledger-of *честный*) :key #'first)))))

(format t "~&── БЕЗ ОТЗЫВОВ ПРАВИЛО НЕ МЕШАЕТ ──~%")

(check "необратимое проходит, когда веры хватает и без всяких отзывов"
       (member :performed
               (kinds (ledger-of
                       '((witness a "…" :grade строго :f 0.97 :c 0.93 :source (x))
                         (witness b "…" :grade строго :f 0.97 :c 0.93 :source (y))
                         (claim осн :grade строго (from a b))
                         (action публ :reversibility irreversible
                                 :requires (>= belief 0.8) :else fold)
                         (do публ осн))))))

(format t "~&── ПРАВИЛО ТОЛЬКО ДЛЯ НЕОБРАТИМОГО ──~%")

;;; Возместимое и обратимое можно откатить — им защита не нужна, и навязывать её значило бы
;;; мешать работе там, где цена ошибки мала.
(check "compensable с тем же отзывом ПРОХОДИТ (его можно возместить)"
       (member :performed
               (kinds (ledger-of
                       (append *основание*
                               '((action отправка :reversibility compensable
                                  :requires (>= belief 0.5) :else fold :compensated-by откат)
                                 (retract против :reason "…")
                                 (do отправка спорно)))))))
(check "reversible тем более проходит"
       (member :performed
               (kinds (ledger-of
                       (append *основание*
                               '((action заметка :reversibility reversible
                                  :requires (>= belief 0.5) :else fold)
                                 (retract против :reason "…")
                                 (do заметка спорно)))))))

(format t "~&── ПОРЯДОК НЕ ЛАЗЕЙКА ──~%")

;;; Отзыв ПОСЛЕ действия — это сирота (ход 28.07), а не обход. Проверяю, что защита
;;; не зависит от того, поставил ли автор отзыв до или после `do`.
(check "отзыв после do даёт сироту, а не тихо совершённое действие"
       (let ((k (kinds (ledger-of
                        (append *основание*
                                '((action публ :reversibility irreversible
                                   :requires (>= belief 0.5) :else fold)
                                  (do публ спорно)
                                  (retract против :reason "…")))))))
         ;; до отзыва вера 0.412 < 0.5 ⇒ действие и так свернулось
         (and (member :folded k) (not (member :performed k)))))

(format t "~&~%── журнал отбитой атаки ──~%")
(show-ledger (ledger-of *атака*))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
