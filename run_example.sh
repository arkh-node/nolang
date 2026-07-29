#!/usr/bin/env bash
# Прогон .nol-программы: разбор → проверка → выполнение → показ.
cd "$(dirname "$0")" || exit 1
F="${1:?укажите файл .nol}"
cat > /tmp/_nol_run.lisp <<LISP
(load "$(pwd)/src/nolang.lisp")
(let ((src (with-open-file (s "$F" :external-format :utf-8)
             (let ((d (make-string (file-length s))))
               (subseq d 0 (read-sequence d s))))))
  (multiple-value-bind (forms errs) (compile-nolang src)
    (format t "~&── РАЗБОР: ~a объявлений ──~%" (length forms))
    (let ((real (set-difference (mapcar #'terr-code errs) '(:runtime :gate-fail))))
      (if real
          (progn (format t "── ПРОВЕРКА: ОТКЛОНЕНО ──~%") (diagnose forms))
          (progn (format t "── ПРОВЕРКА: принято ──~%")
                 ;; замечания печатаем и при принятой программе: «свернётся, не хватило
                 ;; столько-то» — ради этого статическая свёртка и нужна
                 (when errs (diagnose forms)))))
    (let ((отклонено (set-difference (mapcar #'terr-code errs) '(:runtime :gate-fail))))
      (multiple-value-bind (store ledger) (run-nolang forms :carrier :морф)
        (show-run store ledger :rejected (and отклонено t))))))
LISP
sbcl --script /tmp/_nol_run.lisp
