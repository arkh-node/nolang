;;;; nolang src 04 — types. Реализация spec/04_types.md.
;;;; Контракт действия: что требует (предусловия-суждения), какой класс, что даёт (эффект-суждение).
;;;; Незнание предусловия → route (не догадка). Успех → эффект пополняет знание.

(load (merge-pathnames "eval.lisp" *load-pathname*))   ; atom+gate+eval (знать/справка/вычислить/permit)

(defstruct контракт
  имя
  требует   ; список judgment — предусловия (должны быть confident-yes)
  класс     ; :reversible | :irreversible
  даёт)     ; judgment — эффект (новое знание после выполнения)

(defun проверить-требования (треб)
  "Возврат: :ok | (:route j) | (:unmet j) — первое неудовлетворённое предусловие останавливает."
  (dolist (j треб :ok)
    (multiple-value-bind (a tr) (вычислить (list 'check j))
      (declare (ignore tr))
      (ecase (outcome a)
        (:confident-yes)                 ; держится — дальше
        (:undecided    (return (list :route j)))
        (:confident-no (return (list :unmet j)))))))

(defun выполнить-контракт (контракт действие &key (f 0.85) (c 0.7))
  "Проверить предусловия → допуск по классу → выполнить → эффект в знание.
   действие — thunk (реальный эффект). Возврат: (:done эффект) | (:route j) | (:unmet j) | :denied."
  (let ((пров (проверить-требования (контракт-требует контракт))))
    (cond
      ((not (eq пров :ok)) пров)         ; route / unmet — не действуем
      (t (let* ((реш (make-natom (контракт-даёт контракт) f c
                                 (format nil "действие:~a" (контракт-имя контракт))))
                (допуск (permit реш (контракт-класс контракт))))
           (case допуск
             ((:allowed :fold-first)     ; дозволено (или обратимо со снимком)
              (funcall действие)
              (знать реш)                ; эффект пополняет знание, с провенансом действия
              (list :done (контракт-даёт контракт)))
             (:denied :denied)))))))
