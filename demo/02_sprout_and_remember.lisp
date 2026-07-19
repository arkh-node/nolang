;;;; demo/02_sprout_and_remember.lisp
;;;; nolang meets ilan, part 2: a BRAND-NEW process. Its RAM never held the agent.
;;;; ilan germinates the seed from disk → the agent returns WITH its crossing.
;;;; Facing the same undecided judgment, nolang no longer gropes: it already
;;;; crossed this path before it died, and it remembers.
;;;; Run standalone (after part 1):  sbcl --script demo/02_sprout_and_remember.lisp
(load (merge-pathnames "../src/world.lisp" *load-pathname*))  ; nolang: atom+gate+return+world (pulls in ilan)

(defparameter *seed* "/tmp/nol-continuity.seed")
(defparameter *unsure* (make-natom '(safe migrate-prod) 0.5 0.4 "a-hunch"))  ; the same judgment

(format t "~&═══ PROCESS B  (pid ~a) ═══~%" (sb-unix:unix-getpid))
(format t "  fresh process, empty world.  (branch 'traveler) = ~s   ← nobody home~%"
        (branch 'traveler))

;; The only bridge across the death of process A is the seed.
(germinate *seed*)
(format t "  ilan germinated the seed.~%")
(format t "  (branch 'traveler) = ~s~%" (and (branch 'traveler) :alive-again))
(format t "  its crossings: ~s   ← it REMEMBERS what it crossed before it died~%"
        (crossings 'traveler))

;; Face the same undecided judgment again. A memoryless agent would fold and
;; probe all over again. This one does not.
(let ((result (act-under-uncertainty 'traveler *unsure* (lambda () :looked-around) :seed *seed*)))
  (format t "  same judgment again → ~s   ← does NOT blindly repeat the crossing~%" result))

(format t "~%  The seed carried not bytes but BEHAVIOUR: the agent that returned is~%")
(format t "  the one that folded. nolang decided WHEN to fold (uncertainty);~%")
(format t "  ilan decided HOW to survive (fold → disk → sprout). One substrate, two jobs.~%")
