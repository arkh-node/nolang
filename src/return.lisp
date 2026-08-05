;;;; nolang src 02 — return. Bridge gate ↔ ilan. Implements return (roadmap: ilan fold/sprout).
;;;; :fold-first stops being a mere marker: under low confidence the agent FOLDS (ilan),
;;;; acts reversibly, and on refutation SPROUTS back — REMEMBERING the crossing (not amnesia).
;;;; Crossing memory (crossing = path class) is our contribution: sprout remembers it went, and won't blindly repeat.

(load (merge-pathnames "gate.lisp" *load-pathname*))          ; atom + gate

;;; ilan: fold / sprout / sow / germinate — ВНЕШНЯЯ зависимость (github.com/arkh-node/ilan).
;;; 🔴 Раньше здесь стояло безусловное (load "../../ilan/ilan.lisp"): тесты были зелены только
;;; у того, у кого ilan лежит соседней папкой. На чистом клоне — падение стеком, а не внятное
;;; «нет зависимости». Найдено прогоном на чистом клоне 05.08.2026: рабочая копия знала то,
;;; чего не несёт репозиторий. Теперь ищем в нескольких местах, не нашли — говорим вслух.
(defparameter *ilan-loaded* nil
  "Загружен ли ilan. NIL — мост gate↔ilan недоступен, зависящее от него пропускается.")

(dolist (p (list (merge-pathnames "../../ilan/ilan.lisp" *load-pathname*)  ; соседний репозиторий
                 (merge-pathnames "../ilan/ilan.lisp" *load-pathname*)     ; вендоренная копия
                 (merge-pathnames "../vendor/ilan/ilan.lisp" *load-pathname*)
                 (let ((env (sb-ext:posix-getenv "ILAN_PATH")))            ; явное указание
                   (when env (merge-pathnames "ilan.lisp"
                                              (concatenate 'string env "/"))))))
  (when (and p (not *ilan-loaded*) (probe-file p))
    (load p)
    (setf *ilan-loaded* t)))

(unless *ilan-loaded*
  (format *error-output*
          "~&;; ilan НЕ НАЙДЕН — мост gate<->ilan выключен.~%~
             ;;   git clone https://github.com/arkh-node/ilan   (рядом с nolang)~%~
             ;;   либо ILAN_PATH=/путь/к/ilan~%~
             ;; Это не поломка nolang: ядро, типы, гейт и батарея работают без него.~%"))

(defun crossings (agent)
  "Crossings the agent has already gone through (list of judgments of the unresolved)."
  (state (branch agent) :crossings '()))

(defun mark-crossing (agent a)
  "Record the crossing BEFORE the snapshot — then it enters the seed and survives the return."
  (setf (state (branch agent) :crossings)
        (cons (natom-judgment a) (crossings agent))))

(defun crossed-p (agent a)
  (member (natom-judgment a) (crossings agent) :test #'equal))

(defun act-under-uncertainty (agent a action &key (seed "/tmp/nol-agent.seed") refuted)
  "gate decides the action class. The return primitive in action:
   already crossed this path → don't guess again; confident-yes → irreversible; undecided → fold, reversible, on-refute sprout remembering."
  (cond
    ((crossed-p agent a) :already-crossed)          ; already crossed → don't blindly repeat
    (t (case (permit a :irreversible)
         (:allowed  (funcall action))               ; confident and holds → irreversible allowed
         (:denied   :aborted)                        ; confident it doesn't hold → refuse
         (:fold-first
          (mark-crossing agent a)                   ; mark crossing BEFORE fold (goes into the seed)
          (sow seed)                            ; ilan.fold → to disk (a way back exists)
          (let ((r (funcall action)))               ; reversible action
            (if (and refuted (funcall refuted r))
                (progn (germinate seed)                ; ilan.sprout ← return...
                       :sprouted-remembering)        ; ...but crossing already in the seed: I remember I went
                :kept)))))))
