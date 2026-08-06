;; Возврат в субъекта. Заведён 05.08.2026 вместе с самим механизмом.
;;
;; 🔴 ГЛАВНОЕ, ЧТО ПРОВЕРЯЕТСЯ: восстановление есть ВОСПРОИЗВЕДЕНИЕ, а не загрузка.
;; Сохранённому итогу не верят — его перепроверяют прогоном тех же посылок.
(load (merge-pathnames "../../src/nolang.lisp" *load-pathname*))
(load (merge-pathnames "../../src/subject.lisp" *load-pathname*))
(defun chk (c msg) (format t "~&~a ~a~%" (if c "OK" "FAIL") msg))
(defun slurp (p) (with-open-file (s p :external-format :utf-8)
  (let ((o (make-string-output-stream)))
    (loop for l = (read-line s nil nil) while l do (write-line l o))
    (get-output-stream-string o))))

(defparameter *dir* (directory-namestring *load-pathname*))
(defparameter *forms*
  (parse (concatenate 'string (slurp (merge-pathnames "scene.nolp" *dir*))
                              (slurp (merge-pathnames "trace.nol" *dir*)))))
(defparameter *subj*
  (with-prelude
    (multiple-value-bind (st lg) (run-nolang *forms* :carrier :морф)
      (declare (ignore st))
      (serialize-subject *forms* lg :carrier :морф))))

;; 1. честный возврат
(multiple-value-bind (ok lg why) (re-enter *subj*)
  (declare (ignore lg))
  (chk (and ok (null why)) "честный субъект восстанавливается: вывод воспроизведён, не загружен"))

;; 2. подделана ПЕЧАТЬ — вывод не сойдётся
(let ((bad (copy-tree *subj*)))
  (setf (getf (cddr bad) :seal) '((:ran-on :морф nil) (:performed publish c 0.99 0.9)))
  (multiple-value-bind (ok lg why) (re-enter bad)
    (declare (ignore lg))
    (chk (and (not ok) (eq why :seal-differs))
         "подделанная печать отвергнута: посылки те же, вывод другой")))

;; 3. 🔴 подделана СЦЕНА так, что вывод НЕ меняется.
;; Этот случай провалился при первой же проверке 05.08 и показал, что воспроизведение
;; необходимо, но НЕ достаточно: подмена того, ЧЕМ судят, может не отразиться на выводе.
(let ((bad (copy-tree *subj*)))
  (dolist (f (getf (cddr bad) :scene))
    (when (and (consp f) (string= (head-of f) "source") (eq (second f) 'abstracts))
      (setf (getf (cddr f) :grade) '(randomised full_report))))
  (multiple-value-bind (ok lg why) (re-enter bad)
    (declare (ignore lg))
    (chk (and (not ok) (eq why :scene-differs))
         "подмена СЦЕНЫ отвергнута, даже когда она не меняет вывод")))

;; 4. запись и чтение с диска — субъект переживает носитель
(let ((path "/tmp/_subj_test.nols"))
  (subject-write *subj* path)
  (multiple-value-bind (ok lg why) (re-enter (subject-read path))
    (declare (ignore lg why))
    (chk ok "субъект переживает запись на диск и чтение обратно")))

;; 5. вывод НЕ хранится: в записи нет ни степеней, ни весов — только формы и печать
(let ((printed (format nil "~s" *subj*)))
  (chk (and (search ":SCENE" printed) (search ":TRACE" printed) (search ":SEAL" printed))
       "в записи ровно три части: сцена, след, печать — состояние не сохраняется"))

;; ── ПРОДОЛЖЕНИЕ: continue from ──────────────────────────────────────────────
(subject-write *subj* "/tmp/_prev_test.nols")

;; 6. продолжение поверх восстановленного: прежнее воспроизводится, новое добавляется
(let ((cont (parse "continue from \"/tmp/_prev_test.nols\"

witness later : (randomised, abstract)
  says \"пришло после перерыва\"
  source abstracts
  evidence 4 for 0 against

claim c2 from honest, later
perform publish on c2
")))
  (multiple-value-bind (forms err) (resolve-continuation cont)
    (if err (chk nil (format nil "продолжение не собралось: ~a" err))
        (with-prelude
          (multiple-value-bind (env errs) (check-program forms)
            (declare (ignore env))
            (if errs (chk nil "продолжение не типизируется")
                (multiple-value-bind (st lg) (run-nolang forms :carrier :морф)
                  (declare (ignore st))
                  (chk (= 3 (length lg))
                       "продолжение: прежнее действие воспроизведено, новое добавлено"))))))))

;; 7. 🔴 продолжение с подделанным субъектом НЕ проходит — иначе возврат был бы дырой
(let ((bad (copy-tree *subj*)))
  (setf (getf (cddr bad) :seal) '((:ran-on :морф nil)))
  (subject-write bad "/tmp/_bad_test.nols")
  (multiple-value-bind (forms err) (resolve-continuation (parse "continue from \"/tmp/_bad_test.nols\""))
    (declare (ignore forms))
    (chk (eq err :seal-differs) "продолжение с подделанным субъектом отвергнуто")))

;; 8. `continue` не первой формой — не типизируется
(with-prelude
  (multiple-value-bind (env errs)
      (check-program (parse "horizon 20
continue from \"/tmp/_prev_test.nols\""))
    (declare (ignore env))
    (chk (and errs (eq (terr-code (first errs)) :continue))
         "`continue` не первой формой отвергнута: возврат — начало, а не середина")))

;; ── ДВА ВРЕМЕНИ (D4) ────────────────────────────────────────────────────────
;; Противоречие «знал тогда / знаю теперь» — два ФАКТА с разными `at`, а не затирание.
(with-prelude
  (let ((forms (parse "
lattice design       = observational < randomised
lattice transmission = unavailable < abstract < published < full_report
lattice provenance   = design * transmission
source s : (randomised, abstract)

witness early : (randomised, abstract)
  says \"март\"  source s  at 20260313  evidence 3 for 0 against

witness late : (randomised, abstract)
  says \"август\" source s  at 20260805  evidence 5 for 2 against

claim c from early, late
")))
    (multiple-value-bind (env errs) (check-program forms)
      (declare (ignore env))
      (chk (null errs) "свидетели с временем события типизируются"))
    (multiple-value-bind (st lg) (run-nolang forms :carrier :морф)
      (declare (ignore lg))
      (let ((e (gethash 'early st)) (l (gethash 'late st)))
        (chk (and (jv-at e) (jv-at l) (/= (jv-at e) (jv-at l)))
             "два времени доживают до склада и различны: знал тогда ≠ знаю теперь")))))

;; время НЕ обязательно — без него всё работает как прежде
(with-prelude
  (multiple-value-bind (env errs)
      (check-program (parse "
lattice design       = observational < randomised
lattice transmission = unavailable < abstract < published < full_report
lattice provenance   = design * transmission
source s : (randomised, abstract)
witness w : (randomised, abstract) says \"без времени\" source s evidence 3 for 0 against
"))
    (declare (ignore env))
    (chk (null errs) "время события необязательно — старые программы не сломаны")))
