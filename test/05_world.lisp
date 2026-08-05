;;;; test/05_world.lisp — a real rollback of the trace in the world. sbcl --script test/05_world.lisp
(load (merge-pathnames "../src/world.lisp" *load-pathname*))

;;; Мир опирается на ilan (снимок состояния через sow/germinate) — внешняя зависимость.
;;; Нет её — пропускаем вслух, как 02_return и 07_nars: отсутствие зависимости и поломка
;;; кода обязаны быть различимы (найдено на чистом клоне 05.08.2026).
(unless *ilan-loaded*
  (format t "~&SKIP 05_world: ilan не найден, снимок мира не проверяется.~%")
  (sb-ext:exit :code 0))

(defparameter *file* "/tmp/nol-world.txt")

(defun write-file (path text)
  (with-open-file (s path :direction :output :if-exists :supersede :if-does-not-exist :create) (princ text s)))
(defun read-file (path)
  (if (probe-file path)
      (with-open-file (s path :external-format :utf-8)
        (let* ((b (make-string (file-length s))) (n (read-sequence b s)))
          (subseq b 0 n)))   ; trim to chars ACTUALLY read (file-length counts bytes; multibyte ⇒ bytes > chars)
      ""))

(graft 'agent :state (list :crossings nil))

;; original state of the world
(write-file *file* "ORIGINAL")
(defparameter *before* (read-file *file*))
(format t "~&world before the action:  ~s~%" *before*)

;; reversible effect: append (undo = restore the original)
(defparameter *append-fx*
  (let ((original (read-file *file*)))
    (make-effect :description "append to the file"
                 :run  (lambda () (write-file *file* (concatenate 'string original " +CHANGE")))
                 :undo (lambda () (write-file *file* original)))))

;; agent acts under UNCERTAINTY and is refuted → rollback of the world AND itself
(defparameter *subj* (make-natom '(safe change) 0.6 0.3 "guess"))  ; c=0.3 < θ → undecided
(format t "~%action under uncertainty (c=0.3), then refutation:~%")
(let ((result (act-in-world 'agent *subj* *append-fx* :refuted (lambda () t))))
  (format t "  result: ~s~%" result))
(defparameter *after* (read-file *file*))
(format t "  world after the rollback: ~s~%" *after*)
(format t "  BY COUNT: before == after ? ~a   ← the trace in the world is rolled back~%" (string= *before* *after*))

;; irreversible effect (undo = nil) under uncertainty — blocked
(format t "~%irreversible action (no undo) under the same uncertainty:~%")
(graft 'agent :state (list :crossings nil))
(defparameter *delete-fx* (make-effect :description "delete the file (irreversible)" :run (lambda () :deleted) :undo nil))
(format t "  result: ~s   ← the language did NOT allow the irreversible under uncertainty~%"
        (act-in-world 'agent (make-natom '(safe delete) 0.6 0.3 "guess") *delete-fx* :refuted (lambda () t)))

(format t "~%  State AND the world's trace roll back together. The non-undoable without confidence does not pass — this is protection.~%")
