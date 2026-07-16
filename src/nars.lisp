;;;; nolang src 06 — nars. Реализация spec/06_substrate.md.
;;;; Мост к рассуждающему субстрату: суждение nolang → Narsese → NARS выводит → обратно в atom.
;;;; (f,c) ↔ NARS (frequency,confidence) — прямое соответствие (AIKR). Язык не имитирует вывод, а отдаёт его.

(load (merge-pathnames "atom.lisp" *load-pathname*))

(defparameter *nar* "/srv/office/tooling/nars_lab/ONA/NAR")

(defun ->narsese (a)
  "atom (isa X Y)@(f.c) → строку Narsese '<X --> Y>. %f;c%'."
  (destructuring-bind (rel x y) (natom-judgment a)
    (declare (ignore rel))
    (format nil "<~(~a~) --> ~(~a~)>. %~,2f;~,2f%" x y (natom-f a) (natom-c a))))

(defun %извлечь (строка ключ)
  "из '…frequency=0.81, confidence=0.66…' достать число после ключ=."
  (let ((p (search ключ строка)))
    (when p
      (let ((start (+ p (length ключ))))
        (read-from-string строка nil nil :start start)))))

(defun nars-спросить (факты запрос-judgment)
  "Послать факты (atoms) в NARS, спросить вывод по запросу. Возврат: atom (f,c из NARS) или unknown."
  (destructuring-bind (rel x y) запрос-judgment
    (declare (ignore rel))
    (let* ((вход (with-output-to-string (s)
                   (dolist (a факты) (write-line (->narsese a) s))
                   (write-line "100" s)                         ; циклы вывода
                   (format s "<~(~a~) --> ~(~a~)>?~%" x y)))    ; запрос
           (вывод (with-output-to-string (out)
                    (sb-ext:run-program *nar* '("shell")
                                        :input (make-string-input-stream вход)
                                        :output out :error nil)))
           (ans-poz (search "Answer:" вывод)))
      (if ans-poz
          (let* ((хвост (subseq вывод ans-poz))
                 (f (%извлечь хвост "frequency="))
                 (c (%извлечь хвост "confidence=")))
            (if (and f c)
                (%make-natom :judgment запрос-judgment :f f :c c :trace "nars:вывод")
                (%make-natom :judgment запрос-judgment :f 0.5 :c 0.1 :trace "nars:no-answer")))
          (%make-natom :judgment запрос-judgment :f 0.5 :c 0.1 :trace "nars:no-answer")))))
