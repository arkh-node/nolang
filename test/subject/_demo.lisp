;; Демонстрация возврата: прерван → восстановлен → продолжил.
;; Печатает машинно-читаемые маркеры; человеку — examples/subject/.
(load (merge-pathnames "../../src/nolang.lisp" *load-pathname*))
(load (merge-pathnames "../../src/subject.lisp" *load-pathname*))
(defun slurp (p) (with-open-file (s p :external-format :utf-8)
  (let ((o (make-string-output-stream)))
    (loop for l = (read-line s nil nil) while l do (write-line l o))
    (get-output-stream-string o))))
(defparameter *d* (merge-pathnames "../../examples/subject/" *load-pathname*))
(defparameter *path* "/tmp/_v7_subject.nols")

;; ── до перерыва ───────────────────────────────────────────────────────────
(defparameter *f1* (parse (concatenate 'string
                            (slurp (merge-pathnames "interrupted.nolp" *d*))
                            (slurp (merge-pathnames "before.nol" *d*)))))
(with-prelude
  (multiple-value-bind (st lg) (run-nolang *f1* :carrier :морф)
    (declare (ignore st))
    (dolist (e lg) (when (eq (first e) :folded) (format t "~&BEFORE FOLDED ~a~%" (third e))))
    (subject-write (serialize-subject *f1* lg :carrier :морф) *path*)))

;; ── после перерыва ────────────────────────────────────────────────────────
(let ((after (slurp (merge-pathnames "after.nol" *d*))))
  ;; путь в примере — демонстрационный; для приёмки подставляем свой
  (setf after (substitute-if #\  (constantly nil) after))
  (let* ((src (with-output-to-string (o)
                (with-input-from-string (in after)
                  (loop for l = (read-line in nil nil) while l
                        do (write-line (if (search "continue from" l)
                                           (format nil "continue from ~s" *path*) l) o)))))
         (forms (parse src)))
    (multiple-value-bind (full err) (resolve-continuation forms)
      (if err (format t "~&RE-ENTRY FAILED ~a~%" err)
          (progn
            (format t "~&SEAL OK~%")
            (with-prelude
              (multiple-value-bind (st lg) (run-nolang full :carrier :морф)
                (declare (ignore st))
                (dolist (e lg)
                  (case (first e)
                    (:folded    (format t "AFTER FOLDED ~a~%" (third e)))
                    (:performed (format t "AFTER PERFORMED ~a~%" (third e)))))))))))) 
