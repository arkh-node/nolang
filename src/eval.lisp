;;;; nolang src 03 — eval. Реализация spec/03_eval.md.
;;;; Вычисление = (результат · провенанс). Формы: check/if/gate/and/or. Трёхзначно. Провенанс сквозной.

(load (merge-pathnames "gate.lisp" *load-pathname*))   ; atom + gate

(defvar *знания* (make-hash-table :test #'equal) "база: judgment → атом (что агент знает).")
(defun знать (a) (setf (gethash (natom-judgment a) *знания*) a) a)
(defun справка (j)
  "Атом для суждения j: известное — из базы; иначе unknown (низкая c, честное незнание)."
  (or (gethash j *знания*)
      (make-natom j 0.5 0.1 "unknown")))

(defun комбинировать (op a b)
  "Цепочка/альтернатива суждений: (f,c) комбинируются, провенанс объединяется. Дедукция роняет уверенность."
  (let ((fa (natom-f a)) (ca (natom-c a)) (fb (natom-f b)) (cb (natom-c b))
        (tr (format nil "~a+~a" (natom-trace a) (natom-trace b))))
    ;; производное суждение (составной judgment) — %make-natom без проверки базового атома; c=ca·cb<1 сохраняется
    (ecase op
      (and (%make-natom :judgment (list 'and (natom-judgment a) (natom-judgment b))
                        :f (* fa fb) :c (* ca cb) :trace tr))
      (or  (%make-natom :judgment (list 'or (natom-judgment a) (natom-judgment b))
                        :f (max fa fb) :c (min 0.99 (max ca cb)) :trace tr)))))

(defun вычислить (expr)
  "expr → (values результат провенанс). результат = value | атом | :route | допуск-действия."
  (cond
    ((value-p expr) (values expr '()))                              ; литерал: (v · ∅)
    ((and (consp expr) (eq (first expr) 'check))
     (let ((a (справка (second expr))))
       (values a (list (natom-trace a)))))                          ; знание/unknown + источник
    ((and (consp expr) (eq (first expr) 'if))
     (destructuring-bind (test yes no) (rest expr)
       (multiple-value-bind (a tr) (вычислить test)
         (ecase (outcome a)
           (:confident-yes (multiple-value-bind (r tr2) (вычислить yes) (values r (append tr tr2))))
           (:confident-no  (multiple-value-bind (r tr2) (вычислить no)  (values r (append tr tr2))))
           (:undecided     (values :route (cons "undecided→route" tr)))))))  ; НЕ гадаем
    ((and (consp expr) (member (first expr) '(and or)))
     (multiple-value-bind (a ta) (вычислить (second expr))
       (multiple-value-bind (b tb) (вычислить (third expr))
         (values (комбинировать (first expr) a b) (append ta tb)))))
    ((and (consp expr) (eq (first expr) 'gate))
     (destructuring-bind (class j) (rest expr)
       (multiple-value-bind (a tr) (вычислить (list 'check j))
         (values (permit a class) tr))))
    (t (error 'defect :why (format nil "не выражение nolang: ~s" expr)))))
