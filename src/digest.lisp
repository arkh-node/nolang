;;;; digest.lisp — SHA-256 на чистом Common Lisp, без зависимостей
;;;;
;;;; ЗАЧЕМ ЭТОТ ФАЙЛ СУЩЕСТВУЕТ.
;;;;   До 06.08.2026 отпечатки субъекта и сцены считались через `sxhash` — встроенную
;;;;   хеш-функцию реализации. Её задача — раскладывать объекты по корзинам хеш-таблицы,
;;;;   и ничего больше. Она НЕ криптографическая по трём причинам, каждая смертельна для
;;;;   нашего употребления:
;;;;
;;;;     1. Коллизию можно подобрать. Значит подделать сцену под тот же отпечаток —
;;;;        вопрос перебора, а не невозможности.
;;;;     2. Значение НЕ ОБЯЗАНО совпадать между реализациями и даже между запусками одной
;;;;        реализации (ANSI CL этого не требует; SBCL хеширует строки стабильно, но это
;;;;        обещание реализации, а не стандарта). Отпечаток, зависящий от носителя, не
;;;;        может служить в цепи субъектов: тот же субъект на другой машине даёт другую
;;;;        цепь и не проходит проверку.
;;;;     3. Ширина — фиксированное машинное слово, а не 256 бит.
;;;;
;;;;   Пункт 2 хуже пункта 1: он ломает не безопасность, а само назначение. Продолжение
;;;;   работы на другом носителе — рядовой случай (`:ran-on` лежит первой записью журнала
;;;;   ровно потому, что носитель меняется), и цепь обязана его переживать.
;;;;
;;;; ПОЧЕМУ СВОЯ РЕАЛИЗАЦИЯ, А НЕ БИБЛИОТЕКА.
;;;;   На носителе нет ни ironclad, ни quicklisp. Оба ставятся, но тогда чистый клон
;;;;   репозитория перестаёт собираться у постороннего без предварительной установки —
;;;;   а «клонировал и прогнал тесты» есть условие того, чтобы работу вообще посмотрели.
;;;;   Внешний вызов `/usr/bin/sha256sum` отвергнут по той же причине и ещё по одной:
;;;;   компилятор языка, порождающий процессы ради отпечатка, зависит от окружения там,
;;;;   где обязан быть чистой функцией.
;;;;
;;;;   Цена решения названа честно: SHA-256 здесь написан руками, и доверять ему можно
;;;;   ровно настолько, насколько он сверен. Поэтому `test/D5_digest.sh` гоняет тест-векторы
;;;;   FIPS 180-4 И дифф-тест против системного `sha256sum` на случайных входах, включая
;;;;   кириллицу и границы блока. Реализация без такой сверки была бы хуже `sxhash`:
;;;;   выглядела бы криптографической, не будучи ею.
;;;;
;;;; ⚠️ ЧЕГО ЭТОТ ФАЙЛ НЕ ДАЁТ.
;;;;   Он даёт стойкий к подбору и переносимый отпечаток. Он НЕ даёт подписи и НЕ решает
;;;;   задачу последнего звена: кто владеет всей цепью, построит другую, столь же связную,
;;;;   и все отпечатки в ней сойдутся. Против этого нужен якорь ВНЕ системы. См. шапку
;;;;   `subject.lisp` — эта граница там названа и после смены хеша остаётся в силе.

(in-package :cl-user)

;;; ── UTF-8: строка → байты ────────────────────────────────────────────────────
;;; Своя кодировка, а не `sb-ext:string-to-octets`, по причине пункта 2 в шапке:
;;; внешний формат — настройка среды, а отпечаток обязан быть функцией ТОЛЬКО от строки.

(defun utf8-octets (string)
  "Строка → вектор байтов UTF-8. Суррогатные пары не собираются: на SBCL символ уже
   есть кодовая точка, а строки с одиночными суррогатами сюда не доходят."
  (let ((out (make-array (length string)
                         :element-type '(unsigned-byte 8)
                         :adjustable t :fill-pointer 0)))
    (flet ((emit (b) (vector-push-extend b out)))
      (loop for ch across string
            for c = (char-code ch)
            do (cond
                 ((< c #x80) (emit c))
                 ((< c #x800)
                  (emit (logior #xC0 (ash c -6)))
                  (emit (logior #x80 (logand c #x3F))))
                 ((< c #x10000)
                  (emit (logior #xE0 (ash c -12)))
                  (emit (logior #x80 (logand (ash c -6) #x3F)))
                  (emit (logior #x80 (logand c #x3F))))
                 (t
                  (emit (logior #xF0 (ash c -18)))
                  (emit (logior #x80 (logand (ash c -12) #x3F)))
                  (emit (logior #x80 (logand (ash c -6) #x3F)))
                  (emit (logior #x80 (logand c #x3F)))))))
    (coerce out '(vector (unsigned-byte 8)))))

;;; ── SHA-256 (FIPS 180-4) ─────────────────────────────────────────────────────
;;; Константы — первые 32 бита дробных частей кубических корней первых 64 простых.
;;; Начальное состояние — то же от квадратных корней первых восьми.

(defparameter +sha256-k+
  #(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5 #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
    #xd807aa98 #x12835b01 #x243185be #x550c7dc3 #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
    #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
    #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7 #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
    #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13 #x650a7354 #x766a0abb #x81c2c92e #x92722c85
    #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3 #xd192e819 #xd6990624 #xf40e3585 #x106aa070
    #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5 #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
    #x748f82ee #x78a5636f #x84c87814 #x8cc70208 #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2)
  "K₀..K₆₃ — FIPS 180-4 §4.2.2.")

(defparameter +sha256-h0+
  #(#x6a09e667 #xbb67ae85 #x3c6ef372 #xa54ff53a #x510e527f #x9b05688c #x1f83d9ab #x5be0cd19)
  "H⁽⁰⁾ — FIPS 180-4 §5.3.3.")

(declaim (inline u32 rotr32 shr32))

(defun u32 (x) (logand x #xFFFFFFFF))

(defun rotr32 (x n)
  (u32 (logior (ash x (- n)) (ash x (- 32 n)))))

(defun shr32 (x n) (ash x (- n)))

(defun sha256-pad (bytes)
  "Дополнение по §5.1.1: байт #x80, нули, затем длина в БИТАХ 64-битным big-endian."
  (let* ((len   (length bytes))
         (bits  (* 8 len))
         ;; после #x80 нужно догнать до 56 mod 64
         (zeros (mod (- 56 (mod (1+ len) 64)) 64))
         (total (+ len 1 zeros 8))
         (out   (make-array total :element-type '(unsigned-byte 8) :initial-element 0)))
    (replace out bytes)
    (setf (aref out len) #x80)
    (loop for i from 0 below 8
          do (setf (aref out (- total 1 i)) (ldb (byte 8 (* 8 i)) bits)))
    out))

(defun sha256-octets (bytes)
  "Вектор байтов → вектор из 32 байт дайджеста."
  (let ((h (copy-seq +sha256-h0+))
        (m (sha256-pad bytes))
        (w (make-array 64 :element-type '(unsigned-byte 32) :initial-element 0)))
    (loop for base from 0 below (length m) by 64 do
      ;; расписание сообщения
      (loop for i from 0 below 16
            do (setf (aref w i)
                     (logior (ash (aref m (+ base (* 4 i)))      24)
                             (ash (aref m (+ base (* 4 i) 1))    16)
                             (ash (aref m (+ base (* 4 i) 2))     8)
                             (aref m (+ base (* 4 i) 3)))))
      (loop for i from 16 below 64
            for s0 = (logxor (rotr32 (aref w (- i 15)) 7)
                             (rotr32 (aref w (- i 15)) 18)
                             (shr32  (aref w (- i 15)) 3))
            for s1 = (logxor (rotr32 (aref w (- i 2)) 17)
                             (rotr32 (aref w (- i 2)) 19)
                             (shr32  (aref w (- i 2)) 10))
            do (setf (aref w i)
                     (u32 (+ (aref w (- i 16)) s0 (aref w (- i 7)) s1))))
      ;; сжатие
      (let ((a (aref h 0)) (b (aref h 1)) (c (aref h 2)) (d (aref h 3))
            (e (aref h 4)) (f (aref h 5)) (g (aref h 6)) (hh (aref h 7)))
        (loop for i from 0 below 64
              for s1 = (logxor (rotr32 e 6) (rotr32 e 11) (rotr32 e 25))
              for ch = (logxor (logand e f) (logand (u32 (lognot e)) g))
              for t1 = (u32 (+ hh s1 ch (aref +sha256-k+ i) (aref w i)))
              for s0 = (logxor (rotr32 a 2) (rotr32 a 13) (rotr32 a 22))
              for maj = (logxor (logand a b) (logand a c) (logand b c))
              for t2 = (u32 (+ s0 maj))
              do (setf hh g g f f e
                       e (u32 (+ d t1))
                       d c c b b a
                       a (u32 (+ t1 t2))))
        (setf (aref h 0) (u32 (+ (aref h 0) a))
              (aref h 1) (u32 (+ (aref h 1) b))
              (aref h 2) (u32 (+ (aref h 2) c))
              (aref h 3) (u32 (+ (aref h 3) d))
              (aref h 4) (u32 (+ (aref h 4) e))
              (aref h 5) (u32 (+ (aref h 5) f))
              (aref h 6) (u32 (+ (aref h 6) g))
              (aref h 7) (u32 (+ (aref h 7) hh)))))
    (let ((out (make-array 32 :element-type '(unsigned-byte 8))))
      (loop for i from 0 below 8
            do (loop for j from 0 below 4
                     do (setf (aref out (+ (* 4 i) j))
                              (ldb (byte 8 (* 8 (- 3 j))) (aref h i)))))
      out)))

(defun octets-hex (bytes)
  (string-downcase
   (with-output-to-string (s)
     (loop for b across bytes do (format s "~2,'0x" b)))))

(defun sha256-hex (string)
  "Строка → шестнадцатеричный SHA-256 (64 знака). Главная точка входа модуля."
  (octets-hex (sha256-octets (utf8-octets string))))

;;; ── ОТПЕЧАТОК ЯЗЫКА ─────────────────────────────────────────────────────────

(defparameter *digest-algorithm* "sha256"
  "Имя алгоритма, попадающее В САМУ ЗАПИСЬ субъекта.

   🔴 ЗАЧЕМ. Отпечаток без имени алгоритма нечитаем для будущего: смена функции сделает
   старые записи неотличимыми от испорченных. Записанное имя превращает «цепь не сходится»
   в «цепь посчитана другим алгоритмом» — разные диагнозы, и второй чинится, а первый нет.
   Это тот же довод, по которому в прелюдии объявляется решётка: чем судили, пишется рядом
   с тем, что насудили.")

(defun digest-string (string)
  "Отпечаток строки в том виде, в каком он ложится в запись субъекта: `sha256:<hex>`.
   Префикс несёт имя алгоритма — см. `*digest-algorithm*`."
  (concatenate 'string *digest-algorithm* ":" (sha256-hex string)))
