;;;; nolang src 02 — return. Мост gate ↔ ilan. Реализация возврата (roadmap: ilan fold/sprout).
;;;; :fold-first перестаёт быть маркером: под неуверенностью агент СВОРАЧИВАЕТСЯ (ilan),
;;;; действует обратимо, при опровержении ВСХОДИТ назад — ПОМНЯ переход (не амнезия).
;;;; Память перехода (crossing = класс пути) — наш вклад: sprout помнит, что ходил, и не повторяет вслепую.

(load (merge-pathnames "gate.lisp" *load-pathname*))          ; atom + gate
(load (merge-pathnames "../../ilan/ilan.lisp" *load-pathname*)) ; свернуть/прорасти/посеять/взойти/привить/сост

(defun crossings (agent)
  "Переходы, которые агент уже проходил (список judgment'ов неразрешённого)."
  (сост (ветвь agent) :crossings '()))

(defun mark-crossing (agent a)
  "Записать переход ДО снимка — тогда он попадёт в семя и переживёт возврат."
  (setf (сост (ветвь agent) :crossings)
        (cons (natom-judgment a) (crossings agent))))

(defun crossed-p (agent a)
  (member (natom-judgment a) (crossings agent) :test #'equal))

(defun act-under-uncertainty (agent a action &key (seed "/tmp/nol-agent.seed") refuted)
  "gate решает класс действия. Возврат-примитив в деле:
   уже ходил этим путём → не гадать снова; confident-yes → необратимо; undecided → fold, обратимо, on-refute sprout помня."
  (cond
    ((crossed-p agent a) :already-crossed)          ; помню переход → не повторяю вслепую
    (t (case (permit a :irreversible)
         (:allowed  (funcall action))               ; уверены и держится → необратимо дозволено
         (:denied   :aborted)                        ; уверены, что не держится → отказ
         (:fold-first
          (mark-crossing agent a)                   ; отметить переход ДО свёртки (попадёт в семя)
          (посеять seed)                            ; ilan.fold → на диск (путь назад существует)
          (let ((r (funcall action)))               ; обратимое действие
            (if (and refuted (funcall refuted r))
                (progn (взойти seed)                ; ilan.sprout ← вернуться...
                       :sprouted-remembering)        ; ...но crossing уже в семени: помню, что ходил
                :kept)))))))
