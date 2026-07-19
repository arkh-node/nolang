;;;; nolang src 00 — atom. Implements spec/00_atom.md.
;;;; value vs judgment; atom = judgment + (f . c) + trace. Homoiconic Lisp (SBCL).
;;;; Gate: a judgment must be a relation over values; trace is mandatory (else defect); c < 1 (AIKR).

(defun value-p (x)
  "value (token): a symbol or string/path — NOT a list, no attached truth."
  (or (symbolp x) (stringp x)))

(defun judgment-p (x)
  "judgment: (relation value*) — a list, head = relation (symbol), tail = values."
  (and (consp x) (symbolp (first x)) (every #'value-p (rest x))))

(defstruct (natom (:constructor %make-natom))
  judgment   ; (relation value*) — the relation form
  f          ; frequency ∈ [0,1] — how far it holds
  c          ; confidence ∈ [0,1) — how sure (NEVER 1)
  trace)     ; source (string); empty = defect

(define-condition defect (error)
  ((why :initarg :why :reader why))
  (:report (lambda (c s) (format s "DEFECT: ~a" (why c)))))

(defun make-natom (judgment f c trace)
  "Build an atom, checking the invariants derived from the foundation."
  (cond
    ((not (judgment-p judgment)) (error 'defect :why (format nil "not a judgment: ~s" judgment)))
    ((or (null trace) (and (stringp trace) (string= trace ""))) ; genesis: an atom without a source is a defect
     (error 'defect :why (format nil "atom without a source: ~s" judgment)))
    ((not (< c 1))                                              ; AIKR: c=1 is not allowed
     (error 'defect :why (format nil "c=~a — confidence cannot be 1" c)))
    ((not (and (<= 0 f 1) (<= 0 c 1)))
     (error 'defect :why (format nil "f/c out of [0,1]: ~a ~a" f c)))
    (t (%make-natom :judgment judgment :f f :c c :trace trace))))

(defun denote (a)
  "Denotation of an atom: (relation-applied · graded-truth · provenance)."
  (list :relation-applied (natom-judgment a)
        :graded-truth (cons (natom-f a) (natom-c a))
        :provenance (natom-trace a)))

;; src/atom.lisp — definitions only (library). Tests live in test/00_atom.lisp.
