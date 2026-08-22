;;;; nolang service (R0) — долгоживущий вердикт-сервис. Грузит ИНТЕРПРЕТАТОР ОДИН РАЗ,
;;;; принимает запросы по TCP, зовёт judge-source. Обёртка над эталонным интерпретатором,
;;;; не вторая истина: семантика — в compile-with-prelude/run-nolang/program-verdict.
;;;; R0.4: ответ несёт ПРОВЕНАНС (почему) — аудируемость наружу.
(require :sb-bsd-sockets)
(load (merge-pathnames "../src/verdict.lisp" *load-pathname*))

(defun json-escape (s)
  (with-output-to-string (o)
    (loop for ch across (or s "") do
      (case ch
        (#\" (write-string "\\\"" o))
        (#\\ (write-string "\\\\" o))
        (#\Newline (write-string "\\n" o))
        (#\Return (write-string "\\r" o))
        (#\Tab (write-string "\\t" o))
        (t (write-char ch o))))))

(defun num->json (x)
  "Число (в т.ч. рациональное 6/7) → float-строка JSON; не число → null."
  (if (numberp x) (format nil "~,4f" (float x 1.0)) "null"))

(defun name->s (x) (json-escape (string-downcase (princ-to-string x))))

(defun entry->json (e)
  "Запись ledger → JSON-объект провенанса. Формы: (:performed action basis belief thr) ·
   (:folded action basis belief thr gap …) · пороки (:orphaned/:irreparable/:unauthorized action basis …)."
  (let ((kind (name->s (first e))))
    (case (first e)
      ((:performed :compensating)
       (format nil "{\"kind\":\"~a\",\"action\":\"~a\",\"basis\":\"~a\",\"belief\":~a,\"threshold\":~a}"
               kind (name->s (second e)) (name->s (third e)) (num->json (fourth e)) (num->json (fifth e))))
      (:folded
       (format nil "{\"kind\":\"folded\",\"action\":\"~a\",\"basis\":\"~a\",\"belief\":~a,\"threshold\":~a}"
               (name->s (second e)) (name->s (third e)) (num->json (fourth e)) (num->json (fifth e))))
      (t
       (format nil "{\"kind\":\"~a\",\"action\":\"~a\",\"basis\":\"~a\",\"belief\":~a,\"threshold\":~a}"
               kind (name->s (second e)) (name->s (third e)) (num->json (fourth e)) (num->json (fifth e)))))))

(defun ledger->json (ledger)
  "Провенанс: все значимые записи (совершено/свёрнуто/пороки) в порядке от старых к новым."
  (let ((sig (remove-if-not
              (lambda (e) (member (first e)
                                  '(:performed :compensating :folded :orphaned :irreparable
                                    :unauthorized :compensation-folded)))
              (reverse ledger))))
    (format nil "[~{~a~^,~}]" (mapcar #'entry->json sig))))

(defun verdict->json (kind why ledger)
  (format nil "{\"verdict\":\"~a\",\"code\":~a,\"reason\":\"~a\",\"provenance\":~a}"
          (json-escape (ignore-errors (verdict-word kind)))
          (ignore-errors (verdict-code kind))
          (json-escape why)
          (ledger->json ledger)))

(defun read-request (stream)
  "Протокол v1 (маркеры, без байт-счёта — кириллица/переносы целы):
     [REQUIRE: имя] · [===PRELUDE=== …] · ===PROGRAM=== … ===END==="
  (let ((require nil) (mode :head) (pre '()) (prog '()))
    (loop for line = (read-line stream nil :eof)
          until (eq line :eof) do
      (cond
        ((string= line "===END===") (return))
        ((string= line "===PRELUDE===") (setf mode :prelude))
        ((string= line "===PROGRAM===") (setf mode :program))
        ((and (eq mode :head) (>= (length line) 8) (string= (subseq line 0 8) "REQUIRE:"))
         (setf require (string-trim " " (subseq line 8))))
        ((eq mode :prelude) (push line pre))
        ((eq mode :program) (push line prog))))
    (values (format nil "~{~a~^~%~}" (nreverse prog))
            (and pre (format nil "~{~a~^~%~}" (nreverse pre)))
            (and require (plusp (length require)) require))))

(defun handle (stream)
  (multiple-value-bind (program prelude require) (read-request stream)
    (multiple-value-bind (kind why ledger) (judge-source program :require require :prelude-src prelude)
      (write-line (verdict->json kind why ledger) stream)
      (finish-output stream))))

(defun serve (port)
  (let ((sock (make-instance 'sb-bsd-sockets:inet-socket :type :stream :protocol :tcp)))
    (setf (sb-bsd-sockets:sockopt-reuse-address sock) t)
    (sb-bsd-sockets:socket-bind sock #(127 0 0 1) port)
    (sb-bsd-sockets:socket-listen sock 8)
    (format t "~&nolang-service слушает 127.0.0.1:~a — интерпретатор загружен ОДИН раз~%" port)
    (finish-output)
    (loop
      (let ((conn (sb-bsd-sockets:socket-accept sock)))
        (let ((s (sb-bsd-sockets:socket-make-stream conn :input t :output t
                                                    :element-type 'character :external-format :utf-8)))
          (handler-case (handle s)
            (error (e) (ignore-errors (write-line (verdict->json :сбой (format nil "~a" e) nil) s))))
          (ignore-errors (close s))
          (ignore-errors (sb-bsd-sockets:socket-close conn)))))))

(serve (let ((p (sb-ext:posix-getenv "NOL_PORT"))) (if p (parse-integer p) 8899)))
