;;;; test/90_product.lisp — РЕШЁТКА-ПРОИЗВЕДЕНИЕ. Порядок становится ЧАСТИЧНЫМ.
;;;; Run: sbcl --script test/90_product.lisp
;;;;
;;;; ПОВОД (совет Невис 28.07, §5): «в объявлении — да, в употреблении — нет». Правила вывода
;;;; зависят только от ⊓, значит цена разрешить произведение сегодня равна нулю, а цена зашить
;;;; цепочку и мигрировать потом — реальная.
;;;;
;;;; 🔴 ЧТО ЛОМАЛОСЬ БЫ БЕЗ ПРАВКИ: прежняя g-meet была `(if (g<= a b) a b)` — на несравнимых
;;;; это вернуло бы ОДНУ ИЗ НИХ, то есть степень ВЫШЕ настоящей нижней грани. Отмывание через
;;;; дырявую решётку. Здесь это проверяется прямо: грань обязана быть СТРОГО НИЖЕ обеих.
(load (merge-pathnames "../src/parse.lisp" *load-pathname*))

(defvar *n* 0)
(defmacro check (label form) `(progn (assert ,form () "FAIL: ~a" ,label)
                                     (incf *n*) (format t "  ✓ ~a~%" ,label)))

;;; ── кодекс Адмиралтейства (система НАТО), готовое произведение из реальной практики ──
;;; надёжность источника A(лучшая)…F · достоверность сведения 1(лучшая)…6 · оценка вида «B2».
;;; В описателе порядок снизу вверх, поэтому f…a и six…one.
(defparameter *адмиралтейство* "
lattice reliability = f < e < d < c < b < a
lattice credibility = six < five < four < three < two < one
lattice admiralty = reliability * credibility
")

(defun с-решёткой (&rest строки)
  (parse (apply #'concatenate 'string *адмиралтейство* строки)))

(format t "~&── ОБЪЯВЛЕНИЕ И РАЗБОР ──~%")

(check "произведение объявляется и разбирается" (parse-ok? *адмиралтейство*))
(check "части объявляются раньше произведения — иначе ошибка"
       (member :lattice (errors-of '((lattice x :product нет-такой и-такой)))))
(check "произведение из одной решётки не разбирается"
       (not (parse-ok? "lattice a = b
lattice x = a *")))
(check "смешивать < и * нельзя"
       (not (parse-ok? "lattice x = a < b * c")))
(check "кортеж из одного имени не разбирается — скобки лишние"
       (not (parse-ok? (concatenate 'string *адмиралтейство*
                                    "witness w : (b) says \"…\" source s evidence 1 for 0 against"))))

(format t "~&── ⊓ ПОКОМПОНЕНТНА ──~%")

(defparameter *два-донесения*
  (с-решёткой "
witness d1 : (b, two)  says \"колонна у моста\"        source scout evidence 8 for 1 against
witness d2 : (d, one)  says \"подтверждено аэрофото\"  source recon evidence 6 for 1 against
claim column from d1, d2"))

(check "B2 ⊓ D1 = D2 — минимум по каждой оси отдельно"
       (string= "d·two" (g-ru (grade-of *два-донесения* 'column))))

(format t "~&── 🔴 ЧАСТИЧНЫЙ ПОРЯДОК: несравнимые существуют ──~%")

;;; B4 надёжнее, но менее достоверно; D2 наоборот. Ни одна не выше другой.
(defparameter *спор*
  (с-решёткой "
witness p : (b, four) says \"…\" source s1 evidence 5 for 1 against
witness q : (d, two)  says \"…\" source s2 evidence 5 for 1 against
claim mix from p, q"))

(check "B4 ⊓ D2 = D4"
       (string= "d·four" (g-ru (grade-of *спор* 'mix))))

;;; Ключевая проверка, ради которой всё: грань СТРОГО НИЖЕ обеих посылок.
(with-prelude
 (dolist (f (parse *адмиралтейство*)) (chk-lattice f))
 (let* ((b4 (parse-grade '(b four))) (d2 (parse-grade '(d two)))
        (гр (g-meet b4 d2)))
   (check "B4 и D2 НЕСРАВНИМЫ — оба направления ложны"
          (and (not (g<= b4 d2)) (not (g<= d2 b4)) (not (g-comparable-p b4 d2))))
   (check "🔴 грань СТРОГО НИЖЕ B4 (старая g-meet вернула бы саму B4 или D2)"
          (and (g<= гр b4) (not (g<= b4 гр))))
   (check "🔴 …и СТРОГО НИЖЕ D2"
          (and (g<= гр d2) (not (g<= d2 гр))))))

(format t "~&── ЖИВОЙ СЛУЧАЙ ИСТОЧНИКОВЕДЕНИЯ (ради него совет и был дан) ──~%")

;;; «[строго] из спорной рукописи» против «[традиция] из надёжной»: в линейный порядок
;;; не лезет, и это не редкость, а норма. Теперь выражается честно — как несравнимость.
(defparameter *рукописи* "
lattice род = образ < традиция < строго
lattice передача = спорная < надёжная
lattice источник = род * передача
")

(with-prelude
 (dolist (f (parse *рукописи*)) (chk-lattice f))
 (let* ((строгий-спорный (parse-grade '(строго спорная)))
        (традиция-надёжная (parse-grade '(традиция надёжная))))
   (check "«строго из спорной» и «традиция из надёжной» НЕСРАВНИМЫ, а не упорядочены насильно"
          (not (g-comparable-p строгий-спорный традиция-надёжная)))
   (check "их грань — «традиция из спорной»: худшее по каждой оси"
          (string= "традиция·спорная" (g-ru (g-meet строгий-спорный традиция-надёжная))))))

(format t "~&── ЗАКОНЫ ПОЛУРЕШЁТКИ ДЕРЖАТСЯ И НА ПРОИЗВЕДЕНИИ ──~%")

(with-prelude
 (dolist (f (parse *адмиралтейство*)) (chk-lattice f))
 (let ((все (loop for r in '(f e d c b a) append
                  (loop for k in '(six five four three two one)
                        collect (parse-grade (list r k))))))
   (check "идемпотентность a⊓a = a (36 степеней)"
          (every (lambda (a) (equal (g-meet a a) a)) все))
   (check "коммутативность a⊓b = b⊓a (1296 пар)"
          (every (lambda (a) (every (lambda (b) (equal (g-meet a b) (g-meet b a))) все)) все))
   (check "ассоциативность (a⊓b)⊓c = a⊓(b⊓c) (выборка 6³)"
          (let ((s (list (parse-grade '(a one)) (parse-grade '(b four)) (parse-grade '(d two))
                         (parse-grade '(f six)) (parse-grade '(c three)) (parse-grade '(e five)))))
            (every (lambda (a) (every (lambda (b) (every (lambda (c)
                     (equal (g-meet (g-meet a b) c) (g-meet a (g-meet b c)))) s)) s)) s)))
   (check "дно поглощает: ⊥⊓a = ⊥, и дно = (f, six)"
          (and (equal (g-bot) (parse-grade '(f six)))
               (every (lambda (a) (equal (g-meet (g-bot) a) (g-bot))) все)))
   (check "верх нейтрален: ⊤⊓a = a, и верх = (a, one)"
          (and (equal (g-top) (parse-grade '(a one)))
               (every (lambda (a) (equal (g-meet (g-top) a) a)) все)))))

(format t "~&── ЗАПРЕТ ОТМЫВАНИЯ ДЕЙСТВУЕТ И НА ПРОИЗВЕДЕНИИ ──~%")

(check "объявить (a,one) на основании (d,four) — :launder"
       (member :launder
               (errors-of (с-решёткой "
witness w : (d, four) says \"…\" source s evidence 3 for 1 against
claim c : (a, one) from w"))))

(check "объявить НЕСРАВНИМУЮ степень — тоже отмывание (не ниже выведенной)"
       (member :launder
               (errors-of (с-решёткой "
witness w : (d, two) says \"…\" source s evidence 3 for 1 against
claim c : (b, four) from w"))))

(check "понизить до сравнимо-меньшей — законно"
       (null (remove :runtime
                     (errors-of (с-решёткой "
witness w : (b, two) says \"…\" source s evidence 3 for 1 against
claim c : (d, four) from w")))))

(format t "~&── прелюдия цела: линейная решётка работает как прежде ──~%")

(check "без объявления действует прелюдия из четырёх степеней"
       (eq :obraz (grade-of '((witness a "…" :grade строго :f 0.9 :c 0.6)
                              (witness b "…" :grade образ  :f 0.9 :c 0.6)
                              (claim c (from a b)))
                            'c)))

(format t "~&── ЧУЖАЯ ФОРМА СТЕПЕНИ: ДИАГНОСТИКА, А НЕ КРАХ (находка харнесса оракула, 29.07) ──~%")
;;; 🔴 ПОВОД. Кортеж степени при ЛИНЕЙНОЙ действующей решётке доходил до `g-meet-in`,
;;; там `position` возвращал nil, и `<=` падал необработанным условием SBCL. Пользователь
;;; получал бэктрейс вместо объяснения. Нашёл это первый же прогон генератора случайных
;;; программ — выдуманные примеры такого не давали, потому что я писал их согласованными.
(defparameter *чужая-форма*
  '((lattice L g0 g1 g2)
    (witness w "…" :grade (g1 g2) :f 0.9 :c 0.6 :source (s))
    (claim c (from w))))

(check "кортеж при линейной решётке — ошибка формы, а не падение"
       (member :grade-shape (errors-of *чужая-форма*)))
(check "…и проверка доходит до конца: утверждение получает степень"
       (grade-of *чужая-форма* 'c))
(check "🔴 степень при этом ДНО — заниженное направление, никогда не завышенное"
       (eq (grade-of *чужая-форма* 'c) :G0))
(check "g-meet-in тотальна: несовпадение формы даёт дно решётки"
       (let ((l '(:linear (:a :b :c))))
         (and (eq :a (g-meet-in l :b '(:b :c)))
              (eq :a (g-meet-in l '(:b :c) :b))
              (eq :b (g-meet-in l :b :c)))))
(check "…и на произведении тоже: одиночка вместо пары роняет на дно"
       (let ((l (list :product '(:linear (:a0 :a1)) '(:linear (:b0 :b1)))))
         (equal '(:a0 :b0) (g-meet-in l '(:a1 :b1) :a1))))

(format t "~%── ALL GREEN · проверок: ~a ──~%" *n*)
