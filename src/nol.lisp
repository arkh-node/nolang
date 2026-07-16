;;;; nolang src 04 — nol. Ридер и исполнитель программ .nol.
;;;; Язык homoiconic: .nol-файл = s-выражения. know объявляет знание; прочее — вычисляется.
;;;; Так nolang исполняет САМ СЕБЯ, а не наши Lisp-функции.

(load (merge-pathnames "eval.lisp" *load-pathname*))   ; atom+gate+return? нет — eval тянет gate→atom

(defun показ-результата (r)
  (cond ((natom-p r) (format nil "суждение ~s  (f=~a c=~a)"
                             (natom-judgment r) (natom-f r) (natom-c r)))
        (t (format nil "~s" r))))

(defun выполнить-nol (путь)
  "Прочитать программу .nol и исполнить: know → в базу знаний; выражение → вычислить и показать с провенансом."
  (format t "~&═══ ~a ═══~%" (file-namestring путь))
  (with-open-file (s путь :external-format :utf-8)
    (loop for форма = (read s nil :конец)
          until (eq форма :конец) do
      (if (and (consp форма) (eq (first форма) 'know))
          (destructuring-bind (j f c tr) (rest форма)
            (знать (make-natom j f c tr))
            (format t "  · знаю  ~s   (~a . ~a)~%" j f c))
          (multiple-value-bind (r tr) (вычислить форма)
            (format t "  ▸ ~s~%      = ~a~@[   ⟨~{~a~^, ~}⟩~]~%"
                    форма (показ-результата r) tr)))))
  (format t "~%"))
