(load (merge-pathnames "../src/parse.lisp" *load-pathname*))

(defparameter *prog* "
lattice provenance = silence < image < tradition < strict

witness report-a : strict
  says \"источник A\"
  source trial-a
  evidence 8 for 1 against

witness report-b : strict
  says \"источник B\"
  source trial-b
  evidence 6 for 1 against

witness reg-check : strict
  says \"реестр чист\"
  source registry
  evidence 4 for 0 against

rule strong_case(a, b) concludes from a, b
rule verdict(a, b, c) concludes from strong_case(a, b), c

claim solid : strict = verdict(report-a, report-b, reg-check)
")

;; само-ссылка: должна ОТКЛОНЯТЬСЯ на разборе (правило не определено ВЫШЕ себя)
(defparameter *self* "
rule loop(x) concludes from loop(x)
")
;; ссылка вперёд: тоже отклоняется
(defparameter *fwd* "
rule a(x) concludes from b(x)
rule b(x) concludes from x
")

(defun chk (name pred) (format t "~&~:[FAIL~;OK~] ~a~%" pred name))

(chk "составная программа (verdict из strong_case) РАЗБИРАЕТСЯ" (parse-ok? *prog*))
(chk "само-ссылка loop(x) from loop(x) ОТКЛОНЕНА" (not (parse-ok? *self*)))
(chk "ссылка-вперёд b до объявления ОТКЛОНЕНА" (not (parse-ok? *fwd*)))
(let ((msg (or (parse-error-of *self*) "")))
  (chk "отказ само-ссылки называет причину (§5-bis/не определено выше)"
       (or (search "не определено" msg) (search "ацикл" msg) (search "5-bis" msg))))
;; и проверяющий принимает составную программу (раскрытие дало реальных свидетелей)
(let* ((forms (parse *prog*)))
  (multiple-value-bind (env errs) (check-program forms)
    (declare (ignore env))
    (chk "проверяющий ПРИНИМАЕТ составную (раскрытие → реальные свидетели)"
         (null (remove :runtime (mapcar #'terr-code errs))))))
