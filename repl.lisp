;;;; nolang REPL — приглашение САМОГО ЯЗЫКА, а не оболочки, в которой он написан.
;;;;
;;;; 🔴 ЧТО БЫЛО ДО 31.07.2026 И ПОЧЕМУ ЭТО БЫЛО НЕВЕРНО.
;;;; Прежний `repl.lisp` грузил «семь камней» (atom · gate · return · eval · nol · world · types)
;;;; и отдавал управление SBCL: человек видел баннер реализации, строку «nolang core loaded»
;;;; и звёздочку лисповского приглашения. Две беды сразу.
;;;; Первая: грузился РАННИЙ СЛОЙ — s-выражения с трёхзначным гейтом на атомах (`examples/sexp/`),
;;;; а не язык, определённый в `ГРАММАТИКА_v0.md`. Окно показывало прототип, а не nolang.
;;;; Вторая: приглашение принадлежало не языку. Слова Алексея: «если ноланг стал языком, то это
;;;; уже не SBCL». Он прав по существу: то, чем встречает приглашение, и есть заявление о том,
;;;; ЧТО здесь работает. Печатать имя реализации — значит говорить «здесь всё ещё лисп».
;;;;
;;;; Здесь: приглашение `~>`, ввод — конструкции языка, пустая строка завершает ввод.
;;;; Разбор и вердикт идут ТЕМИ ЖЕ функциями, что и в батарее (`compile-with-prelude`,
;;;; `program-verdict`): у приглашения нет своей семантики, иначе оно врало бы про язык.
;;;;                                                                — Невис, 31.07.2026

;; 🔴 ЗАГРУЗКА МОЛЧА, НО НЕ ВСЛЕПУЮ. SBCL печатает сводку компиляции («caught STYLE-WARNING»,
;; «undefined function») о функциях, определённых НИЖЕ по файлу — порядок в наших модулях
;; несущий (см. шапку common.lisp), так что это не дефект, а шум РЕАЛИЗАЦИИ. Человеку,
;; пришедшему к языку, он не адресован: приглашение должно встречать языком, а не внутренностями.
;; `handler-bind` тут бессилен — это не сигнал warning, а печать компилятора. Поэтому вывод
;; уводится в строку. 🔴 Но если загрузка УПАДЁТ, строка печатается целиком: молчание об ошибке
;; было бы ровно тем инструментом, который лжёт «всё хорошо», — а такие мы сегодня разоружали.
(let ((buf (make-string-output-stream)))
  (handler-case
      (let ((*standard-output* buf) (*error-output* buf)
            (*compile-verbose* nil) (*load-verbose* nil) (*compile-print* nil))
        (handler-bind ((warning #'muffle-warning))
          (load "/srv/langs/nolang/src/verdict.lisp")))   ; → prelude → nolang: parse · check · reduce
    (error (e)
      (format t "~&⛔ ЯЗЫК НЕ ЗАГРУЗИЛСЯ — это сбой инструмента, а не отказ языка:~%~a~%~%~a~%"
              e (get-output-stream-string buf))
      (finish-output)
      (sb-ext:exit :code 2))))

(defparameter *repl-prompt* "~> ")
(defparameter *repl-cont*   " … ")

(defvar *repl-prelude-path* nil)
(defvar *repl-prelude-src* nil)
(defvar *repl-lines* '() "Строки программы, в обратном порядке ввода.")

(defun repl-program-src ()
  (format nil "~{~a~%~}" (reverse *repl-lines*)))

(defun repl-say-help ()
  (format t "~&  Пишите объявления языка; ПУСТАЯ СТРОКА заканчивает ввод и запускает разбор.~%~
               Введённое накапливается как ОДНА программа — ровно так язык и читается.~%~%~
             ~4T:prelude ФАЙЛ   взять линейку (решётка, действия, пороги) из .nolp~%~
             ~4T:example        живой пример: линейка + замер (chronicle)~%~
             ~4T:show           показать накопленное~%~
             ~4T:drop           стереть накопленное (линейка остаётся)~%~
             ~4T:run ДЕЙСТВИЕ   прогнать и спросить именно про это действие~%~
             ~4T:help   :quit~%~%~
             🔴 Без имени действия вердикт отвечает «ничему не воспрепятствовало» — то есть~%~
             ~4Tне отвечает ничего. Спрашивающий про необратимое обязан НАЗВАТЬ его.~%"))

(defun repl-load-prelude (path)
  (handler-case
      (progn (setf *repl-prelude-src* (slurp path) *repl-prelude-path* path)
             (format t "~&  линейка принята: ~a~%" path))
    (error (e) (format t "~&  ⛔ линейка не прочиталась: ~a~%" e))))

(defun repl-judge (&optional require)
  "Разобрать накопленное и показать. REQUIRE — имя действия, о котором спрашиваем."
  (let ((src (repl-program-src)))
    (if (string= (string-trim '(#\Space #\Newline #\Tab) src) "")
        (format t "~&  (пусто)~%")
        (handler-case
            (multiple-value-bind (forms errs)
                (if *repl-prelude-src*
                    (compile-with-prelude *repl-prelude-src* src)
                    (compile-nolang src))
              (let ((rej (rejecting-errors errs)))
                (format t "~&  разобрано объявлений: ~a~@[  · линейка: ~a~]~%"
                        (length forms) *repl-prelude-path*)
                (unless *repl-prelude-src*
                  (format t "  ⚠️ линейки нет: мера и замер в одном месте — её могли выточить~%~
                             ~5Tпод уже известный результат  (:prelude ФАЙЛ)~%"))
                (when errs (diagnose forms))
                (multiple-value-bind (store ledger) (run-nolang forms :carrier :репл)
                  (show-run store ledger :rejected (and rej t))
                  (multiple-value-bind (kind why) (program-verdict errs ledger :require require)
                    (format t "~&")
                    (say-verdict-line kind why)))))
          (nol-syntax-error (e)
            (format t "~&  ⛔ не разбирается:~%~a~%" e))
          (error (e)
            (format t "~&  ⛔ сбой инструмента (это НЕ вердикт языка): ~a~%" e))))))

(defun repl-command (line)
  "→ T, если строка была командой."
  (let* ((s (string-trim '(#\Space #\Tab) line))
         (sp (position #\Space s))
         (cmd (subseq s 0 (or sp (length s))))
         (arg (and sp (string-trim '(#\Space) (subseq s sp)))))
    (cond
      ((string-equal cmd ":quit")
       (format t "~&  до встречи.~%") (finish-output) (sb-ext:exit :code 0))
      ((string-equal cmd ":help") (repl-say-help) t)
      ((string-equal cmd ":show")
       (format t "~&~a~%" (if *repl-lines* (repl-program-src) "  (пусто)")) t)
      ((string-equal cmd ":drop") (setf *repl-lines* '()) (format t "~&  стёрто.~%") t)
      ((string-equal cmd ":prelude")
       (if arg (repl-load-prelude arg) (format t "~&  :prelude требует файл~%")) t)
      ((string-equal cmd ":example")
       (repl-load-prelude "/srv/langs/nolang/examples/chronicle.nolp")
       (setf *repl-lines*
             (reverse (with-open-file (f "/srv/langs/nolang/examples/chronicle.nol"
                                         :external-format :utf-8)
                        (loop for l = (read-line f nil nil) while l collect l))))
       (format t "  замер принят: examples/chronicle.nol~%  спросить:  :run write_to_chronicle~%") t)
      ((string-equal cmd ":run")
       (repl-judge (and arg (intern (string-upcase arg)))) t)
      ((and (> (length s) 0) (char= (char s 0) #\:))
       (format t "~&  неизвестная команда ~a   (:help)~%" cmd) t)
      (t nil))))

(defun nolang-repl ()
  (format t "~&~%  вера может прибывать · происхождение может только падать~%")
  (format t "  между ними нет моста — в этом и есть язык~%~%")
  (format t "  :help — что можно · :example — живой пример · :quit~%~%")
  (loop
    (format t "~&~a" (if *repl-lines* *repl-cont* *repl-prompt*))
    (finish-output)
    (let ((line (read-line *standard-input* nil :eof)))
      (cond
        ((eq line :eof) (format t "~%") (return))
        ((repl-command line))                       ; команда — уже выполнена
        ((string= (string-trim '(#\Space #\Tab) line) "")
         (when *repl-lines* (repl-judge)))          ; пустая строка — разобрать и показать
        (t (push line *repl-lines*))))))

(nolang-repl)
(sb-ext:exit :code 0)
