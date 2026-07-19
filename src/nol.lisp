;;;; nolang src — nol. Reader and runner for .nol programs.
;;;; Homoiconic: a .nol file is s-expressions. `know` declares knowledge; the rest is evaluated.
;;;; This is how nolang runs ITSELF, not our Lisp functions.

(load (merge-pathnames "eval.lisp" *load-pathname*))   ; atom+gate+return? no — eval pulls gate→atom

(defun show-result (r)
  (cond ((natom-p r) (format nil "judgment ~s  (f=~a c=~a)"
                             (natom-judgment r) (natom-f r) (natom-c r)))
        (t (format nil "~s" r))))

(defun run-nol (path)
  "Read and run a .nol program: know → into the knowledge base; an expression → evaluate and show with provenance."
  (format t "~&═══ ~a ═══~%" (file-namestring path))
  (with-open-file (s path :external-format :utf-8)
    (loop for form = (read s nil :eof)
          until (eq form :eof) do
      (if (and (consp form) (eq (first form) 'know))
          (destructuring-bind (j f c tr) (rest form)
            (know (make-natom j f c tr))
            (format t "  · know  ~s   (~a . ~a)~%" j f c))
          (multiple-value-bind (r tr) (evaluate form)
            (format t "  ▸ ~s~%      = ~a~@[   ⟨~{~a~^, ~}⟩~]~%"
                    form (show-result r) tr)))))
  (format t "~%"))
