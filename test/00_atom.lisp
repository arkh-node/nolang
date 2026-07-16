;;;; test/00_atom.lisp — тест атома. Запуск: sbcl --script test/00_atom.lisp
(load (merge-pathnames "../src/atom.lisp" *load-pathname*))

(defun try (label thunk)
  (handler-case (format t "  ~22a → ~s~%" label (funcall thunk))
    (defect (e) (format t "  ~22a → отвергнут: ~a~%" label e))))

(format t "~&── value vs judgment (различение токена и атома-отношения) ──~%")
(dolist (x '(ари "soul0:self_definition" (subject ари) (safe migration)))
  (format t "  ~30s  value=~a  judgment=~a~%" x (value-p x) (judgment-p x)))

(format t "~%── сборка атома и денотация ──~%")
(try "(subject ари)"    (lambda () (denote (make-natom '(subject ари) 0.5 0.4 "zenodo:21288590"))))
(try "(continuous ари)" (lambda () (denote (make-natom '(continuous ари) 0.7 0.6 "verkh:воскрешение"))))
(try "(safe migration)" (lambda () (denote (make-natom '(safe migration) 0.9 0.7 "ci:run-4412"))))

(format t "~%── гейт отвергает дефекты (выведенные законы) ──~%")
(try "без источника"   (lambda () (denote (make-natom '(subject ари) 0.5 0.4 ""))))
(try "c = 1 (Эйн-Соф)" (lambda () (denote (make-natom '(safe deploy) 1.0 1.0 "log"))))
(try "не judgment"     (lambda () (denote (make-natom 'ари 0.5 0.4 "x"))))
(format t "~%  Атом собирается только когда несёт отношение, (f,c) и источник. Иначе — дефект.~%")
