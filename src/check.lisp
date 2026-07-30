;;;; nolang src — check. СТАТИЧЕСКИЙ ПРОВЕРЯЮЩИЙ градуированного слоя.
;;;; Реализует заказ АЛГЕБРА_v0.md §5 (шесть пунктов). Не путать с src/types.lisp —
;;;; тот про контракты действий в рантайме (слой Лора, 19.07), этот про степени в типах.
;;;;
;;;; ЧТО ГАРАНТИРУЕТСЯ СТАТИЧЕСКИ (и это ровно то, что гарантируется — не больше):
;;;;   1. провенанс: степень в типе, ни одного терма, её повышающего  ⇒ отмывание невыразимо
;;;;   2. роли молчания: слоты from/searched различны; searched берёт ТОЛЬКО молчание
;;;;   3. линейность молчания: порождённое обязано быть потреблено РОВНО раз
;;;;   4. присутствие гейта: необратимое недостижимо без порога и тотальной ветви отказа
;;;;   5. пустая посылочная база ⇒ ⊥
;;;;   6. свёртка гейта, КОГДА свидетели литеральны (иначе — рантайм, и это сказано вслух)
;;;;
;;;; 🔴 ЧЕГО НЕТ и не будет обещано: доказательства «b ≥ θ на всех путях» в общем случае.
;;;; f и c — рантайм-величины; решать это статически без SMT нельзя. Типы гарантируют не
;;;; отсутствие отказа, а то, что отказ ОБРАБОТАН. Пример 4 обещал больше — поправлено 28.07.

(load (merge-pathnames "common.lisp" *load-pathname*))

;;; Решётка, разбор предложений, масса веры, диагностика и словарь форм — в src/common.lisp.
;;; 🔴 Здесь остаётся ТОЛЬКО логика проверяющего. `chk-claim` обязана остаться отдельной от
;;; `red-claim`: на их раздельности стоит доказательство Невис (см. шапку common.lisp).

;;; ── окружение проверяющего ──────────────────────────────────────────────────
(defstruct (bnd (:constructor bnd (kind &key grade f c thr else origin roots)))
  kind grade f c thr else origin
  roots)   ; 🔴 ПОДДЕРЖКА как МНОЖЕСТВО корней (`formal/SupportSet.agda`). У свидетеля —
           ; {его корень}; у выведенного утверждения — ОБЪЕДИНЕНИЕ поддержек посылок.
           ; Прежде вывод не нёс корня вовсе, и свёртка группировала его по `nil`.

(defvar *env*) (defvar *sil*)

(defun look (id) (gethash id *env*))

(defun chk-horizon (form)
  "Горизонт программы. 🔴 Ставится в ПРЕДПРОХОДЕ, до чтения свидетелей: их веса считаются
   из (f,c) через `k`, и объявленный позже горизонт пересчитал бы уже прочитанное."
  (setf *k* (float (second form) 1.0)))

(defun chk-lattice (form)
  ;; (lattice ИМЯ молчание образ традиция строго)   ← линейная, снизу вверх
  ;; (lattice ИМЯ :product надёжность достоверность) ← произведение ранее объявленных
  ;; 🔴 Действующей становится ПОСЛЕДНЯЯ объявленная: части объявляются раньше произведения,
  ;; и это совпадает с порядком чтения. Правило простое и потому не требует запоминания.
  (let ((name (second form)) (rest* (cddr form)))
    (cond
      ;; ── произведение ──
      ((and rest* (eq (first rest*) :product))
       (let* ((part-names (rest rest*))
              (parts (mapcar (lambda (n) (cdr (assoc n *lattices*))) part-names)))
         (cond
           ((< (length part-names) 2)
            (err! :lattice name "произведение из одной решётки — это она сама, а не произведение"))
           ((some #'null parts)
            (err! :lattice name
                  "произведение ~a ссылается на необъявленную решётку ~{~a~^, ~}. ~
                   Части объявляются ДО произведения." name
                  (loop for n in part-names for p in parts unless p collect n)))
           (t (let ((desc (cons :product parts)))
                (push (cons name desc) *lattices*)
                (setf *lattice* desc))))))
      ;; ── линейная ──
      (t
       (let ((keys (mapcar (lambda (n) (intern (string-upcase (string n)) :keyword)) rest*)))
         (if (< (length keys) 2)
             (err! :lattice name
                   "решётка ~a объявлена меньше чем двумя степенями: сравнивать нечего" name)
             (let ((desc (list :linear keys)))
               (push (cons name desc) *lattices*)
               (setf *lattice* desc
                     ;; имена степеней ДОПОЛНЯЮТ словарь, а не заменяют его: в произведении
                     ;; нужны имена из ВСЕХ частей одновременно
                     *grade-alias*
                     (append (mapcar (lambda (n k) (cons (string-downcase (string n)) k))
                                     rest* keys)
                             *grade-alias*)
                     *grade-print*
                     (append (mapcar (lambda (n k) (cons k (string-downcase (string n))))
                                     rest* keys)
                             *grade-print*)))))))))

;;; ── ИМПОРТ МОДУЛЯ ───────────────────────────────────────────────────────────
(defun register-import (form)
  "ТИХАЯ регистрация модуля: имя → решётка источника + таблица φ. → описатель решётки или nil.
   🔴 Молчит НАМЕРЕННО: форму `import` читают три прохода (сбор корпуса у проверяющего,
   сбор корпуса у машины, сам проверяющий), и если бы диагностику давала регистрация,
   одна ошибка печаталась бы трижды. Ругается ровно один — chk-import."
  (let* ((name (second form))
         (desc (cdr (assoc (kw form :lattice) *lattices*)))
         (phi  (mapcar (lambda (row) (cons (parse-grade (car row)) (parse-grade (cdr row))))
                       (kw form :phi))))
    (when desc (push (cons name (list :lattice desc :phi phi)) *imports*))
    desc))

(defun chk-import (form)
  ;; (import ИМЯ :lattice ИМЯ-РЕШЁТКИ :phi ((степень . степень) …))
  (let* ((name (second form))
         (srcname (kw form :lattice))
         (desc (register-import form)))
    (cond
      ((null desc)
       (err! :import name
             "импорт ~a ссылается на необъявленную решётку ~a. Решётка источника ~
              объявляется ДО импорта: иначе нечему сопоставлять степени." name srcname))
      ;; 🔴 Совпадение решёток — почти всегда ошибка ПОРЯДКА, и сказать это надо прямо.
      ((equal desc *lattice*)
       (err! :import name
             "импорт ~a отображает решётку ~a в неё же: действующей решёткой сейчас ~
              является она сама.~%  Действующей становится ПОСЛЕДНЯЯ объявленная — ~
              объявите решётку импортёра ПОСЛЕ решётки источника." name srcname))
      (t (chk-phi name desc (module-phi (module-of name)))))))

(defun chk-phi (name src phi)
  "Проверка условий импорта ПЕРЕБОРОМ по конечной решётке источника.
   Порядок жёсткий: сперва таблица (тотальность, чужие ключи, чужие значения), и только
   на полной таблице — грань и дно. Иначе пробел в таблице породил бы лавину ложных
   расхождений на парах, где φ просто не определена."
  (let* ((dst *lattice*)
         (elems (lat-elements src))
         (miss  (remove-if (lambda (g) (assoc g phi :test #'equal)) elems))
         (extra (remove-if (lambda (row) (member (car row) elems :test #'equal)) phi))
         (bad   (remove-if (lambda (row) (and (cdr row) (g-shape-ok-p dst (cdr row)))) phi)))
    (cond
      (miss (err! :import name
                  "φ модуля ~a не определена на степенях: ~{~a~^, ~}.~%  ~
                   Таблица обязана быть ПОЛНОЙ: всякая степень источника обязана ~
                   получить образ, иначе свидетель с ней не имеет степени вовсе."
                  name (mapcar #'g-ru miss)))
      (extra (err! :import name
                   "φ модуля ~a отображает ~{~a~^, ~} — этого нет в решётке источника."
                   name (mapcar (lambda (r) (g-ru (car r))) extra)))
      (bad (err! :import name
                 "φ модуля ~a отправляет ~{~a~^, ~} за пределы решётки импортёра."
                 name (mapcar (lambda (r) (if (cdr r) (g-ru (cdr r)) "?")) bad)))
      (t
       ;; ── φ(⊥ˢ) = ⊥ᵈ ──
       (let ((pb (cdr (assoc (g-bot-of src) phi :test #'equal))))
         (unless (equal pb (g-bot-of dst))
           (err! :import name
                 "φ модуля ~a не сохраняет дно: φ(~a) = ~a, а дно импортёра — ~a.~%  ~
                  Пустая посылочная база после импорта перестала бы быть ⊥ — ~
                  и вернулось бы отмывание из ничего."
                 name (g-ru (g-bot-of src)) (g-ru pb) (g-ru (g-bot-of dst)))))
       ;; ── φ(a ⊓ b) = φ(a) ⊓ φ(b) на ВСЕХ парах ──
       ;; 🔴 Перебор ЕСТЬ доказательство квантора, а не выборка из него: решётка конечна
       ;; (тот же довод, что для правил — САМОЦВЕТЫ, ход 11). Сообщаем ПЕРВУЮ пару,
       ;; на которой сломалось: чинить надо её, а не читать список.
       (let ((broken nil))
         (dolist (a elems)
           (dolist (b elems)
             (unless broken
               (let ((left  (cdr (assoc (g-meet-in src a b) phi :test #'equal)))
                     (right (g-meet-in dst (cdr (assoc a phi :test #'equal))
                                       (cdr (assoc b phi :test #'equal)))))
                 (unless (equal left right)
                   (setf broken (list a b left right)))))))
         (when broken
           (destructuring-bind (a b left right) broken
             (err! :import name
                   "φ модуля ~a не сохраняет нижнюю грань. Сломалось на паре ~a и ~a:~%  ~
                    φ(~a ⊓ ~a) = ~a, а φ(~a) ⊓ φ(~a) = ~a.~%  ~
                    Значит «отобразить, потом свернуть» и «свернуть, потом отобразить» ~
                    дают РАЗНОЕ — и порядок посылок снова начинает значить на границе ~
                    модуля. Условие равносильное (formal/ModuleImport.agda, necessary): ~
                    ослабить его нельзя."
                   name (g-ru a) (g-ru b) (g-ru a) (g-ru b) (g-ru left)
                   (g-ru a) (g-ru b) (g-ru right)))))))))

(defun chk-witness (form)
  ;; (witness ID "текст" :grade строго :f 0.9 :c 0.8 [:module M])
  ;; 🔴 Свидетель модуля объявляет степень в шкале ИСТОЧНИКА; в окружение ложится φ(степень).
  ;; Корень (:source) φ не трогает — провенанс границу проходит неизменным.
  (let* ((id (second form))
         (mod (kw form :module))
         (raw (parse-grade (kw form :grade 'образ)))
         (g   nil))
    (if (null mod)
        (progn (setf g raw)
               (unless g (err! :grade id "неизвестная степень у свидетеля ~a" id)))
        (multiple-value-bind (v why) (grade-through-module mod raw)
          (setf g v)
          (case why
            (:unknown-module
             (err! :import id
                   "свидетель ~a объявлен из модуля ~a, который не импортирован ~
                    (или его импорт не сложился). Импорт объявляется ДО своих свидетелей."
                   id mod))
            (:unknown-grade (err! :grade id "неизвестная степень у свидетеля ~a" id))
            (:foreign-grade
             (err! :grade id
                   "степень ~a свидетеля ~a не принадлежит решётке модуля ~a. ~
                    Свидетель модуля объявляет степень в шкале ИСТОЧНИКА, не в своей."
                   (g-ru raw) id mod))
            (:phi-undefined
             (err! :import id
                   "φ модуля ~a не определена на степени ~a свидетеля ~a." mod (g-ru raw) id)))))
    ;; 🔴 ФОРМА СТЕПЕНИ обязана совпасть с формой действующей решётки — здесь, у истока,
    ;; а не при первой же грани. Прежде такой свидетель доходил до `g-meet` и ронял
    ;; проверяющий бэктрейсом (находка харнесса оракула, 29.07): пользователь получал
    ;; крах вместо диагностики, а крах не объясняет, что именно он написал не так.
    (when (and g (not (g-shape-ok-p *lattice* g)))
      (err! :grade-shape id "у свидетеля ~a ~a" id (g-shape-error g))
      (setf g nil))
    ;; 🔴 КОРЕНЬ свидетеля — ближайший известный источник; нет источника → сам себе корень.
    (let ((root (or (first (kw form :source)) id)))
      (multiple-value-bind (ff cc)
        (if (kw form :w+) (evidence->fc (kw form :w+) (kw form :w- 0.0))
            (values (kw form :f 0.9) (kw form :c 0.8)))
      (setf (gethash id *env*)
            (bnd :jud :grade (or g (g-bot)) :f ff :c cc
                 :origin root :roots (list root)))))))

(defun chk-ask (form)
  ;; (ask ID :in (corpus library) :reason "…")  → молчание, ЛИНЕЙНОЕ
  (let ((id (second form)))
    (setf (gethash id *env*) (bnd :silence :grade (g-bot) :f 0.5 :c 0.0))
    (setf (gethash id *sil*) :pending)))

(defun use-silence! (id where)
  (case (gethash id *sil*)
    (:pending (setf (gethash id *sil*) :used))
    (:used (err! :reused where
                 "молчание ~a потреблено дважды. Молчание линейно: ровно один раз, ~
                  либо опорой, либо обзором — иначе один охват сойдёт за два." id))))

;;; 🔴 ОТЗЫВ ЖИВЁТ И В ПРОВЕРЯЮЩЕМ — иначе типовой слой солжёт. Если машина пересчитывает
;;; основание, а компилятор нет, статическая степень разойдётся с динамической, и вся
;;; здравость (РЕДУКЦИЯ §4.3) обратится в украшение. Пересчёт тот же: отозванный
;;; свидетель выпадает из основания целиком.
(defvar *dead* '())
(defvar *done* '())

;;; 🔴 Квантор по корпусу: тот же предикат, что у машины (общий, иначе статика разойдётся
;;; с прогоном), но обход СВОЙ — раздельность chk/red несёт доказательство.
(defvar *corpus-c* '() "Все свидетели программы: (имя степень корень).")

(defun collect-corpus-c (forms)
  ;; см. тот же комментарий в reduce.lisp: решётка объявляется до того, как читать степени.
  ;; 🔴 И импорт — тоже: степень свидетеля модуля читается ЕГО решёткой и проходит через φ,
  ;; так что к моменту чтения свидетеля модуль обязан быть зарегистрирован.
  (let ((out '()))
    (dolist (f forms (nreverse out))
      (when (and (consp f) (string= (head-of f) "horizon")) (chk-horizon f))
      ;; 🔴 Горизонт — как решётка: ставится ДО чтения свидетелей, иначе их (f,c) считались бы
      ;; не тем `k`, который объявила программа.
      (when (and (consp f) (string= (head-of f) "horizon")) (chk-horizon f))
      (when (and (consp f) (string= (head-of f) "lattice")) (chk-lattice f))
      (when (and (consp f) (string= (head-of f) "import"))  (register-import f))
      (when (and (consp f) (string= (head-of f) "witness"))
        (let* ((mod (kw f :module))
               (raw (parse-grade (kw f :grade)))
               (g   (if mod (grade-through-module mod raw) raw)))
          ;; счёт, если он есть, переводится в (f,c) ЗДЕСЬ — уже с горизонтом программы
          (multiple-value-bind (ff cc)
              (if (kw f :w+) (evidence->fc (kw f :w+) (kw f :w- 0.0))
                  (values (kw f :f 0.9) (kw f :c 0.8)))
            (push (list (second f) (or g (g-bot))
                        (or (first (kw f :source)) (second f)) ff cc)
                  out)))))))

(defun root-best-c (dead)
  "Корень → его тяжелейший свидетель: (корень имя f c). Свой обход, не общий с машиной.
   🔴 Вес есть свойство КОРНЯ: масса читает членство в поддержке, а не список посылок."
  (let ((tbl '()))
    (dolist (w *corpus-c* tbl)
      (destructuring-bind (name grade root &optional (f 0.9) (c 0.8)) w
        (declare (ignore grade))
        ;; 🔴 Нелитеральный свидетель (нет f/c) в таблицу НЕ входит: его вес неизвестен
        ;; статически. Тогда корень не найдётся, и обход честно пометит основание
        ;; нелитеральным — то есть скажет «решится прогоном», а не соврёт числом.
        (unless (or (member name dead) (member root dead) (null f) (null c))
          (multiple-value-bind (wp wm) (fc->evidence f c)
            (let ((cell (assoc root tbl)))
              (if (null cell)
                  (push (list root name f c (+ wp wm)) tbl)
                  (when (> (+ wp wm) (fifth cell))
                    (setf (cdr cell) (list name f c (+ wp wm))))))))))))

(defun select-c (spec)
  "→ (values подошедшие отсеянные). Свой обход: свёртка справа, не накопление слева."
  (let ((in '()) (out '()))
    (dolist (w (reverse *corpus-c*))
      (destructuring-bind (name grade root &optional f c) w
        (declare (ignore f c))
        (unless (or (member name *dead*) (member root *dead*))
          (if (witness-matches-p grade root spec)
              (push name in)
              (push name out)))))
    (values in out)))

(defun chk-claim (form)
  ;; (claim ID [:grade строго] (from A B …) [(searched S …)])
  (let* ((id       (second form))
         (declared (let ((g (kw form :grade))) (and g (parse-grade g))))
         (all-spec (let ((x (clause form "from-all"))) (if (eq x :нет) nil (or x '(:все)))))
         (need-roots (let ((x (clause form "requiring-roots"))) (if (eq x :нет) nil (first x))))
         (from     (if all-spec
                       (let ((spec (if (eq (first all-spec) :все) '() all-spec)))
                         ;; форма условия обязана совпасть с формой решётки
                         (let ((gs (getf spec :grade>=)))
                           (when gs
                             (let ((g (if (keywordp gs) gs (parse-grade gs))))
                               (unless (and g (g-shape-ok-p *lattice* g))
                                 (err! :grade-shape id "~a" (g-shape-error gs))))))
                         (select-c spec))
                       (clause form "from")))
         (searched (clause form "searched"))
         (from     (if (eq from :нет) '() from))
         (searched (if (eq searched :нет) '() searched))
         ;; отозванные посылки выпадают из основания ДО всякого счёта
         ;; мёртв сам свидетель ИЛИ его корень — отзыв предка снимает потомков
         (from     (remove-if (lambda (p)
                                (let ((b (look p)))
                                  (or (member p *dead*)
                                      (and b (bnd-origin b) (member (bnd-origin b) *dead*)))))
                              from)))

    ;; ── обзорный слот принимает ТОЛЬКО молчание (заказ §5.2) ──
    (dolist (s searched)
      (let ((b (look s)))
        (cond ((null b) (err! :unknown id "обзорная роль ссылается на неизвестное ~a" s))
              ((not (eq (bnd-kind b) :silence))
               (err! :slot id
                     "в обзорную роль (searched) подан свидетель ~a. Обзор принимает ~
                      только молчание: иначе свидетель прошёл бы мимо нижней грани — ~
                      отмывание через чёрный ход." s))
              (t (use-silence! s id)))))

    ;; ── опорный слот: свёртка ⊕ по РАЗЛИЧНЫМ id + нижняя грань степеней ──
    (let ((seen '()) (f 0.5) (c 0.0)
          ;; 🔴 пустая база — ДНО, не верх решётки (заказ §5.6)
          (grade (if (null from) (g-bot) (g-top)))
          (roots '())
          (literal t))
      ;; 🔴 Свёртка по КОРНЯМ. Реализация СВОЯ, не общая с машиной: на раздельности
      ;; chk-claim/red-claim стоит доказательство Невис (см. шапку common.lisp).
      ;; Здесь идём иначе — сперва собираем лучших по корню, потом ревизуем слева.
      ;; 🔴 СТЕПЕНЬ и МАССА считаются РАЗНЫМИ обходами, и это не удвоение работы.
      ;; Степень — по посылкам (у вывода берётся ЕГО собственная: объявленная ниже выведенной
      ;; не должна подниматься обратно к своему корню). Масса — по ЧЛЕНСТВУ В ПОДДЕРЖКЕ,
      ;; и поддержка вывода есть ОБЪЕДИНЕНИЕ поддержек его посылок (`formal/SupportSet.agda`).
      (let ((best-by-root '()) (support '()))
        (dolist (p from)
          (let ((b (look p)))
            (cond
              ((null b) (err! :unknown id "опорная роль ссылается на неизвестное ~a" p)
                        (setf literal nil))
              ((eq (bnd-kind b) :action)
               (err! :slot id "действие ~a не может быть посылкой утверждения" p))
              (t
               (when (eq (bnd-kind b) :silence) (use-silence! p id))
               (unless (member p seen)               ; дисциплина тождества
                 (push p seen)
                 (cond
                   ((eq (bnd-kind b) :silence) (setf grade (g-meet grade (g-bot))))
                   ;; выведенное утверждение: своя степень, поддержка — объединением
                   ((and (bnd-roots b) (null (bnd-origin b)))
                    (dolist (r (bnd-roots b)) (pushnew r support))
                    (setf grade (g-meet grade (bnd-grade b))))
                   (t
                    (when (bnd-origin b) (pushnew (bnd-origin b) support))
                    (let* ((root (bnd-origin b))
                           (cell (assoc root best-by-root))
                           (w (if (and (bnd-f b) (bnd-c b))
                                  (multiple-value-bind (wp wm) (fc->evidence (bnd-f b) (bnd-c b))
                                    (+ wp wm))
                                  -1)))
                      (when (= w -1) (setf literal nil))
                      (if (null cell)
                          (push (list root w b) best-by-root)
                          (when (> w (second cell)) (setf (cdr cell) (list w b))))))))))))
        ;; степень — по представителям групп свидетелей
        (dolist (cell (reverse best-by-root))
          (setf grade (g-meet grade (bnd-grade (third cell)))))
        ;; 🔴 масса — по членству: каждый корень поддержки вносит вес РОВНО ОДИН раз
        (let ((tbl (root-best-c *dead*)))
          (dolist (r (reverse support))
            (let ((cell (assoc r tbl)))
              (if cell
                  (multiple-value-setq (f c) (t-revise f c (third cell) (fourth cell)))
                  (setf literal nil)))))
        (setf roots (reverse support)))

      ;; требование к множеству: не хватило различных корней ⇒ дно (как пустая база)
      (when need-roots
        (when (< (length roots) need-roots) (setf grade (g-bot))))

      ;; ── ЗАПРЕТ ОТМЫВАНИЯ: объявленная степень не выше выведенной (заказ §5.5) ──
      (when (and declared (not (g<= declared grade)))
        (err! :launder id
              "нельзя объявить [~a] на основании [~a].~%  ~
               выведено из посылок: ~a~%  ~
               чтобы поднять — предъявите свидетеля нужной степени; ~
               операции повышения степени в языке НЕТ."
              (g-ru declared) (g-ru grade) (g-ru grade)))

      (setf (gethash id *env*)
            (bnd :jud :grade (if (and declared (g<= declared grade)) declared grade)
                      :f (and literal f) :c (and literal c)
                      :roots roots)))))

(defun chk-action (form)
  ;; (action NAME :reversibility irreversible :requires (>= belief 0.9) :else fold)
  (let* ((id  (second form))
         (rev (kw form :reversibility 'reversible))
         (req (kw form :requires))
         (els (kw form :else))
         (thr (and (consp req) (third req)))
         (qty (and (consp req) (second req))))
    (when (and (consp req) qty (not (string= (string-downcase (string qty)) "belief")))
      (err! :quantity id
            "гейт повешен на ~a. Порог сравнивается с МАССОЙ ВЕРЫ b = f·c, и ни с чем ~
             другим: c=0.95 при f=0.50 — высокая уверенность в том, что мы разорваны ~
             пополам; f=0.99 при c=0.01 — один уверенный шёпот. (АЛГЕБРА §1.3)" qty))
    (when (and (string= (string-downcase (string rev)) "irreversible") (null req))
      (err! :ungated id
            "необратимое действие ~a объявлено без гейта. Необратимое недостижимо ~
             без порога по массе веры." id))
    ;; 🔴 Возмещение обязано быть ОБЪЯВЛЕННЫМ действием: у него свой гейт и своя цена ошибки.
    ;; Имя, за которым ничего не стоит, — это «названо», а не «сделано»; ровно та разница,
    ;; ради которой компенсация и заводилась действием, а не пометкой.
    (let ((comp (kw form :compensated-by)))
      (when comp
        (let ((b (look comp)))
          (cond
            ((null b)
             (err! :unknown id "~a возмещается через ~a, но такого действия не объявлено.~%  ~
                                Возмещение — действие со своим гейтом, а не имя." id comp))
            ((not (eq (bnd-kind b) :action))
             (err! :slot id "~a возмещается через ~a, а это не действие" id comp))))))
    (when (and req (null els))
      (err! :no-else id
            "гейт у ~a без ветви отказа. Порог, который нечем не пройти, не гейт: ~
             нужна :else (fold / подпись человека / понижение класса)." id))
    ;; ── ТРЕБОВАНИЕ К СТЕПЕНИ ОСНОВАНИЯ (`formal/Act.agda`, Невис 29.07) ──────────
    (let ((need (let ((g (kw form :needs-grade))) (and g (parse-grade g)))))
      (when (and (kw form :needs-grade) (null need))
        (err! :grade id "неизвестная степень в требовании действия ~a" id))
      (when (and need (not (g-shape-ok-p *lattice* need)))
        (err! :grade-shape id "в требовании действия ~a: ~a" id (g-shape-error need))
        (setf need nil))
      ;; 🔴 НЕОБРАТИМОЕ, ТРЕБУЮЩЕЕ ДНА, — ЭТО НЕ ТРЕБОВАНИЕ. Её `no-irreversible-on-bottom`
      ;; даёт защиту ровно при `req ≢ ⊥`: при требовании-дне типизируется что угодно
      ;; (`bottom-blocks`), и запись выглядела бы защитой, не будучи ею.
      (when (and (string= (string-downcase (string rev)) "irreversible")
                 need (equal need (g-bot)))
        (err! :req id
              "необратимое ~a требует основания степени [~a] — это дно решётки, ~
               то есть не требует ничего.~%  Запись выглядит защитой, не будучи ею: ~
               на дне типизируется любое основание. Назовите степень выше дна." id (g-ru need)))
      (setf (gethash id *env*) (bnd :action :thr thr :else els :grade need)))))

(defun root-known-p (name)
  "Есть ли свидетель, чей корень — NAME? Тогда NAME можно отозвать как источник."
  (let ((found nil))
    (maphash (lambda (k b) (declare (ignore k))
               (when (and (eq (bnd-kind b) :jud) (eq (bnd-origin b) name)) (setf found t)))
             *env*)
    found))

(defun chk-retract (form)
  ;; (retract W :reason "…") — свидетель выбывает, основания пересчитываются
  (let* ((w (second form)) (b (look w)))
    ;; отзывать можно свидетеля ИЛИ КОРЕНЬ (источник, на который кто-то ссылается):
    ;; отзыв корня снимает всех потомков сам, без отдельного правила
    (cond ((and (null b) (not (root-known-p w)))
           (err! :unknown w "отозван неизвестный свидетель или источник ~a" w))
          ((and b (not (eq (bnd-kind b) :jud)))
           (err! :slot w "отозвать можно свидетеля или источник; ~a — ни то, ни другое" w))
          (t
           (pushnew w *dead*)
           ;; перепрогон уже обработанного при новом мёртвом множестве (как в машине)
           (let ((*errs* '()) (prefix (reverse *done*)))
             (clrhash *env*) (clrhash *sil*)
             (dolist (f prefix)
               (let ((h (head-of f)))
                 (cond ((string= h "horizon") (chk-horizon f))
                       ((string= h "lattice") (chk-lattice f))
                       ;; регистрация, а не проверка: об ошибке импорта уже сказано один раз
                       ((string= h "import")  (register-import f))
                       ((string= h "witness") (chk-witness f))
                       ((string= h "ask")     (chk-ask f))
                       ((string= h "claim")   (chk-claim f))
                       ((string= h "action")  (chk-action f))))))))))

(defun chk-revoke (form)
  ;; (revoke ИМЯ :reason "…")
  ;; 🔴 ТРИ СЛУЧАЯ, и два из них — добавления Невис, которых я не видел:
  ;;  (1) отзыв разрешения, которого никто не давал  → :unknown («нельзя отозвать то, чего
  ;;      не давали» — у неё это теорема `no-perm-never-unauthorized`);
  ;;  (2) отзыв ЧУЖОГО разрешения — НЕ :unknown, а отдельная ошибка: форма записана верно,
  ;;      лицо существует, права нет. Молчаливо пропустить хуже, чем не понять;
  ;;  (3) до/после совершения — разные вещи. До: действие просто не совершится. После:
  ;;      `unauthorized` описывает не запрет, а ФАКТ О ПРОШЛОМ — «это было сделано без
  ;;      права», и оно неисправимо, как `irreparable`. Различие проводит машина; здесь
  ;;      проверяющий говорит, что отзыв придёт ПОСЛЕ совершения, если это так.
  (let* ((who (second form))
         (даватели '()) (совершено '()))
    (dolist (f *done*)
      (when (consp f)
        (let ((h (head-of f)))
          (when (string= h "action")
            (let ((p (kw f :permission)))
              (when p (pushnew (second p) даватели))))
          (when (string= h "do") (pushnew (third f) совершено)))))
    (cond
      ((null даватели)
       (err! :unknown who
             "отзывается разрешение от ~a, но ни одно действие в программе на разрешение ~
              не ссылалось.~%  Нельзя отозвать то, чего не давали." who))
      ((not (member who даватели))
       ;; 🔴 ЭТО НЕ :unknown. Лицо есть, форма верна — нет ПРАВА отзывать чужое.
       (err! :authority who
             "~a отзывает разрешение, которого не давал~%  ~
              (в программе разрешения дали: ~{~a~^, ~}).~%  ~
              Разрешение адресно: кто дал, тот и отзывает. Право распоряжаться чужим ~
              словом само есть право, и его тут никто не предъявлял."
             who (reverse даватели)))
      (совершено
       ;; не ошибка — сообщение о РОДЕ последствия
       (err! :runtime who
             "разрешение от ~a отзывается ПОСЛЕ совершения действия.~%  ~
              Это не запрет, а факт о прошлом: сделанное было сделано без права, и ~
              исправить это нельзя — как нельзя исправить непоправимое.~%  ~
              Основание при этом ЦЕЛО: вера не изменится, свидетели живы." who)))))

(defun chk-do (form)
  ;; (do ACTION CLAIM)
  (let* ((an (second form)) (cn (third form))
         (a (look an)) (j (look cn)))
    (cond
      ((null a) (err! :unknown an "неизвестное действие ~a" an))
      ((not (eq (bnd-kind a) :action)) (err! :slot an "~a — не действие" an))
      ((null j) (err! :unknown cn "неизвестное основание ~a" cn))
      ((not (eq (bnd-kind j) :jud)) (err! :slot cn "~a — не утверждение" cn))
      (t
       ;; ── 🔴 ТРЕБОВАНИЕ К СТЕПЕНИ — ПРОВЕРКА ТИПИЗАЦИИ, А НЕ ГЕЙТ ────────────────
       ;; `Typed basis a` существует, только если `req a ⊑ grade(basis)` (`formal/Act.agda`).
       ;; Это ОШИБКА, а не замечание: `gate-fail` есть исход программы (свернётся, как
       ;; написано), а недостаточная степень основания — программа, которой не должно быть.
       ;; Разница ровно та, что между «веры не хватило» и «так писать нельзя».
       (let ((need (bnd-grade a)))
         (when (and need (not (g<= need (bnd-grade j))))
           (err! :req an
                 "~a требует основания не ниже [~a], а ~a имеет [~a].~%  ~
                  Это не нехватка веры — свидетельств можно принести сколько угодно, ~
                  происхождение от этого не изменится.~%  ~
                  Поднять степень нечем: операции подъёма в языке НЕТ. Нужен свидетель ~
                  нужной степени — или действие другого класса."
                 an (g-ru need) cn (g-ru (bnd-grade j)))))
       ;; ── свёртка гейта, КОГДА свидетели литеральны; иначе честно в рантайм ──
       (let ((b (belief (bnd-f j) (bnd-c j))) (thr (bnd-thr a)))
         (cond
           ((and b thr (< b thr))
            (err! :gate-fail an
                  "необратимое ~a при массе веры ~,3f < ~,3f.~%  ~
                   f=~,3f c=~,3f b=f·c=~,3f~%  ~
                   доступно: (1) ещё свидетель (2) понизить класс (3) :else ~a ~
                   (4) подпись человека"
                  an b thr (bnd-f j) (bnd-c j) b (bnd-else a)))
           ((and thr (null b))
            ;; не ошибка — честная граница статики
            (err! :runtime an
                  "гейт ~a решается в рантайме: основание ~a собрано не из литеральных ~
                   свидетелей. Статически проверено, что гейт ЕСТЬ и у него есть ветвь ~
                   отказа; выполнится ли порог — покажет прогон." an cn))))))))

;;; ── прогон ──────────────────────────────────────────────────────────────────
;; "rule" пропущено СОЗНАТЕЛЬНО: правило раскрывается подстановкой при разборе и до
;; проверяющего доходит только как запись в тексте программы. Проверять нечего — проверяется
;; каждое РАСКРЫТОЕ применение, на своих конкретных степенях.
(assert-covers "check-program"
               '("lattice" "horizon" "import" "retract" "revoke" "witness" "ask" "claim" "action" "do")
               :skip '("rule"))
;; перепрогон внутри chk-retract действий не совершает — то же основание, что у `replay`
(assert-covers "chk-retract/перепрогон" '("lattice" "horizon" "import" "witness" "ask" "claim" "action")
               :skip '("do" "retract" "revoke" "rule"))

(defun check-program (forms)
  "→ (values env errors). Ошибки в порядке появления."
  (with-prelude
   (let ((*env* (make-hash-table :test #'eq))
        (*sil* (make-hash-table :test #'eq))
        (*errs* '())
        (*dead* '()) (*done* '())
        (*corpus-c* (collect-corpus-c forms)))
    (dolist (form forms)
      (when (consp form)
        (let ((head (head-of form)))
          (cond ((string= head "horizon") (chk-horizon form))
                ((string= head "lattice") (chk-lattice form))
                ((string= head "import")  (chk-import form))
                ((string= head "retract") (chk-retract form))
                ((string= head "revoke")  (chk-revoke form))
                ((string= head "witness") (chk-witness form))
                ((string= head "ask")     (chk-ask form))
                ((string= head "claim")   (chk-claim form))
                ((string= head "action")  (chk-action form))
                ((string= head "do")      (chk-do form))
                ((string= head "rule") nil)   ; раскрыто при разборе, см. assert-covers выше
                (t (err! :unknown-form (first form) "неизвестная форма ~a" (first form))))
          (push form *done*))))
    ;; ── линейность молчания: долги не прощаются (заказ §5.3) ──
    (maphash (lambda (id st)
               (when (eq st :pending)
                 (err! :dropped id
                       "молчание ~a порождено и не потреблено. Спросил, не нашёл и ~
                        промолчал об этом — охват скрыт. Потребите опорой (и заплатите ⊥) ~
                        либо обзором (и оно будет напечатано)." id)))
             *sil*)
    (values *env* (nreverse *errs*)))))

(defun errors-of (forms &optional (codes nil))
  "Коды ошибок программы; при CODES — только указанных родов."
  (multiple-value-bind (env errs) (check-program forms)
    (declare (ignore env))
    (let ((cs (mapcar #'terr-code errs)))
      (if codes (remove-if-not (lambda (c) (member c codes)) cs) cs))))

(defun grade-of (forms id)
  (multiple-value-bind (env errs) (check-program forms)
    (declare (ignore errs))
    (let ((b (gethash id env))) (and b (bnd-grade b)))))

(defun diagnose (forms)
  "Человеку: напечатать диагностику так, как её печатал бы компилятор."
  (multiple-value-bind (env errs) (check-program forms)
    (declare (ignore env))
    (if (null errs)
        (format t "~&✓ программа принята~%")
;; 🔴 `gate-fail` — ЗАМЕЧАНИЕ, а не ошибка (найдено живым примером 28.07).
        ;; У необратимого действия ветвь отказа ОБЯЗАТЕЛЬНА грамматикой, значит непрохождение
        ;; порога — не дефект программы, а её ИСХОД: она свернётся, как и написано. Ошибкой
        ;; было бы отсутствие ветви, но оно невыразимо. Статическая свёртка полезна тем, что
        ;; говорит автору ЗАРАНЕЕ, насколько он не дотянул, — это подсказка, а не отказ.
        (dolist (e errs)
          (say-error (if (member (terr-code e) '(:runtime :gate-fail)) "ЗАМЕЧАНИЕ" "ОШИБКА")
                     (terr-code e)
                     (and (terr-where e) (format nil "у ~a" (terr-where e)))
                     (terr-text e))))
    errs))
