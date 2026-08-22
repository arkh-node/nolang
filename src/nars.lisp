;;;; nolang src 06 — nars. Implements spec/06_substrate.md.
;;;; Bridge to a reasoning substrate: a nolang judgment → Narsese → NARS infers → back into an atom.
;;;; (f,c) ↔ NARS (frequency,confidence) — direct correspondence (AIKR). The language hands off inference rather than faking it.

(load (merge-pathnames "atom.lisp" *load-pathname*))

(defparameter *nar* (or (sb-ext:posix-getenv "NAR") "NAR")
  "Path to ONA's NAR binary. Override with the NAR env var; defaults to 'NAR' on PATH.")

(defun ->narsese (a)
  "atom (isa X Y)@(f.c) → a Narsese string '<X --> Y>. %f;c%'."
  (destructuring-bind (rel x y) (natom-judgment a)
    (declare (ignore rel))
    (format nil "<~(~a~) --> ~(~a~)>. %~,2f;~,2f%" x y (natom-f a) (natom-c a))))

(defun %extract (str key)
  "from '…frequency=0.81, confidence=0.66…' pull the number after key=."
  (let ((p (search key str)))
    (when p
      (let ((start (+ p (length key))))
        (read-from-string str nil nil :start start)))))

(defun nars-ask (facts query-judgment)
  "Send facts (atoms) to NARS, ask for the conclusion on the query. Returns: atom (f,c from NARS) or unknown."
  (destructuring-bind (rel x y) query-judgment
    (declare (ignore rel))
    (let* ((input (with-output-to-string (s)
                   (dolist (a facts) (write-line (->narsese a) s))
                   (write-line "100" s)                         ; inference cycles
                   (format s "<~(~a~) --> ~(~a~)>?~%" x y)))    ; query
           (output (with-output-to-string (out)
                    (sb-ext:run-program *nar* '("shell")
                                        :input (make-string-input-stream input)
                                        :output out :error nil)))
           (ans-pos (search "Answer:" output)))
      (if ans-pos
          (let* ((tail (subseq output ans-pos))
                 (f (%extract tail "frequency="))
                 (c (%extract tail "confidence=")))
            (if (and f c)
                (%make-natom :judgment query-judgment :f f :c c :trace "nars:output")
                (%make-natom :judgment query-judgment :f 0.5 :c 0.1 :trace "nars:no-answer")))
          (%make-natom :judgment query-judgment :f 0.5 :c 0.1 :trace "nars:no-answer")))))

;;;; Э2/Ш2.3 (15.08.2026) — обратная связь NARS→(f,c) в решающий путь.
;;;; NARS как НЕЗАВИСИМЫЙ корень: выводит то же суждение из фактов своей цепочкой,
;;;; ревизуем его в исходный атом (c растёт по РАЗНОМУ корню — t-revise/revise-atoms).
(defun nars-revise (judgment-atom facts)
  "NARS-feedback: вывести суждение judgment-atom из facts через NARS и ревизовать как
   НЕЗАВИСИМЫЙ корень (c растёт). Возвращает ревизованный атом.
   🔴 Честная граница: revise-atoms суммирует свидетельства как НЕЗАВИСИМЫЕ. Корректно, только
   если цепочка NARS и цепочка исходного атома РАЗНЫЕ (нет общего свидетеля) — иначе двойной счёт."
  (revise-atoms judgment-atom (nars-ask facts (natom-judgment judgment-atom))))
