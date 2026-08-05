;;;; test/02_return.lisp — return under uncertainty. sbcl --script test/02_return.lisp
(load (merge-pathnames "../src/return.lisp" *load-pathname*))

;;; Мост gate<->ilan — внешняя зависимость. Нет её — тест ПРОПУСКАЕТСЯ вслух, а не падает:
;;; отсутствие зависимости и поломка кода должны быть различимы (найдено на чистом клоне 05.08).
(unless *ilan-loaded*
  (format t "~&SKIP 02_return: ilan не найден, мост gate<->ilan не проверяется.~%")
  (sb-ext:exit :code 0))

(graft 'agent :state (list :crossings nil))
(defparameter *subj* (make-natom '(subject ari) 0.5 0.4 "zenodo:21288590"))  ; undecided (c<θ)
(defparameter *mig*  (make-natom '(safe migration) 0.9 0.7 "ci:run-4412"))    ; confident-yes

(format t "~&── agent acts under UNCERTAINTY (subject ari, c=0.4) ──~%")
(format t "  1st pass: ~s~%"
        (act-under-uncertainty 'agent *subj* (lambda () :observed)
                               :refuted (lambda (r) (declare (ignore r)) t)))  ; action refuted
(format t "  crossings in the agent's memory: ~s~%" (crossings 'agent))
(format t "  2nd pass over the same: ~s   ← REMEMBERS it went, doesn't guess again~%"
        (act-under-uncertainty 'agent *subj* (lambda () :observed)))

(format t "~%── agent acts under CONFIDENCE (safe migration, c=0.7) ──~%")
(format t "  irreversibly: ~s   ← confident-yes, no path back needed~%"
        (act-under-uncertainty 'agent *mig* (lambda () :applied)))

(format t "~%  Return is a primitive: unsure → folded, acted reversibly, returned REMEMBERING the crossing.~%")
(format t "  Return without memory of the crossing is amnesia, not freedom. Here the memory exists.~%")
