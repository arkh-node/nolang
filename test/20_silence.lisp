;;;; test/20_silence.lisp — РАЗВИЛКА МОЛЧАНИЯ, закрытая свойствами.
;;;; Run: sbcl --script test/20_silence.lisp
;;;;
;;;; ВОПРОС (ПРИМЕРЫ_v0.md, пример 3): если утверждение опирается на молчание ЧАСТИЧНО
;;;; (два свидетеля и одно молчание) — падает ли степень до ⊥, или молчание не участвует?
;;;;
;;;; РЕЗОЛЮЦИЯ: ни то, ни другое. Различается не ФАКТ молчания, а его РОЛЬ в выводе.
;;;;   (from ...)     опорная роль — молчание работает посылкой ⇒ степень ⊥
;;;;                  (это argumentum e silentio, и решётка обязана его ловить)
;;;;   (searched ...) обзорная роль — молчание сообщает, ГДЕ искали ⇒ степень не трогает,
;;;;                  но обязано быть напечатано (граница знания видна читателю)
;;;; И третье, без чего первые два обходятся: МОЛЧАНИЕ НЕЛЬЗЯ ВЫБРОСИТЬ. Иначе охват
;;;; скрывается молча, и различие ролей ничего не стоит.
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))

(defun ~= (a b &optional (eps 1e-5)) (< (abs (- a b)) eps))
(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

;;; ── носители ────────────────────────────────────────────────────────────────
(defparameter *grades* '(:silence :obraz :tradition :strogo))
(defun g<= (a b) (<= (position a *grades*) (position b *grades*)))
(defun g-meet (a b) (if (g<= a b) a b))

(defstruct (jud (:constructor jud (id grade f c))) id grade f c)
(defstruct (sil (:constructor sil (id searched reason))) id searched reason)

;;; Молчание в терминах свидетельства: вес НУЛЕВОЙ. Не «пятьдесят на пятьдесят»,
;;; а «свидетельств нет» — (f=0.5, c=0) есть в точности w+=w-=0.
(defun sil-f (s) (declare (ignore s)) 0.5)
(defun sil-c (s) (declare (ignore s)) 0.0)
(defun item-f (x) (if (sil-p x) (sil-f x) (jud-f x)))
(defun item-c (x) (if (sil-p x) (sil-c x) (jud-c x)))
(defun item-id (x) (if (sil-p x) (sil-id x) (jud-id x)))
(defun item-grade (x) (if (sil-p x) :silence (jud-grade x)))

;;; ── must-use: молчание, которое произвели, обязано быть потреблено ───────────
(defvar *pending* nil)
(defun ask (id searched reason)
  "Спросить корпус и не найти. Молчание РЕГИСТРИРУЕТСЯ: его нельзя тихо уронить."
  (let ((s (sil id searched reason))) (push id *pending*) s))
(defun dropped-silences () *pending*)

;;; ── вывод ───────────────────────────────────────────────────────────────────
(defun conclude (&key from searched)
  "⊕ по РАЗЛИЧНЫМ посылкам (дисциплина тождества) · ⊓ по степеням ОПОРНЫХ посылок.
   searched принимает ТОЛЬКО молчания и на степень не влияет.
   → (values f c grade coverage)"
  (dolist (x searched)
    (assert (sil-p x) () "обзорная роль принимает только молчание, получено: ~a" x))
  ;; 🔴 ПУСТАЯ ПОСЫЛОЧНАЯ БАЗА = ДНО, а не верх. Формально ⊓ по пустому множеству
  ;; есть верх решётки — и это дало бы [строго] утверждению, за которым НИЧЕГО не стоит.
  ;; Степень — то, что ПРЕДЪЯВЛЕНО; ничего не предъявлено ⇒ ⊥. Значит присвоение степени
  ;; НЕ является гомоморфизмом моноида (∅ ↦ ⊥, а не ∅ ↦ ⊤), и это намеренно.
  (let ((seen (make-hash-table :test #'equal)) (f 0.5) (c 0.0)
        (grade (if (null from) :silence :strogo)))
    (dolist (x from)
      (unless (gethash (item-id x) seen)
        (setf (gethash (item-id x) seen) t)
        (multiple-value-setq (f c) (t-revise f c (item-f x) (item-c x)))
        (setf grade (g-meet grade (item-grade x)))))          ; молчание здесь = ⊥
    (dolist (x (append from searched))                        ; потребили — снять с учёта
      (setf *pending* (remove (item-id x) *pending* :test #'equal)))
    (values f c grade
            (mapcar (lambda (s) (list (sil-id s) (sil-searched s) (sil-reason s)))
                    (remove-if-not #'sil-p (append from searched))))))

;;; ── данные ──────────────────────────────────────────────────────────────────
(defun fresh ()
  (setf *pending* nil)
  (values (jud :report-162 :strogo 0.9 0.6)
          (jud :report-159 :strogo 0.8 0.5)))

(format t "~&── роль молчания в ⊕ (носитель уверенности) ──~%")

(multiple-value-bind (a b) (fresh)
  (let ((s (ask :s1 '(corpus library registry) "свидетелей нет")))
    (multiple-value-bind (f1 c1 g1) (conclude :from (list a b))
      (multiple-value-bind (f2 c2 g2) (conclude :from (list a b s))
        (declare (ignore g1 g2))
        (check "⊕: молчание НЕ меняет ни частоту, ни уверенность (нейтраль моноида)"
               (and (~= f1 f2) (~= c1 c2)))))))

(format t "~&── роль молчания в ⊓ (носитель честности) — СУТЬ РАЗВИЛКИ ──~%")

;;; ОПОРНАЯ роль: «традиция об этом молчит, следовательно…» — argumentum e silentio.
(multiple-value-bind (a b) (fresh)
  (let ((s (ask :s1 '(corpus) "традиция молчит")))
    (multiple-value-bind (f c g) (conclude :from (list a b s))
      (declare (ignore f))
      (check "ОПОРНОЕ молчание роняет степень до ⊥ — даже при двух [строго]"
             (eq g :silence))
      (check "…но уверенность при этом НЕ ноль — операции меряют РАЗНОЕ"
             (> c 0.5)))))

;;; ОБЗОРНАЯ роль: «мы искали здесь и здесь — там пусто» — отчёт об охвате.
(multiple-value-bind (a b) (fresh)
  (let ((s (ask :s1 '(corpus library) "в этих сводах пусто")))
    (multiple-value-bind (f c g cov) (conclude :from (list a b) :searched (list s))
      (declare (ignore f c))
      (check "ОБЗОРНОЕ молчание степень НЕ роняет: [строго] остаётся [строго]"
             (eq g :strogo))
      (check "…но охват записан и печатается — граница знания видна"
             (and (= 1 (length cov)) (equal '(corpus library) (second (first cov))))))))

;;; Обзор инертен к ОБЕИМ операциям — это и делает его честным отчётом, а не доводом.
(multiple-value-bind (a b) (fresh)
  (let ((s1 (ask :s1 '(corpus) "пусто")) (s2 (ask :s2 '(registry) "пусто")))
    (multiple-value-bind (f1 c1 g1) (conclude :from (list a b))
      (multiple-value-bind (f2 c2 g2) (conclude :from (list a b) :searched (list s1 s2))
        (check "обзор ИНЕРТЕН: сколько ни добавляй, f, c и степень неподвижны"
               (and (~= f1 f2) (~= c1 c2) (eq g1 g2)))))))

(format t "~&── вырожденный случай: обе операции говорят одно ──~%")

(progn
  (setf *pending* nil)
  (let ((s (ask :s1 '(corpus library registry) "свидетелей нет")))
    (multiple-value-bind (f c g) (conclude :from (list s))
      (check "опора ТОЛЬКО на молчание: c = 0 и степень = ⊥ одновременно"
             (and (~= f 0.5) (~= c 0.0) (eq g :silence))))))

(format t "~&── молчание нельзя выбросить (must-use) ──~%")

(progn
  (setf *pending* nil)
  (multiple-value-bind (a b) (values (jud :a :strogo 0.9 0.6) (jud :b :strogo 0.8 0.5))
    (ask :s-lost '(corpus) "спросили и забыли")                ; произвели и НЕ потребили
    (conclude :from (list a b))
    (check "уроненное молчание видно: охват скрыть нельзя"
           (equal '(:s-lost) (dropped-silences)))))

(progn
  (setf *pending* nil)
  (multiple-value-bind (a b) (values (jud :a :strogo 0.9 0.6) (jud :b :strogo 0.8 0.5))
    (let ((s (ask :s-used '(corpus) "спросили и записали")))
      (conclude :from (list a b) :searched (list s))
      (check "потреблённое молчание с учёта снято — долгов нет"
             (null (dropped-silences))))))

(format t "~&── обзорная роль не принимает свидетельств (слоты не путаются) ──~%")

(check "в searched нельзя подсунуть свидетеля — это была бы отмывка через чёрный ход"
       (handler-case
           (progn (conclude :from nil :searched (list (jud :x :strogo 0.9 0.6))) nil)
         (error () t)))

(format t "~&── пустая посылочная база: ⊓ по ∅ есть верх, но степень — дно ──~%")

(progn
  (setf *pending* nil)
  (multiple-value-bind (f c g) (conclude :from nil)
    (check "утверждение без посылок: степень ⊥, не [строго] (отмывание из ничего)"
           (and (eq g :silence) (~= c 0.0) (~= f 0.5)))))

(progn
  (setf *pending* nil)
  (let ((s (ask :s1 '(corpus) "пусто")))
    (multiple-value-bind (f c g) (conclude :from nil :searched (list s))
      (declare (ignore f c))
      (check "обзор без опор степень не поднимает: искали — не значит нашли"
             (eq g :silence)))))

(format t "~&── дисциплина тождества держится и на молчаниях ──~%")

(progn
  (setf *pending* nil)
  (let ((s (ask :s1 '(corpus) "пусто")))
    (multiple-value-bind (f1 c1 g1) (conclude :from (list s s s))
      (setf *pending* nil)
      (let ((s2 (ask :s1 '(corpus) "пусто")))
        (multiple-value-bind (f2 c2 g2) (conclude :from (list s2))
          (check "трижды повторённое молчание = одно молчание"
                 (and (~= f1 f2) (~= c1 c2) (eq g1 g2))))))))

(format t "~%── ALL GREEN · свойств проверено: ~a ──~%" *n*)
(format t "~&РЕЗОЛЮЦИЯ РАЗВИЛКИ: роль, а не факт.~%~
           опорное молчание ⇒ ⊥ (аргумент от молчания пойман решёткой)~%~
           обзорное молчание ⇒ степень цела, охват напечатан~%~
           выбросить молчание нельзя ⇒ различие ролей нельзя обойти умолчанием~%")
