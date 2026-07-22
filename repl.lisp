;;; nolang REPL loader — loads the 7 core stones into an interactive SBCL.
;;; Stone 07 (nars.lisp) is the isolated optional bridge and is NOT loaded here.
;;; Launch:  sbcl --load repl.lisp
(let ((base "/srv/langs/nolang/src/"))
  (dolist (stone '("atom" "gate" "return" "eval" "nol" "world" "types"))
    (handler-case (load (format nil "~a~a.lisp" base stone))
      (error (e) (format t "~&  SKIP ~a: ~a~%" stone e)))))
(format t "~%nolang core loaded — 7 stones (atom · gate · return · eval · nol · world · types).~%")
(format t "The NARS bridge (stone 07) stays isolated by design.~%")
(format t "Smoke tests from a shell:  bash test/run.sh~%~%")
