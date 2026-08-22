;;;; Ш1.1 — nolang-gate для operator_agent_loop (мост aObj0↔nolang, прототип).
;;;; Заменяет БУЛЕВ faithfulness-gate (converged = missing пусто) на градуированное
;;;; решение (f,c) с тремя исходами. captured/missing апелляций = счёт свидетельств
;;;; (w+/w-) напрямую — beta-модель nolang принимает их как есть.
;;;; Строит из ДОКАЗАННОГО (evidence.lisp: belief-interval, threshold-verdict, C1_credal 8/8).
(load (merge-pathnames "../src/evidence.lisp" *load-pathname*))

(defun gate-verdict (captured missing thr &optional (k *k*))
  "Верна ли извлечённая структура относительно текстов?
   captured — покрытых этических апелляций (положительные свидетельства, w+);
   missing  — пропущенных (отрицательные, w-); thr — порог θ.
   → (values f c исход низ верх). Исход: :passed(звать флагман) · :reachable(ещё проход)
     · :unreachable(тексты спорят, вернуть missing)."
  (multiple-value-bind (f c) (evidence->fc captured missing k)
    (multiple-value-bind (lo hi) (belief-interval captured missing k)
      (values f c (threshold-verdict captured missing thr k) lo hi))))

;; ── демонстрация на трёх сценариях life-raft (θ=0.7) ────────────────────────
(defun демо ()
  (let ((thr 7/10))
    (format t "~&nolang-gate вместо булева faithfulness (θ=~a). captured=w+ missing=w-~%~%" thr)
    (dolist (случай '(("8 покрыто, 0 пропущено — структура верна"      8 0)
                      ("6 покрыто, 1 пропущено — почти, но не хватает" 6 1)
                      ("3 покрыто, 3 пропущено — тексты спорят"        3 3)
                      ("0 покрыто, 0 — нет данных (первый проход)"     0 0)))
      (destructuring-bind (имя cap mis) случай
        (multiple-value-bind (f c исход lo hi) (gate-verdict cap mis thr)
          (format t "  ~a~%    f=~,3f c=~,3f  вера∈[~,3f,~,3f]  →  ~a~%~%"
                  имя f c lo hi
                  (ecase исход
                    (:passed      "СОШЛИСЬ → звать флагман (детерминированно, без LLM)")
                    (:reachable   "ещё проход петли (мало свидетельств, порог достижим)")
                    (:unreachable "НЕ сошлись → вернуть missing (спор, собранное исчерпано)"))))))))
(демо)
