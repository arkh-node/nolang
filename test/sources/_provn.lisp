;; Вывод наружу: класс, отпечаток и происхождение источника обязаны дожить до PROV-N.
;; Отпечаток здесь ничего не проверяет — его работа дожить неизменным, чтобы на этапе D
;; было с чем сверять при восстановлении.
(load (merge-pathnames "../../src/nolang.lisp" *load-pathname*))
(load (merge-pathnames "../../src/provn.lisp" *load-pathname*))
(defun slurp (p) (with-open-file (s p :external-format :utf-8)
  (let ((o (make-string-output-stream)))
    (loop for l = (read-line s nil nil) while l do (write-line l o))
    (get-output-stream-string o))))
(let* ((dir (directory-namestring *load-pathname*))
       (text (concatenate 'string (slurp (merge-pathnames "ceiling.nolp" dir))
                                  (slurp (merge-pathnames "ceiling_honest.nol" dir)))))
  (with-prelude
    (let ((forms (parse text)))
      (check-program forms)
      (multiple-value-bind (st lg n pend dead srcs) (run-nolang forms :carrier :морф)
        (declare (ignore n pend dead))
        (format t "~&~a~%" (export-provn st lg :sources srcs))))))
