;;;; test/05_world.lisp — настоящий откат следа в мире. sbcl --script test/05_world.lisp
(load (merge-pathnames "../src/world.lisp" *load-pathname*))

(defparameter *файл* "/tmp/nol-world.txt")

(defun записать (путь текст)
  (with-open-file (s путь :direction :output :if-exists :supersede :if-does-not-exist :create) (princ текст s)))
(defun прочитать (путь)
  (if (probe-file путь)
      (with-open-file (s путь :external-format :utf-8)
        (let* ((b (make-string (file-length s))) (n (read-sequence b s)))
          (subseq b 0 n)))   ; по РЕАЛЬНО прочитанным символам (кириллица: байтов больше)
      ""))

(привить 'агент :состояние (list :crossings nil))

;; исходное состояние мира
(записать *файл* "ИСХОДНОЕ")
(defparameter *было* (прочитать *файл*))
(format t "~&мир до действия:      ~s~%" *было*)

;; обратимый эффект: дописать (undo = вернуть исходное)
(defparameter *дописать*
  (let ((исходное (прочитать *файл*)))
    (make-эффект :описание "дописать в файл"
                 :сделать  (lambda () (записать *файл* (concatenate 'string исходное " +ИЗМЕНЕНИЕ")))
                 :откатить (lambda () (записать *файл* исходное)))))

;; агент под НЕУВЕРЕННОСТЬЮ действует и опровергается → откат мира И себя
(defparameter *subj* (make-natom '(safe change) 0.6 0.3 "guess"))  ; c=0.3 < θ → undecided
(format t "~%действие под неуверенностью (c=0.3), затем опровержение:~%")
(let ((исход (act-in-world 'агент *subj* *дописать* :refuted (lambda () t))))
  (format t "  исход: ~s~%" исход))
(defparameter *стало* (прочитать *файл*))
(format t "  мир после отката:     ~s~%" *стало*)
(format t "  СЧЁТОМ: до == после ? ~a   ← след в мире откачен~%" (string= *было* *стало*))

;; необратимый эффект (undo = nil) под неуверенностью — заблокирован
(format t "~%необратимое действие (нет undo) под той же неуверенностью:~%")
(привить 'агент :состояние (list :crossings nil))
(defparameter *удалить* (make-эффект :описание "удалить файл (необратимо)" :сделать (lambda () :deleted) :откатить nil))
(format t "  исход: ~s   ← язык НЕ пустил необратимое под неуверенностью~%"
        (act-in-world 'агент (make-natom '(safe delete) 0.6 0.3 "guess") *удалить* :refuted (lambda () t)))

(format t "~%  Состояние И след в мире откатываются вместе. Неоткатимое без уверенности не проходит — это защита.~%")
