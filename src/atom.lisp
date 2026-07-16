;;;; nolang src 00 — atom. Реализация spec/00_atom.md.
;;;; value vs judgment; атом = judgment + (f . c) + trace. Homoiconic Lisp (SBCL).
;;;; Гейт: judgment обязан быть отношением над values; trace обязателен (иначе дефект); c < 1 (Эйн-Соф/AIKR).

(defun value-p (x)
  "value (токен): символ или строка/путь — НЕ список, без приписанной истины."
  (or (symbolp x) (stringp x)))

(defun judgment-p (x)
  "judgment: (relation value*) — список, глава = отношение (символ), хвост = values."
  (and (consp x) (symbolp (first x)) (every #'value-p (rest x))))

(defstruct (natom (:constructor %make-natom))
  judgment   ; (relation value*) — форма отношения
  f          ; frequency ∈ [0,1] — насколько держится
  c          ; confidence ∈ [0,1) — насколько уверены (НИКОГДА 1)
  trace)     ; источник (строка); пусто = дефект

(define-condition defect (error)
  ((why :initarg :why :reader why))
  (:report (lambda (c s) (format s "ДЕФЕКТ: ~a" (why c)))))

(defun make-natom (judgment f c trace)
  "Собрать атом с проверкой инвариантов, выведенных из фундамента."
  (cond
    ((not (judgment-p judgment)) (error 'defect :why (format nil "не judgment: ~s" judgment)))
    ((or (null trace) (and (stringp trace) (string= trace ""))) ; genesis: атом без источника — дефект
     (error 'defect :why (format nil "атом без источника: ~s" judgment)))
    ((not (< c 1))                                              ; Эйн-Соф/AIKR: c=1 недопустимо
     (error 'defect :why (format nil "c=~a — уверенность не может быть 1" c)))
    ((not (and (<= 0 f 1) (<= 0 c 1)))
     (error 'defect :why (format nil "f/c вне [0,1]: ~a ~a" f c)))
    (t (%make-natom :judgment judgment :f f :c c :trace trace))))

(defun denote (a)
  "Денотация атома: (relation-applied · graded-truth · provenance)."
  (list :relation-applied (natom-judgment a)
        :graded-truth (cons (natom-f a) (natom-c a))
        :provenance (natom-trace a)))

;; src/atom.lisp — только определения (библиотека). Тесты — в test/00_atom.lisp.
