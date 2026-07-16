;;;; nolang src 01 — gate. Реализация spec/01_gate.md.
;;;; (f,c) РЕШАЕТ класс действия. Трёхзначный if. Монотонно по c. Загружает атом.

(load (merge-pathnames "atom.lisp" *load-pathname*))

(defparameter *theta* 0.5 "порог уверенности: c >= theta = 'уверены'. Монотонность делает выбор безопасным.")

(defun outcome (a &optional (theta *theta*))
  "Трёхзначный исход над атомом: :confident-yes | :confident-no | :undecided."
  (let ((c (natom-c a)) (f (natom-f a)))
    (cond
      ((< c theta) :undecided)        ; не уверены → третья ветвь (не гадаем)
      ((>= f 0.5)  :confident-yes)     ; уверены и держится
      (t           :confident-no))))  ; уверены и не держится

(defun nif (a &key yes no undecided (theta *theta*))
  "Трёхзначный if nolang. undecided НЕ гадает — роутит к иной проверке."
  (ecase (outcome a theta)
    (:confident-yes (if yes (funcall yes) :yes))
    (:confident-no  (if no (funcall no) :no))
    (:undecided     (if undecided (funcall undecided) :route))))

(defun permit (a action-class &optional (theta *theta*))
  "Дозволенность класса действия при уверенности атома (capability effect).
   :reversible всегда; :irreversible только при confident-yes; при undecided → :fold-first (снимок, обратимо)."
  (case action-class
    (:reversible :allowed)
    (:irreversible
     (ecase (outcome a theta)
       (:confident-yes :allowed)
       (:undecided     :fold-first)   ; не запрет — понижение класса: ilan.fold, затем обратимо
       (:confident-no  :denied)))
    (t (error 'defect :why (format nil "неизвестный класс действия: ~s" action-class)))))
