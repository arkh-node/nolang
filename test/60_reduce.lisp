;;;; test/60_reduce.lisp — РЕДУКЦИЯ: три теоремы о прогоне.
;;;; Run: sbcl --script test/60_reduce.lisp
;;;;
;;;; Здесь проверяется не «работает ли», а ТРИ СВОЙСТВА МАШИНЫ:
;;;;   ЗАВЕРШАЕМОСТЬ  — программа из n объявлений останавливается ровно за n шагов
;;;;   КОНФЛЮЭНТНОСТЬ — порядок объявлений (при соблюдении зависимостей) не влияет на склад
;;;;   ЗДРАВОСТЬ      — 🔴 динамическая степень СОВПАДАЕТ со статической
;;;;
;;;; Третья — главная: она и означает, что типовой слой не врёт. Провенанс, приписанный
;;;; компилятором, есть тот же провенанс, что получится в прогоне. Без неё вся конструкция
;;;; была бы украшением.
(load (merge-pathnames "../src/reduce.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))
(defun ~= (a b &optional (eps 1e-4)) (< (abs (- a b)) eps))

(defparameter *прог*
  '((lattice provenance молчание образ традиция строго)
    (witness з-162 "…" :grade строго :f 0.889 :c 0.9)
    (witness з-159 "…" :grade строго :f 0.857 :c 0.875)
    (ask т-273 :in (corpus library) :reason "свидетелей нет")
    (claim радость :grade строго (from з-162 з-159) (searched т-273))
    (action публикация :reversibility irreversible :requires (>= belief 0.7) :else fold)
    (do публикация радость)))

(format t "~&── ЗАВЕРШАЕМОСТЬ ──~%")

(multiple-value-bind (store ledger steps pend) (run-nolang *прог*)
  (declare (ignore store))
  (check "программа из 7 объявлений встаёт ровно за 7 шагов" (= steps 7))
  (check "непотреблённых молчаний не осталось (Δ = ∅)" (null pend))
  (check "журнал содержит ровно одно действие" (= 1 (length ledger))))

;;; Завершаемость здесь ТРИВИАЛЬНА, и это надо сказать вслух: в v0 нет выражений,
;;; нет рекурсии, нет циклов. Каждое объявление редуцируется ровно один раз.
(check "завершаемость масштабируется: 100 объявлений → 100 шагов"
       (= 100 (nth-value 2 (run-nolang
                            (loop for i from 1 to 100
                                  collect `(witness ,(intern (format nil "W~a" i))
                                                    "…" :grade строго :f 0.9 :c 0.8))))))

(format t "~&── КОНФЛЮЭНТНОСТЬ: склад не зависит от порядка ──~%")

;;; Случайная топологическая сортировка: берём любое объявление, чьи зависимости уже выданы.
(defun deps-of (form)
  (let ((head (string-downcase (string (first form)))))
    (cond ((string= head "claim")
           (append (let ((x (clause form "from")))     (if (eq x :нет) '() x))
                   (let ((x (clause form "searched"))) (if (eq x :нет) '() x))))
          ((string= head "do") (list (second form) (third form)))
          (t '()))))

(defun random-topo (forms)
  "Перестановка, уважающая зависимости. lattice закреплена первой."
  (let* ((lat (remove-if-not (lambda (f) (string-equal (string (first f)) "lattice")) forms))
         (body (remove-if (lambda (f) (string-equal (string (first f)) "lattice")) forms))
         (done '()) (out '()))
    (loop while body do
      (let* ((ready (remove-if-not
                     (lambda (f) (every (lambda (d) (member d done)) (deps-of f))) body))
             (pick (nth (random (length ready)) ready)))
        (push pick out) (push (second pick) done)
        (setf body (remove pick body :count 1))))
    (append lat (nreverse out))))

(let ((base (store-signature (run-nolang *прог*))) (ok t) (различных 0) (виды '()))
  (dotimes (i 200)
    (let* ((perm (random-topo *прог*))
           (sig (store-signature (run-nolang perm))))
      (pushnew (mapcar #'second perm) виды :test #'equal)
      (unless (equal base sig) (setf ok nil))))
  (setf различных (length виды))
  (check "склад одинаков при 200 случайных допустимых порядках" ok)
  (check "…и порядки действительно РАЗНЫЕ (иначе проверка пустая)" (> различных 3)))

;;; Журнал — единственное, что порядком отличается, и это по замыслу: он ИСТОРИЯ.
(check "журнал — история, склад — состояние: разное назначение"
       (let ((l1 (nth-value 1 (run-nolang *прог*))))
         (= 1 (length l1))))

(format t "~&── 🔴 ЗДРАВОСТЬ: динамическая степень = статической ──~%")

(check "на живой программе степени совпадают"
       (eq (grade-of *прог* 'радость) (grade-at-runtime *прог* 'радость)))

;;; Случайные программы: свидетели случайных степеней, утверждение по случайному
;;; подмножеству, иногда с молчанием в ОПОРНОЙ роли. Сверяем статику с прогоном.
(defparameter *степени* '(образ традиция строго))

(defun random-program (i)
  (let* ((k (+ 1 (random 4)))
         (ws (loop for j from 1 to k
                   collect (intern (format nil "W~a-~a" i j))))
         (forms (loop for w in ws
                      collect `(witness ,w "…"
                                        :grade ,(nth (random 3) *степени*)
                                        :f ,(+ 0.55 (random 0.4))
                                        :c ,(+ 0.1 (random 0.8)))))
         (with-silence (zerop (random 3)))
         (sid (intern (format nil "S~a" i)))
         (base (if with-silence (append ws (list sid)) ws)))
    (append forms
            (when with-silence `((ask ,sid :in (corpus) :reason "пусто")))
            `((claim ,(intern (format nil "C~a" i)) (from ,@base))))))

(let ((ok t) (с-молчанием 0) (без 0))
  (dotimes (i 200)
    (let* ((prog (random-program i))
           (cid (intern (format nil "C~a" i)))
           (st (grade-of prog cid))
           (dy (grade-at-runtime prog cid)))
      (if (eq st :silence) (incf с-молчанием) (incf без))
      (unless (eq st dy) (setf ok nil))))
  (check "200 случайных программ: статическая степень = динамической" ok)
  (check "…и обе ветви встретились (с молчанием в опоре и без)"
         (and (> с-молчанием 5) (> без 5))))

(format t "~&── ОТКАЗ ГЕЙТА — ЗНАЧЕНИЕ, А НЕ ИСКЛЮЧЕНИЕ ──~%")

(defparameter *слабая*
  '((witness рец "…" :grade строго :f 0.9 :c 0.6)          ; b = 0.54
    (claim статья :grade строго (from рец))
    (action публикация :reversibility irreversible :requires (>= belief 0.9) :else fold)
    (do публикация статья)))

(multiple-value-bind (store ledger steps pend) (run-nolang *слабая*)
  (declare (ignore steps pend))
  (check "прогон НЕ падает: отказ — обычный шаг" (= 1 (length ledger)))
  (check "в журнале записано «свёрнуто», а не «совершено»"
         (eq :folded (first (first ledger))))
  (let ((св (gethash (intern "ПУБЛИКАЦИЯ/СВЁРТОК") store)))
    (check "свёрток лёг НА СКЛАД как значение первого класса" (fv-p св))
    (check "…несёт основание, на котором стояли" (eq 'статья (fv-on св)))
    (check "…и НЕДОСТАЧУ: сколько веры не хватило" (~= (fv-lack св) (- 0.9 0.54) 0.01))))

(check "добрали свидетеля — гейт пропускает, свёртка нет"
       (let* ((p (append (butlast *слабая* 2)
                         '((witness рец-2 "…" :grade строго :f 0.97 :c 0.93)
                           (claim статья-2 :grade строго (from рец рец-2))
                           (action публ :reversibility irreversible
                                   :requires (>= belief 0.5) :else fold)
                           (do публ статья-2))))
              (l (nth-value 1 (run-nolang p))))
         (eq :performed (first (first l)))))

(format t "~&── ⊕ В МАШИНЕ ЕСТЬ БУКВАЛЬНО СЛОЖЕНИЕ ──~%")

(check "веса складываются покомпонентно: w⁺(a⊕b) = w⁺(a) + w⁺(b)"
       (let* ((p '((witness a "…" :grade строго :f 0.8 :c 0.5)
                   (witness b "…" :grade строго :f 0.6 :c 0.5)
                   (claim c (from a b))))
              (st (run-nolang p))
              (va (gethash 'a st)) (vb (gethash 'b st)) (vc (gethash 'c st)))
         (and (~= (jv-w+ vc) (+ (jv-w+ va) (jv-w+ vb)))
              (~= (jv-w- vc) (+ (jv-w- va) (jv-w- vb))))))

(check "молчание в опорной роли вносит НОЛЬ веса, но роняет степень"
       (let* ((p '((witness a "…" :grade строго :f 0.9 :c 0.8)
                   (ask s :in (corpus) :reason "пусто")
                   (claim c (from a s))))
              (st (run-nolang p))
              (va (gethash 'a st)) (vc (gethash 'c st)))
         (and (~= (jv-w+ vc) (jv-w+ va))
              (eq (jv-grade vc) :silence))))

(format t "~&── дисциплина тождества держится и в прогоне ──~%")

(check "повтор свидетеля не удваивает вес"
       (let* ((p1 '((witness a "…" :grade строго :f 0.9 :c 0.8) (claim c (from a))))
              (p2 '((witness a "…" :grade строго :f 0.9 :c 0.8) (claim c (from a a a))))
              (v1 (gethash 'c (run-nolang p1))) (v2 (gethash 'c (run-nolang p2))))
         (~= (jv-w+ v1) (jv-w+ v2))))

(format t "~&~%── журнал прогона, как его увидит человек ──~%")
(show-ledger (nth-value 1 (run-nolang *прог*)))
(show-ledger (nth-value 1 (run-nolang *слабая*)))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
