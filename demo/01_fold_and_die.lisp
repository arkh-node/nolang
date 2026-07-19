;;;; demo/01_fold_and_die.lisp
;;;; nolang meets ilan, part 1: an agent unsure of a judgment does NOT guess.
;;;; nolang's three-valued gate returns :fold-first; ilan sows the whole agent
;;;; (crossing included) to a seed on disk. Then this process dies.
;;;; Run standalone:  sbcl --script demo/01_fold_and_die.lisp
(load (merge-pathnames "../src/world.lisp" *load-pathname*))  ; nolang: atom+gate+return+world (pulls in ilan)

(defparameter *seed* "/tmp/nol-continuity.seed")

;; A fresh agent with no memory yet.
(graft 'traveler :state (list :crossings nil))

;; A judgment the agent is NOT confident about: c = 0.4 < *theta* (0.5).
(defparameter *unsure* (make-natom '(safe migrate-prod) 0.5 0.4 "a-hunch"))

(format t "~&═══ PROCESS A  (pid ~a) ═══~%" (sb-unix:unix-getpid))
(format t "  agent 'traveler is born.  crossings: ~s~%" (crossings 'traveler))
(format t "  it faces  ~s  at (f=~a c=~a)~%"
        (natom-judgment *unsure*) (natom-f *unsure*) (natom-c *unsure*))

;; What does nolang's gate say about acting irreversibly on this?
(format t "  nolang gate:  outcome = ~s ,  permit :irreversible = ~s~%"
        (outcome *unsure*) (permit *unsure* :irreversible))

;; So the agent folds instead of guessing: it records the crossing and ilan
;; sows the agent to disk. The reversible probe runs, is not refuted → :kept.
(let ((result (act-under-uncertainty 'traveler *unsure*
                                     (lambda () :looked-around)   ; a reversible probe
                                     :seed *seed*)))
  (format t "  act-under-uncertainty → ~s~%" result)
  (format t "  crossing now in memory: ~s~%" (crossings 'traveler)))

(format t "  ilan sowed the agent to: ~a~%" *seed*)
(format t "  → PROCESS A ends here. Its RAM vanishes. Only the seed on disk survives.~%~%")
