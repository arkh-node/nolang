;;;; nolang src 05 — world. Реализация spec/05_world.md.
;;;; Настоящий откат: под неуверенностью откатывается СЛЕД В МИРЕ + состояние агента. Необратимое без уверенности заблокировано.

(load (merge-pathnames "return.lisp" *load-pathname*))   ; atom+gate+ilan+return

(defstruct эффект
  описание
  сделать    ; функция: меняет мир
  откатить)  ; функция: возвращает мир. nil ⇒ эффект НЕОБРАТИМ

(defun act-in-world (agent a эффект &key refuted (seed "/tmp/nol-agent.seed"))
  "gate + реальный эффект мира с откатом. Возврат: символ исхода."
  (cond
    ((crossed-p agent a) :already-crossed)
    (t (case (permit a :irreversible)
         (:allowed (funcall (эффект-сделать эффект)) :done-irreversibly)  ; уверены → необратимо
         (:denied  :aborted)
         (:fold-first
          (cond
            ((null (эффект-откатить эффект)) :blocked-irreversible)  ; нет undo под неуверенностью → защита
            (t (mark-crossing agent a)
               (посеять seed)                          ; снимок состояния (ilan)
               (funcall (эффект-сделать эффект))        ; выполнить эффект мира (обратимо — есть undo)
               (cond
                 ((and refuted (funcall refuted))
                  (funcall (эффект-откатить эффект))    ; ← сначала откат СЛЕДА В МИРЕ
                  (взойти seed)                          ; ← затем откат состояния, помня переход
                  :rolled-back-world-and-self)
                 (t :kept)))))))))
