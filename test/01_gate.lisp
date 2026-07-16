;;;; test/01_gate.lisp — gate над нашими атомами. sbcl --script test/01_gate.lisp
(load (merge-pathnames "../src/gate.lisp" *load-pathname*))

(defun a! (j f c tr) (make-natom j f c tr))

(defparameter *атомы*
  (list (a! '(safe migration)  0.9 0.7 "ci:run-4412")      ; уверены, держится
        (a! '(subject ари)     0.5 0.4 "zenodo:21288590")  ; НЕ уверены (c<θ)
        (a! '(continuous ари)  0.7 0.6 "verkh:воскрешение"); уверены, держится
        (a! '(safe deploy)     0.2 0.8 "audit:failed")))   ; уверены, НЕ держится

(format t "~&── трёхзначный исход и capability (θ=~a) ──~%" *theta*)
(format t " атом                    (f . c)   исход           reversible  irreversible~%")
(format t "─────────────────────────────────────────────────────────────────────────~%")
(dolist (a *атомы*)
  (format t "  ~22s (~a.~a)  ~14a  ~10a  ~s~%"
          (natom-judgment a) (natom-f a) (natom-c a)
          (outcome a) (permit a :reversible) (permit a :irreversible)))

(format t "~%── nif: язык ВЫБИРАЕТ ход по уверенности ──~%")
(dolist (a *атомы*)
  (format t "  ~22s → ~s~%"
          (natom-judgment a)
          (nif a :yes (lambda () :apply)
                 :no  (lambda () :abort)
                 :undecided (lambda () :fold-observe-recheck))))

(format t "~%  Необратимое проходит ТОЛЬКО при confident-yes. Не уверен → снимок и обратимо. Не держится → отказ.~%")
