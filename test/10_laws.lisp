;;;; test/10_laws.lisp — ЗАКОНЫ алгебры, а не случаи. Run: sbcl --script test/10_laws.lisp
;;;;
;;;; Порядок работ Ф3: примеры → АЛГЕБРА И ЕЁ ЗАКОНЫ → типы. Типы, поставленные раньше
;;;; алгебры, узаконят неверную алгебру (баг `c=ca·cb` в публичном main, 25.07).
;;;; Здесь законы проверяются СВОЙСТВАМИ на случайных входах, а не отдельными примерами.
;;;;
;;;; Две операции языка живут на РАЗНЫХ носителях и имеют разный алгебраический характер:
;;;;   ⊕  ревизия уверенностей  — коммутативный МОНОИД (накопление; НЕ идемпотентен)
;;;;   ⊓  нижняя грань степеней — ограниченная ПОЛУРЕШЁТКА (деградация; идемпотентна)
;;;; Разница характеров и есть ядро замысла: вера накапливается, честность деградирует.
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))

(defun ~= (a b &optional (eps 1e-5)) (< (abs (- a b)) eps))
(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun rnd-f () (+ 0.01 (random 0.98)))          ; частота в (0,1)
(defun rnd-c () (+ 0.01 (random 0.90)))          ; уверенность < 1 — граница Эйн-Соф
(defparameter *trials* 200)

(format t "~&── ⊕ РЕВИЗИЯ: коммутативный моноид ──~%")

(let ((ok t))
  (dotimes (i *trials*)
    (let ((fa (rnd-f)) (ca (rnd-c)) (fb (rnd-f)) (cb (rnd-c)))
      (multiple-value-bind (f1 c1) (t-revise fa ca fb cb)
        (multiple-value-bind (f2 c2) (t-revise fb cb fa ca)
          (unless (and (~= f1 f2) (~= c1 c2)) (setf ok nil))))))
  (check "коммутативность a⊕b = b⊕a (200 случайных)" ok))

(let ((ok t))
  (dotimes (i *trials*)
    (let ((fa (rnd-f)) (ca (rnd-c)) (fb (rnd-f)) (cb (rnd-c)) (fc (rnd-f)) (cc (rnd-c)))
      (multiple-value-bind (fab cab) (t-revise fa ca fb cb)
        (multiple-value-bind (l cl) (t-revise fab cab fc cc)
          (multiple-value-bind (fbc cbc) (t-revise fb cb fc cc)
            (multiple-value-bind (r cr) (t-revise fa ca fbc cbc)
              (unless (and (~= l r) (~= cl cr)) (setf ok nil))))))))
  (check "ассоциативность (a⊕b)⊕c = a⊕(b⊕c) (200 случайных)" ok))

(let ((ok t))
  (dotimes (i *trials*)
    (let ((fa (rnd-f)) (ca (rnd-c)))
      (multiple-value-bind (f c) (t-revise fa ca 0.5 0.0)   ; 0.5,0 = МОЛЧАНИЕ (w=0)
        (unless (and (~= f fa) (~= c ca)) (setf ok nil)))))
  (check "нейтраль: a ⊕ молчание = a — молчание есть единица моноида" ok))

(let ((ok t))
  (dotimes (i *trials*)
    (let* ((f (rnd-f)) (c (rnd-c)))
      (multiple-value-bind (f2 c2) (t-revise f c f c)       ; согласный свидетель
        (declare (ignore f2))
        (unless (> c2 c) (setf ok nil)))))
  (check "монотонность: согласный свидетель ПОВЫШАЕТ уверенность" ok))

;;; 🔴 ИДЕМПОТЕНТНОСТЬ — НЕ закон ⊕, и это правильно.
;;; Ревизия складывает СВИДЕТЕЛЬСТВА; два независимых голоса обязаны усиливать веру.
;;; Значит «не считать одного свидетеля дважды» — не свойство операции, а
;;; ДИСЦИПЛИНА ТОЖДЕСТВА: ⊕ применяется к МНОЖЕСТВУ свидетелей, не к мультимножеству.
(let ((broken 0))
  (dotimes (i *trials*)
    (let ((f (rnd-f)) (c (rnd-c)))
      (multiple-value-bind (f2 c2) (t-revise f c f c)
        (declare (ignore f2))
        (when (> (abs (- c2 c)) 1e-5) (incf broken)))))
  (check "⊕ НЕ идемпотентен (и это верно: свидетельства накапливаются)"
         (= broken *trials*)))

;;; ── дисциплина тождества: свёртка по МНОЖЕСТВУ свидетелей ──
;;; Идемпотентность возвращается здесь — не как свойство ⊕, а как свойство сборки.
(defstruct (wit (:constructor wit (id f c))) id f c)

(defun believe (witnesses)
  "Свернуть ⊕ по РАЗЛИЧНЫМ свидетелям (по id). Повтор — не считается."
  (let ((seen (make-hash-table :test #'equal)) (f 0.5) (c 0.0))
    (dolist (w witnesses (values f c))
      (unless (gethash (wit-id w) seen)
        (setf (gethash (wit-id w) seen) t)
        (multiple-value-setq (f c) (t-revise f c (wit-f w) (wit-c w)))))))

(let* ((a (wit :report-162 0.9 0.6))
       (b (wit :report-159 0.8 0.5)))
  (multiple-value-bind (f1 c1) (believe (list a b))
    (multiple-value-bind (f2 c2) (believe (list a b a b a))   ; тот же набор, с повторами
      (check "дисциплина тождества: повтор свидетеля НЕ усиливает"
             (and (~= f1 f2) (~= c1 c2)))
      (multiple-value-bind (f3 c3) (believe (list a))
        (declare (ignore f3))
        (check "но НОВЫЙ свидетель усиливает" (> c1 c3))))))

(format t "~&── ⊓ СТЕПЕНЬ ПРОВЕНАНСА: ограниченная полурешётка ──~%")

;;; ⊥ (молчание) < образ < традиция < строго — линейный порядок; ⊓ = минимум.
(defparameter *grades* '(:silence :obraz :tradition :strogo))
(defun g<= (a b) (<= (position a *grades*) (position b *grades*)))
(defun g-meet (a b) (if (g<= a b) a b))

(let ((ok t))
  (dolist (a *grades*) (unless (eq (g-meet a a) a) (setf ok nil)))
  (check "идемпотентность a⊓a = a" ok))
(let ((ok t))
  (dolist (a *grades*) (dolist (b *grades*)
    (unless (eq (g-meet a b) (g-meet b a)) (setf ok nil))))
  (check "коммутативность a⊓b = b⊓a" ok))
(let ((ok t))
  (dolist (a *grades*) (dolist (b *grades*) (dolist (c *grades*)
    (unless (eq (g-meet (g-meet a b) c) (g-meet a (g-meet b c))) (setf ok nil)))))
  (check "ассоциативность (a⊓b)⊓c = a⊓(b⊓c)" ok))
(let ((ok t))
  (dolist (a *grades*) (unless (eq (g-meet :silence a) :silence) (setf ok nil)))
  (check "молчание поглощает: ⊥⊓a = ⊥ (дно решётки)" ok))
(let ((ok t))
  (dolist (a *grades*) (unless (eq (g-meet :strogo a) a) (setf ok nil)))
  (check "строго нейтрально сверху: строго⊓a = a" ok))

;;; 🔴 ЗАПРЕТ ОТМЫВАНИЯ — то, ради чего вся решётка.
(check "вывод не выше худшей посылки: образ ⊓ строго = образ"
       (eq (g-meet :obraz :strogo) :obraz))

(format t "~&── асимметрия двух операций (ядро замысла) ──~%")
(check "⊕ накапливает (не идемпотентен), ⊓ деградирует (идемпотентна) — характеры РАЗНЫЕ"
       (and (not (~= (nth-value 1 (t-revise 0.7 0.5 0.7 0.5)) 0.5))
            (eq (g-meet :obraz :obraz) :obraz)))

(format t "~%── ALL GREEN · законов проверено: ~a ──~%" *n*)
