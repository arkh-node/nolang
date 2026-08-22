;;;; Ш1.2 — CLI-обёртка nolang-gate для operator_agent_loop.
;;;; Вызов: sbcl --script gate_judge.lisp <captured> <missing> [thr]
;;;;   captured — покрытых этических апелляций (w+); missing — пропущенных (w-);
;;;;   thr — порог θ (по умолчанию 0.7).
;;;; Печатает ОДНУ строку JSON: {"f":..,"c":..,"lo":..,"hi":..,"outcome":".."}.
;;;; outcome: passed(звать флагман) · reachable(ещё проход) · unreachable(спор→вернуть missing).
;;;; Строит из ДОКАЗАННОГО (evidence.lisp). Латиница в ключах/значениях JSON (ЗАКОН XLIV).
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))

(let* ((args (cdr sb-ext:*posix-argv*))
       (cap  (parse-integer (or (first  args) "0")))
       (mis  (parse-integer (or (second args) "0")))
       (thr  (let ((s (third args))) (if s (read-from-string s) 7/10))))
  (multiple-value-bind (f c) (evidence->fc cap mis)
    (multiple-value-bind (lo hi) (belief-interval cap mis)
      (let ((verdict (threshold-verdict cap mis thr)))
        (format t "{\"f\":~,4f,\"c\":~,4f,\"lo\":~,4f,\"hi\":~,4f,\"outcome\":\"~(~a~)\"}~%"
                (float f 1.0) (float c 1.0) (float lo 1.0) (float hi 1.0) verdict)))))
