;;;; nolang src — reduce. ОПЕРАЦИОННАЯ СЕМАНТИКА: что значит «выполнить» программу.
;;;; Пятый шаг Ф3 + ОТЗЫВ СВИДЕТЕЛЯ (долг №1, закрыт 28.07). Малый шаг: одно объявление — один переход.
;;;;
;;;; КОНФИГУРАЦИЯ  ⟨ Σ ; Δ ; Λ ; D ; H ; P ⟩
;;;;   Σ  склад значений      id ↦ суждение ⟨g, w⁺, w⁻, основание⟩ | молчание | свёрток | действие
;;;;   Δ  непотреблённые молчания (линейный контекст — тот же, что в типах)
;;;;   Λ  ЖУРНАЛ: что совершено, на каком основании, при какой массе веры — ДОПИСЫВАЕМЫЙ
;;;;   D  отозванные свидетели (множество мёртвых)
;;;;   H  уже обработанные объявления (нужны для пересчёта при отзыве)
;;;;   P  остаток программы
;;;;
;;;; 🔴 ЧЕТЫРЕ РЕШЕНИЯ:
;;;; 1. Выполнение — не последовательность команд, а РОСТ СКЛАДА. Порядок объявлений
;;;;    (при соблюдении зависимостей) на итог не влияет: ⊕ и ⊓ коммутативны и ассоциативны.
;;;; 2. ОТКАЗ ГЕЙТА — ЗНАЧЕНИЕ, А НЕ ИСКЛЮЧЕНИЕ. `fold` кладёт на склад СВЁРТОК: что
;;;;    пытались, на чём стояли, какого порога не хватило и НАСКОЛЬКО.
;;;; 3. Ни одно действие не остаётся сиротой: Λ хранит основание КАЖДОГО действия.
;;;; 4. 🔴 ОТЗЫВ — ОПЕРАЦИЯ НАД ОСНОВАНИЕМ, А НЕ НАД ЗНАЧЕНИЕМ. Моноиду не нужно
;;;;    становиться группой: утверждение хранит СВОИ ПОСЫЛКИ (иначе не было бы провенанса),
;;;;    значит отозвать свидетеля = убрать его из основания и ПЕРЕСЧИТАТЬ. Наивное вычитание
;;;;    весов даёт отрицательный вес в 23% случайных случаев (счёт: 70 из 300); пересчёт
;;;;    неотрицателен ПО ПОСТРОЕНИЮ. Провенанс, заведённый ради честности, оплатил алгебру.

(load (merge-pathnames "check.lisp" *load-pathname*))

;;; ── значения склада ─────────────────────────────────────────────────────────
;; 🔴 Суждение несёт не только основание, но и ОХВАТ (обзорные молчания) и ОПОРУ-НА-МОЛЧАНИЕ
;; (опорные молчания). Без этих двух полей охват потреблён и НЕВИДИМ — ровно то состояние,
;; против которого заведена линейность молчания (АЛГЕБРА §3). Печать их — часть семантики.
;; ORIGIN — ближайший известный источник свидетеля. ROOTS/COLLAPSED — что вошло в свёртку
;; и что было поглощено как копия того же корня (см. red-claim).
(defstruct (jv (:constructor jv (grade w+ w- &optional base cover leaned origin roots collapsed
                                 dropped short-roots (k *k*))))
  grade w+ w- base cover leaned origin roots collapsed
  ;; 🔴 ГОРИЗОНТ СОХРАНЯЕТСЯ В МОМЕНТ СОЗДАНИЯ, а не читается при вычислении веры.
  ;; Найдено при вводе `horizon` (29.07) — и это ВТОРОЙ раз за сутки, когда я нарушаю
  ;; собственный закон: «отложенное вычисление в контексте, которого больше нет, — это не
  ;; поздний ответ, а чужой». `jv-belief` зовётся ПОСЛЕ прогона, когда `with-prelude` уже
  ;; вернул прелюдный `k`, и вера считалась бы не тем горизонтом, который объявила программа.
  ;; Первый раз то же было со степенью в вердикте. Закон, записанный и нарушенный дважды,
  ;; надо не перечитывать, а встраивать в носитель — вот он, слот.
  dropped        ; отсеянные квантором: (имя степень частота) — ОБЯЗАНЫ быть видны
  short-roots    ; требование к множеству не выполнено: (нужно есть)
  k)             ; горизонт, действовавший при создании
(defstruct (sv (:constructor sv (where why))) where why)
(defstruct (fv (:constructor fv (action on b thr lack))) action on b thr lack)
(defstruct (av (:constructor av (rev thr else comp &optional need perm))) rev thr else comp
  need
  perm)  ; (цитата кто дата) — РАЗРЕШЕНИЕ. Не на решётке основания: другой род (право, не факт).  ; 🔴 требуемая степень основания. Машина её НЕ проверяет: это дело типизации
         ; (`formal/Act.agda`). Хранится ради вердикта — чтобы точка решения могла назвать,
         ; чего действие требовало, даже когда программа уже отвергнута проверяющим.

(defun jv-fc (j)
  "🔴 Вера считается ТЕМ горизонтом, что действовал при создании значения, а не тем,
   что случился при печати. См. слот `k` выше."
  (evidence->fc (jv-w+ j) (jv-w- j) (or (jv-k j) *k*)))
(defun jv-belief (j) (multiple-value-bind (f c) (jv-fc j) (* f c)))

;;; ── конфигурация ────────────────────────────────────────────────────────────
(defstruct (cfg (:constructor cfg (store pending ledger dead done rest)))
  store pending ledger dead done rest)

(defun cfg-final-p (c) (null (cfg-rest c)))

(defun store-put (store id val)
  (let ((new (make-hash-table :test #'eq)))
    (maphash (lambda (k v) (setf (gethash k new) v)) store)
    (setf (gethash id new) val)
    new))

;;; ── шаги над складом ────────────────────────────────────────────────────────
(defun red-witness (form store)
  ;; R-WITNESS: свидетель ложится как СЧЁТ свидетельств, не как (f,c).
  ;; 🔴 И несёт КОРЕНЬ — ближайший известный источник. Без корня ⊕ складывает копии одного
  ;; свидетельства как независимые голоса: то же отмывание, только через родословную.
  ;; 🔴 Свидетель модуля: степень объявлена в шкале ИСТОЧНИКА и приходит через φ.
  ;; Корень при этом НЕ меняется — иначе один источник, пришедший двумя путями, перестал
  ;; бы узнаваться, и свёртка по корням сложила бы его как двух независимых.
  (let* ((id (second form)) (raw (parse-grade (kw form :grade)))
         (mod (kw form :module))
         (g (if mod (grade-through-module mod raw) raw))
         (f (kw form :f 0.9)) (c (kw form :c 0.8))
         ;; нет источника → сам себе корень (одиночка, ни с кем не группируется)
         (origin (or (first (kw form :source)) id)))
    ;; 🔴 СЧЁТ, ЕСЛИ ОН ЕСТЬ, БЕРЁТСЯ КАК ЕСТЬ. Поверхностный синтаксис отдаёт `w⁺`/`w⁻`
    ;; напрямую (см. `p-witness`): счёт есть носитель, `(f,c)` — карта над ним, и цена карты
    ;; зависит от `k`. Форма с `:f`/`:c` (внутренние тесты) переводится, как прежде.
    (multiple-value-bind (w+ w-)
        (if (kw form :w+) (values (kw form :w+) (kw form :w- 0.0)) (fc->evidence f c))
      (store-put store id (jv (or g (g-bot)) w+ w- nil nil nil origin)))))

(defun red-ask (form store)
  (store-put store (second form) (sv (kw form :in) (kw form :reason))))

;;; 🔴 Квантор бежит по ВСЕМУ корпусу, а не по объявленному выше: иначе перестановка
;;; объявлений меняла бы результат и рушилась конфлюэнтность (`perm-inv`). Отсюда два прохода.
(defvar *corpus* '()
  "Все свидетели программы: (имя степень корень f c модуль) — заполняется до прогона.
   МОДУЛЬ нужен не счёту, а отчёту: расхождение внутри корня МЕЖДУ модулями — не копии,
   а спорная передача, и её надо назвать отдельно (см. red-claim).")

(defun corpus-module (name)
  (sixth (assoc name *corpus*)))

(defun collect-corpus (forms)
  ;; 🔴 Решётки обрабатываются ПО ХОДУ сбора: степени свидетелей разбираются действующей
  ;; решёткой, а не прелюдией. Поймано живым примером 28.07 — корпус собирался раньше, чем
  ;; объявлялась решётка, и все степени читались не той таблицей.
  ;; То же и с импортом: модуль обязан быть зарегистрирован до чтения своих свидетелей.
  (let ((out '()))
    (dolist (f forms (nreverse out))
      (when (and (consp f) (string= (head-of f) "horizon")) (chk-horizon f))
      (when (and (consp f) (string= (head-of f) "lattice")) (chk-lattice f))
      (when (and (consp f) (string= (head-of f) "import"))  (register-import f))
      (when (and (consp f) (string= (head-of f) "witness"))
        (let* ((mod (kw f :module))
               (raw (parse-grade (kw f :grade)))
               (g   (if mod (grade-through-module mod raw) raw)))
          (multiple-value-bind (ff cc)
              (if (kw f :w+) (evidence->fc (kw f :w+) (kw f :w- 0.0))
                  (values (kw f :f 0.9) (kw f :c 0.8)))
            (push (list (second f) (or g (g-bot))
                        (or (first (kw f :source)) (second f))
                        ff cc mod)
                  out)))))))

;;; 🔴 СВИДЕТЕЛИ — ОБЪЯВЛЕНИЯ, А НЕ СОБЫТИЯ: они есть с самого начала, а не появляются по ходу.
;;; Склад наполняется ими ДО обхода. Иначе выходило так (поймано тестом конфлюэнтности 28.07):
;;; квантор видел весь корпус и отбирал верно, а свёртка читала склад — и свидетель, объявленный
;;; ПОСЛЕ утверждения, попадал в отбор, но веса не давал. Порядок объявлений менял веру ⇒
;;; ломался `perm-inv`. Предзаполнение чинит это и заодно делает независимым от порядка
;;; поимённый `from` тоже.
(defun prefill-store (corpus dead)
  (let ((store (make-hash-table :test #'eq)))
    (dolist (w corpus store)
      (destructuring-bind (name grade root f c &optional mod) w
        (declare (ignore mod))
        (unless (or (member name dead) (member root dead))
          (multiple-value-bind (w+ w-) (fc->evidence f c)
            (setf (gethash name store) (jv grade w+ w- nil nil nil root))))))))

(defun select-from-corpus (spec dead)
  "→ (values подошедшие отсеянные). Отсеянные записываются: отбор — вектор черри-пикинга."
  (let ((in '()) (out '()))
    (dolist (w *corpus*)
      (destructuring-bind (name grade root f c &optional mod) w
        (declare (ignore c mod))
        (unless (or (member name dead) (member root dead))   ; мёртвые не участвуют вовсе
          (if (witness-matches-p grade root spec)
              (push name in)
              (push (list name grade f) out)))))
    (values (nreverse in) (nreverse out))))

(defun root-best (corpus dead)
  "Корень → его лучший (тяжелейший) свидетель: (корень имя w⁺ w⁻ степень).
   🔴 ВЕС ЕСТЬ СВОЙСТВО КОРНЯ, А НЕ ССЫЛКИ НА НЕГО. Отсюда `mass-resp-∈` Невис
   (`formal/SupportSet.agda`): масса читает ЧЛЕНСТВО в поддержке, а не список посылок,
   и потому ни порядок, ни повторы, ни глубина вывода не могут её изменить —
   не по бдительности автора, а потому что невыразимо."
  (let ((tbl '()))
    (dolist (w corpus tbl)
      (destructuring-bind (name grade root f c &optional mod) w
        (declare (ignore mod))
        ;; нелитеральный свидетель веса не несёт — в таблицу не входит (см. check.lisp)
        (unless (or (member name dead) (member root dead) (null f) (null c))
          (multiple-value-bind (wp wm) (fc->evidence f c)
            (let ((cell (assoc root tbl)))
              (if (null cell)
                  (push (list root name wp wm grade) tbl)
                  (when (> (+ wp wm) (+ (third cell) (fourth cell)))
                    (setf (cdr cell) (list name wp wm grade)))))))))))

(defun red-claim (form store dead)
  ;; R-CLAIM: ⊕ есть СЛОЖЕНИЕ ВЕСОВ (АЛГЕБРА, теорема 1) — здесь видно буквально.
  ;; 🔴 Отозванный свидетель ВЫПАДАЕТ ИЗ ОСНОВАНИЯ целиком: ни веса, ни степени.
  (let* ((id (second form))
         (declared (let ((g (kw form :grade))) (and g (parse-grade g))))
         (all-spec (let ((x (clause form "from-all"))) (if (eq x :нет) nil (or x '(:все)))))
         (dropped '()) (short-roots nil)
         (decl-from (if all-spec
                        (multiple-value-bind (in out)
                            (select-from-corpus (if (eq (first all-spec) :все) '() all-spec) dead)
                          (setf dropped out) in)
                        (clause* form "from")))
         (need-roots (let ((x (clause form "requiring-roots"))) (if (eq x :нет) nil (first x))))
         (srch (clause* form "searched"))
         ;; мёртв сам свидетель ИЛИ его корень — отзыв предка снимает потомков
         (live (remove-if (lambda (p)
                            (let ((v (gethash p store)))
                              (or (member p dead)
                                  (and (jv-p v) (member (jv-origin v) dead)))))
                          decl-from))
         (seen '()) (w+ 0.0) (w- 0.0) (cover '()) (leaned '())
         (roots '()) (collapsed '())
         (grade (if (null live) (g-bot) (g-top))))
    ;; ── 🔴 СВЁРТКА ПО КОРНЯМ, А НЕ ПО ДОКУМЕНТАМ ────────────────────────────────
    ;; Два свода, восходящих к одному источнику, есть ОДНО свидетельство. Группа
    ;; сворачивается в одного представителя — с наибольшим весом: лучше сохранившаяся
    ;; копия и есть твой лучший доступ к оригиналу. Остальные поглощаются, но НЕ молча:
    ;; поглощённые записываются и печатаются (урок хода 2 — потреблено ≠ показано).
    (let ((groups '()) (support '()))          ; корень → список (имя . значение)
      (dolist (p live)
        (unless (member p seen)
          (push p seen)
          (let ((v (gethash p store)))
            (cond
              ;; 🔴 ВЫВЕДЕННОЕ УТВЕРЖДЕНИЕ НЕСЁТ МНОЖЕСТВО КОРНЕЙ, А НЕ ОДИН.
              ;; Прежде у него `origin` был `nil`, и свёртка группировала по нему: два
              ;; НЕЗАВИСИМЫХ вывода попадали в группу «nil», и один поглощался как копия
              ;; другого (0.540 вместо 0.675). `nil` в роли корня — это молчание,
              ;; притворившееся источником. Поддержка вывода есть ОБЪЕДИНЕНИЕ поддержек
              ;; его посылок; степень берётся его собственная — иначе объявленная ниже
              ;; выведенной (T-ASCRIBE) поднялась бы обратно к своему корню, то есть отмылась.
              ((and (jv-p v) (jv-base v))
               (dolist (r (jv-roots v)) (pushnew r support))
               (setf grade (g-meet grade (jv-grade v))))
              ((jv-p v)
               (when (jv-origin v) (pushnew (jv-origin v) support))
               (let ((cell (assoc (jv-origin v) groups)))
                 (if cell (push (cons p v) (cdr cell))
                     (push (list (jv-origin v) (cons p v)) groups))))
              ((sv-p v)
               (push (list p (sv-where v) (sv-why v)) leaned)
               (setf grade (g-meet grade (g-bot))))))))
      (dolist (grp (nreverse groups))
        (let* ((root (first grp))
               (members (reverse (rest grp)))
               (best (first (sort (copy-list members) #'>
                                  :key (lambda (m) (+ (jv-w+ (cdr m)) (jv-w- (cdr m))))))))
          ;; расхождение внутри корня — не копии, а противоречивая передача. Не прятать.
          ;; 🔴 И РАЗЛИЧАТЬ ДВА СЛУЧАЯ. Внутри одного корпуса разошлись два свода — это работа
          ;; для текстолога. Разошлись своды одного корня, пришедшие из РАЗНЫХ модулей, — это
          ;; спорная передача между корпусами: кто-то из двоих донёс источник неверно, и
          ;; вопрос уже не к спискам, а к самим корпусам. Свести их в одну строку значило бы
          ;; спрятать более тяжёлый случай под менее тяжёлым.
          (let ((freqs (mapcar (lambda (m) (nth-value 0 (jv-fc (cdr m)))) members))
                (mods  (remove-duplicates (mapcar (lambda (m) (corpus-module (car m))) members)
                                          :test #'equal)))
            (when (and (cdr members)
                       (> (- (reduce #'max freqs) (reduce #'min freqs)) 0.1))
              (push (if (cdr mods)
                        (list root :спорная-передача (mapcar #'car members)
                              (mapcar (lambda (m) (or m :здешний)) mods))
                        (list root :расхождение (mapcar #'car members)))
                    collapsed)))
          (dolist (m members)
            (unless (eq m best) (push (list root (car m) (car best)) collapsed)))
          ;; масса здесь БОЛЬШЕ НЕ КОПИТСЯ: она считается ниже по членству в поддержке
          (setf grade (g-meet grade (jv-grade (cdr best))))))
      ;; 🔴 МАССА ВЕРЫ — ПО ЧЛЕНСТВУ В ПОДДЕРЖКЕ (её `massUpTo`). Каждый корень поддержки
      ;; вносит вес РОВНО ОДИН раз, кем бы и сколько раз на него ни сослались: отсюда даром
      ;; и `∪-idem` (общий предок не удваивается), и `derived≡direct` (вывод не теряет
      ;; независимого свидетельства), и `∪-comm` (порядок посылок не значит ничего).
      (let ((tbl (root-best *corpus* dead)))
        (dolist (r support)
          (let ((cell (assoc r tbl)))
            (when cell (incf w+ (third cell)) (incf w- (fourth cell))))))
      (setf roots (reverse support)))
    ;; ОБЗОРНОЕ молчание: степени не трогает, но охват обязан остаться при утверждении
    (dolist (sname srch)
      (let ((v (gethash sname store)))
        (when (sv-p v) (push (list sname (sv-where v) (sv-why v)) cover))))
    ;; 🔴 Требование к МНОЖЕСТВУ: не хватило различных корней ⇒ дно, как пустая база.
    ;; Одно свидетельство, даже строгое, не есть подтверждение из двух независимых источников.
    (let ((n-roots (length roots)))
      (when (and need-roots (< n-roots need-roots))
        (setf short-roots (list need-roots n-roots)
              grade (g-bot))))
    (store-put store id
               (jv (if (and declared (g<= declared grade)) declared grade)
                   w+ w- (nreverse seen) (nreverse cover) (nreverse leaned)
                   nil roots (nreverse collapsed)
                   dropped short-roots))))

(defun red-action (form store)
  (store-put store (second form)
             (av (kw form :reversibility 'reversible)
                 (let ((r (kw form :requires))) (and (consp r) (third r)))
                 (kw form :else) (kw form :compensated-by)
                 (let ((g (kw form :needs-grade))) (and g (parse-grade g)))
                 ;; 🔴 Право НЕ приходит из объявления: там стоит лишь требование «кто вправе».
                 ;; Склад получает его позже, формой `permit` — то есть в момент замера,
                 ;; а не в момент, когда писалась линейка.
                 nil)))

;;; ── R-PERMIT: предъявленное право ложится на действие ───────────────────────
;;; 🔴 Право не трогает ни веру, ни степень: это ТРЕТЬЯ ОСЬ. Меняется единственное —
;;; появляется то, что `revoke` сможет отозвать, а вердикт — предъявить читателю.
;;; Формат тот же, что раньше приходил из объявления действия: (цитата кто адрес), —
;;; поэтому `revoke` и четвёртый статус `unauthorized` работают без единой правки.
(defun red-permit (form store)
  (let* ((a (second form))
         (av* (gethash a store)))
    (if (av-p av*)
        (store-put store a
                   (av (av-rev av*) (av-thr av*) (av-else av*) (av-comp av*) (av-need av*)
                       (list (kw form :quote) (kw form :who) (kw form :at))))
        store)))

(defun red-do (form store ledger &optional done)
  ;; R-DO-PASS / R-DO-FOLD — единственное место, где программа обращается наружу.
  ;;
  ;; 🔴 ПРАВИЛО СВЕЖЕГО ОТЗЫВА (совет Невис, §2 её записки). Отзыв может ПОДНЯТЬ веру —
  ;; зеркало теоремы 5: отозвать оппонента значит укрепить веру. Отсюда атака: вера ниже
  ;; порога → отозвать неудобного свидетеля → вера прыгнула → совершить необратимое.
  ;; Запрещать отзыв нельзя (сломается добросовестный случай), поэтому запрет ставится
  ;; не на отзыв, а на использование его КАК ТОПЛИВА:
  ;;     гейт необратимого берёт ХУДШЕЕ из «до отзывов» и «после».
  ;; Счётом на атаке: 0.412 → 0.665, минимум 0.412 — гейт держит.
  ;; Счётом на честном отзыве: 0.782 → 0.665, минимум 0.665 — то есть послеотзывная правда.
  ;; ⚠️ Авторство в языке не выражено; «тот же автор в том же сеансе» читается консервативно
  ;; как «любой отзыв в этой же программе». Уточнение — когда появятся авторы.
  (let* ((an (second form)) (jn (third form))
         (a (gethash an store)) (j (gethash jn store))
         (b-now (and (jv-p j) (jv-belief j)))
         (rev (and (av-p a) (av-rev a)))
         (irreversible (and rev (string-equal (string rev) "irreversible")))
         (b-pre (when (and irreversible done)
                  (let ((v (gethash jn (replay done '() t))))
                    (and (jv-p v) (jv-belief v)))))
         (b (if (and b-now b-pre) (min b-now b-pre) b-now))
         (thr (and (av-p a) (av-thr a))))
    (cond
      ((null thr)
       (call-handler :performed an jn b nil)
       (values store (cons (list :performed an jn b nil) ledger)))
      ((and b (>= b thr))
       (call-handler :performed an jn b thr)
       (values store (cons (list :performed an jn b thr) ledger)))
      (t (let ((fid (intern (format nil "~a/СВЁРТОК" an))))
           (values (store-put store fid (fv an jn b thr (and b (- thr b))))
                   (cons (list :folded an jn b thr (and b (- thr b))
                               ;; если связала ДООТЗЫВНАЯ вера — сказать об этом прямо
                               (if (and b-pre b-now (< b-pre b-now))
                                   :свежий-отзыв-не-в-счёт
                                   (and (av-p a) (av-else a))))
                         ledger)))))))

;;; ── ПЕРЕСЧЁТ: прогон набора объявлений при заданном множестве мёртвых ────────
;;; Отзыв не «откатывает» — он ПЕРЕСЧИТЫВАЕТ. Конфлюэнтность гарантирует, что
;;; результат определён однозначно, а не зависит от того, как мы шли.
(defun replay (forms dead &optional ignore-retracts)
  "Прогнать объявления при мёртвом множестве DEAD. → склад. Действия не совершаются.
   IGNORE-RETRACTS — прогон «как если бы отзывов в этой программе не было»; нужен гейту
   необратимого, чтобы свежий отзыв нельзя было использовать как топливо (см. red-do)."
  (let* ((*corpus* (or *corpus* (collect-corpus forms)))
         (store (prefill-store *corpus* dead)) (d dead))
    (dolist (form forms store)
      (let ((h (head-of form)))
        (cond ((string= h "horizon") (chk-horizon form))
              ((string= h "lattice") (chk-lattice form))
              ((string= h "import")  (register-import form))
              ;; 🔴 Отзыв КОРНЯ убивает всех потомков сам собой: свидетель с мёртвым корнем
              ;; выпадает из основания без отдельного правила. Побочная выгода носителя.
              ((string= h "retract") (unless ignore-retracts (pushnew (second form) d)))
              ((string= h "revoke") nil)   ; право основания не трогает — см. step-cfg
              ;; 🔴 permit при перепрогоне ВОССТАНАВЛИВАЕТСЯ: перепрогон пересчитывает веру
              ;; после отзыва свидетеля, и потерять здесь предъявленное право значило бы
              ;; превратить осиротение в неправомерность — разные статусы, разные последствия.
              ((string= h "permit") (setf store (red-permit form store)))
              ((string= h "witness") (setf store (red-witness form store)))
              ((string= h "ask")     (setf store (red-ask form store)))
              ((string= h "claim")   (setf store (red-claim form store d)))
              ((string= h "action")  (setf store (red-action form store))))))))

;; 🔴 ПОЛНОТА ДИСПЕТЧЕРОВ проверяется при загрузке (см. common.lisp). `replay` сознательно
;; не совершает действий — пересчёт отвечает на вопрос «каким был бы склад», а не переигрывает
;; историю; поэтому "do" у него в пропущенных, и это объявлено, а не забыто.
(assert-covers "replay" '("lattice" "horizon" "import" "retract" "revoke" "permit" "witness" "ask"
                          "claim" "action")
               :skip '("do" "rule"))

;;; ── МОСТ НАРУЖУ ─────────────────────────────────────────────────────────────
;;; 🔴 МОСТ ОДНОСТОРОННИЙ, И ЭТО НЕСУЩЕЕ РЕШЕНИЕ. Обработчик зовётся ПОСЛЕ того, как гейт
;;; принял решение, и его возврат НИ НА ЧТО не влияет: ни на склад, ни на журнал, ни на
;;; последующие шаги. Иначе внешний мир мог бы задним числом менять провенанс — «действие
;;; удалось, значит основание было хорошим», а это ровно отмывание через результат.
;;; Ядро остаётся без эффектов: без обработчика `perform` по-прежнему только пишет в журнал.
(defvar *action-handler* nil
  "Функция (вид имя основание вера порог) → игнорируется. nil — чистый прогон.")

(defun call-handler (kind action basis belief threshold)
  (when *action-handler*
    (ignore-errors                      ; сбой внешнего мира не ломает вывод и не меняет склад
      (funcall *action-handler* kind action basis belief threshold))
    nil))                               ; возврат отброшен НАМЕРЕННО, см. выше

(defun orphans (ledger store)
  "Действия, чьё основание перестало держать порог. → список записей :orphaned."
  (let ((out '()))
    (dolist (e (reverse ledger) (nreverse out))
      (when (eq (first e) :performed)
        (destructuring-bind (kind a j b thr) e
          (declare (ignore kind b))
          (let* ((nj (gethash j store)) (nb (and (jv-p nj) (jv-belief nj))))
            (when (and thr nb (< nb thr))
              (let* ((av* (gethash a store))
                     (comp (and (av-p av*) (av-comp av*)))
                     (rev (and (av-p av*) (av-rev av*))))
                (push (list :orphaned a j nb thr comp rev) out)
                ;; 🔴 КОМПЕНСАЦИЯ — ДЕЙСТВИЕ СО СВОИМ ГЕЙТОМ, а не пометка и не отмена.
                ;; Необратимое отменить нельзя; возместимое — можно совершить ВТОРОЕ действие,
                ;; и оно проходит СВОЙ порог, а не порог того, что рухнуло. Иначе возмещение
                ;; наследовало бы чужое условие и совершалось бы «за компанию»: у него другая
                ;; цена ошибки и другое основание судить.
                ;; Возмещение может и НЕ пройти — тогда это отдельная запись, а не тишина:
                ;; «возместить собирались, да не хватило» есть знание, и его нельзя терять.
                (let* ((cav (and comp (gethash comp store)))
                       (cthr (and (av-p cav) (av-thr cav)))
                       (roots (and (jv-p nj) (jv-roots nj))))
                  (cond
                    ((and comp rev (string-equal (string rev) "compensable"))
                     (if (and cthr nb (< nb cthr))
                         (push (list :compensation-folded comp j nb cthr (- cthr nb) a) out)
                         (push (list :compensating comp j nb (or cthr thr) a roots) out)))
                    ((and rev (string-equal (string rev) "irreversible"))
                     (push (list :irreparable a j nb thr) out))))))))))))

;;; ── шаг ─────────────────────────────────────────────────────────────────────
(defun step-cfg (c)
  (let* ((form (first (cfg-rest c))) (rest (rest (cfg-rest c)))
         (h (head-of form))
         (store (cfg-store c)) (pend (cfg-pending c)) (ledger (cfg-ledger c))
         (dead (cfg-dead c)) (done (append (cfg-done c) (list form))))
    (macrolet ((к (st &optional (pd 'pend) (lg 'ledger) (dd 'dead))
                 `(cfg ,st ,pd ,lg ,dd done rest)))
      (cond
        ((string= h "horizon") (chk-horizon form) (к store))
        ((string= h "lattice") (chk-lattice form) (к store))
        ;; импорт склада не меняет: он объявляет ШКАЛУ, а не свидетельство.
        ((string= h "import")  (register-import form) (к store))
        ((string= h "witness") (к (red-witness form store)))
        ((string= h "ask") (к (red-ask form store) (cons (second form) pend)))
        ((string= h "claim")
         (let* ((from (clause* form "from")) (srch (clause* form "searched"))
                (used (append from srch)))
           (к (red-claim form store dead)
              (remove-if (lambda (s) (member s used)) pend))))
        ((string= h "action") (к (red-action form store)))
        ((string= h "permit") (к (red-permit form store)))
        ((string= h "do")
         (multiple-value-bind (st lg) (red-do form store ledger (cfg-done c))
           (к st pend lg)))
        ;; ── 🔴 R-REVOKE: ЧЕТВЁРТЫЙ СТАТУС ─────────────────────────────────
        ;; Отзыв разрешения НЕ трогает склад: основание цело, вера прежняя, свидетели живы.
        ;; Меняется единственное — ПРАВО. Совершённое действие, чьё разрешение отозвано,
        ;; становится НЕПРАВОМЕРНЫМ, и это не осиротение: там рухнуло основание, здесь —
        ;; основание стоит, а стоять на нём было нельзя. Числами их не различить.
        ((string= h "revoke")
         (let* ((who (second form))
                (плохие '()))
           (dolist (e ledger)
             (when (eq (first e) :performed)
               (let* ((av* (gethash (second e) store))
                      (perm (and (av-p av*) (av-perm av*))))
                 (when (and perm (eq (second perm) who))
                   (push (list :unauthorized (second e) (third e) (fourth e) (fifth e)
                               (kw form :reason) (first perm))
                         плохие)))))
           (к store pend
              (append плохие
                      (cons (list :revoked who (kw form :reason) nil nil) ledger)))))
        ;; ── R-RETRACT ──────────────────────────────────────────────────────
        ((string= h "retract")
         (let* ((w (second form))
                (dead* (adjoin w dead))
                (store* (replay done dead*))          ; ПЕРЕСЧЁТ, не откат
                (orph (orphans ledger store*))
                (_ (dolist (e orph)
                     (when (eq (first e) :compensating)
                       (call-handler :compensating (second e) (third e)
                                     (fourth e) (fifth e)))))
                ;; 🔴 Журнал ДОПИСЫВАЕТСЯ. Отозвать отзыв нельзя: история не стирается.
                (ledger* (append (reverse orph)
                                 (cons (list :retracted w (kw form :reason) nil nil)
                                       ledger))))
           (declare (ignore _))
           (к store* pend ledger* dead*)))
        (t (к store))))))

;;; ── прогон ──────────────────────────────────────────────────────────────────
(assert-covers "step-cfg" '("lattice" "horizon" "import" "witness" "ask" "claim" "action" "do"
                            "retract" "revoke" "permit")
               :skip '("rule"))

;;; ── НОСИТЕЛЬ ────────────────────────────────────────────────────────────────
;;; 🔴 ПОЧЕМУ ОН ЗДЕСЬ ПАРАМЕТР, А НЕ ПОЛЕ (совет Невис, §3 её записки).
;;; Если носитель — поле записи, «нейтральность» держится на дисциплине автора: сегодня
;;; никто метку не читает, завтра прочтёт. Если носитель — ПАРАМЕТР, которого ни одна форма
;;; языка не принимает, нейтральность выпадает свободной теоремой: её нельзя нарушить, не
;;; расширив язык. Ровно как коммутативность выпала из переноса в (ℝ≥0², +).
;;;
;;; И ровно поэтому носитель надо было СНАЧАЛА ЗАВЕСТИ: пока его нет вовсе, «нейтральность
;;; к носителю» истинна ПУСТО, а пустая истина — не черта языка.
;;;
;;; ЧТО ИМЕННО УТВЕРЖДАЕТСЯ (инстанцирование теоремы 5 «Свидетеля» в нашей семантике):
;;;   Σ (склад = континуант) НЕ ЗАВИСИТ от носителя — прогоны на разных носителях дают
;;;   побайтово равное состояние;
;;;   Λ (журнал = история) носитель ЗАПИСЫВАЕТ — иначе мы потеряли бы, где это происходило.
;;; Состояние нейтрально, история помнит. Это не компромисс, а разделение назначений
;;; (то же, что и в §4.2: склад воспроизводим, журнал историчен).
(defun run-nolang (forms &key carrier)
  "→ (values склад журнал шагов непотреблённые-молчания отозванные).
   CARRIER — метка носителя. Ни одна форма языка её не принимает: попасть в вычисление
   она может только через расширение языка, а не через программу.
   Решётка живёт ровно один прогон — прелюдия не пачкается."
  (with-prelude
   (let ((*errs* '()))
    (let* ((*corpus* (collect-corpus forms))
           (c (cfg (prefill-store *corpus* '()) '()
                  ;; носитель ложится в ЖУРНАЛ первой записью — и больше нигде не появляется
                  (if carrier (list (list :ran-on carrier nil)) '())
                  '() '() forms))
           (n 0))
      (loop until (cfg-final-p c) do (setf c (step-cfg c)) (incf n))
      (values (cfg-store c) (reverse (cfg-ledger c)) n (cfg-pending c) (cfg-dead c))))))

(defun grade-at-runtime (forms id)
  (let ((v (gethash id (run-nolang forms)))) (and (jv-p v) (jv-grade v))))

(defun belief-at-runtime (forms id)
  (let ((v (gethash id (run-nolang forms)))) (and (jv-p v) (jv-belief v))))

(defun store-signature (store)
  "Отпечаток склада, независимый от порядка."
  (let ((out '()))
    (maphash (lambda (k v)
               (when (jv-p v)
                 (push (list k (jv-grade v) (round (* 1e6 (jv-w+ v))) (round (* 1e6 (jv-w- v))))
                       out)))
             store)
    (sort out #'string< :key (lambda (x) (string (first x))))))

;;; ── ПЕЧАТЬ ────────────────────────────────────────────────────────────────────
;;; 🔴 Печать — ЧАСТЬ СЕМАНТИКИ, а не удобство. Обзорное молчание степени не трогает;
;;; единственное, ради чего оно вообще существует, — чтобы читатель видел ГРАНИЦУ ЗНАНИЯ.
;;; Значит утверждение, напечатанное без охвата, нарушает замысел так же, как немое молчание.
;;; Поэтому отдельного «печатать без охвата» способа НЕТ: show-claim всегда печатает всё,
;;; а show-run — единственный вход для показа прогона.
(defun show-claim (id j)
  "Утверждение целиком: степень, вера, основание, ОПОРА-НА-МОЛЧАНИЕ и ОХВАТ."
  (multiple-value-bind (f c) (jv-fc j)
    (format t "~&  ~a : [~a]  f=~,3f c=~,3f b=~,3f~%" id (g-ru (jv-grade j)) f c (* f c)))
  (when (jv-base j)
    (format t "      на чём стоит: ~{~a~^, ~}~%" (jv-base j)))
  ;; опора на молчание — почему степень на дне, сказано словами, а не выведено читателем из ⊥
  (dolist (l (jv-leaned j))
    (format t "      🔴 ОПИРАЕТСЯ НА МОЛЧАНИЕ ~a: искали в ~{~a~^, ~} — ~a~%"
            (first l) (second l) (third l))
    (format t "         (аргумент от молчания: степень поэтому на дне)~%"))
  ;; 🔴 ОТСЕВ КВАНТОРА — виден, и особо помечен тот, чьё исключение ПОДНЯЛО веру.
  ;; Критерий не выдуман: теорема 5 говорит, что свидетель роняет веру ⟺ его частота ниже
  ;; уже накопленной. Значит отсеянный с частотой НИЖЕ полученной веры — ровно тот, кого
  ;; исключение сделало сильнее. Это и есть измеримый черри-пикинг.
  (when (jv-dropped j)
    (let* ((b (jv-belief j))
           (опасные (remove-if-not (lambda (d) (< (third d) b)) (jv-dropped j))))
      (format t "      ⊗ отсеяно квантором: ~a~{ ~a~}~%"
              (length (jv-dropped j)) (mapcar #'first (jv-dropped j)))
      (when опасные
        (format t "      🔴 из них ~a с частотой НИЖЕ полученной веры (~,3f): ~{~a~^, ~}~%~
                   ~9Tих исключение ПОДНЯЛО веру — проверьте, отбор ли это или черри-пикинг~%"
                (length опасные) b (mapcar #'first опасные)))))
  (when (jv-short-roots j)
    (format t "      ⊘ НЕДОБОР КОРНЕЙ: требовалось ~a различных, есть ~a — степень на дне~%"
            (first (jv-short-roots j)) (second (jv-short-roots j))))
  ;; 🔴 Поглощённые копии — видны. Свёртка по корням убирает ложное усиление, но если
  ;; сделать это молча, читатель не поймёт, почему два свидетеля дали вес одного.
  ;; Тот же закон, что с охватом: поглощено ≠ показано.
  (dolist (cl (jv-collapsed j))
    (case (second cl)
      (:расхождение
       (format t "      ⚠ РАСХОЖДЕНИЕ в корне ~a: ~{~a~^, ~} говорят по-разному.~%~
                    ~9Tэто не копии одного свидетельства, а спорная передача — ~
                    разберите вручную.~%" (first cl) (third cl)))
      (:спорная-передача
       (format t "      ⚠ СПОРНАЯ ПЕРЕДАЧА корня ~a МЕЖДУ КОРПУСАМИ (~{~a~^, ~}): ~
                    ~{~a~^, ~} говорят по-разному.~%~
                    ~9Tодин и тот же источник донесён двумя корпусами неодинаково — ~
                    вопрос к корпусам, не к спискам.~%"
               (first cl) (fourth cl) (third cl)))
      (t
       (format t "      ⊙ ~a поглощён как копия корня ~a (учтён ~a — вес больше)~%"
               (second cl) (first cl) (third cl)))))
  (when (and (jv-roots j) (cdr (jv-roots j)))
    (format t "      корней: ~a (~{~a~^, ~}) — вес считан по корням, не по документам~%"
            (length (jv-roots j)) (jv-roots j)))
  ;; охват — граница знания, ради которой обзорная роль и заведена
  (dolist (cv (jv-cover j))
    (format t "      ⌕ охват ~a: искали в ~{~a~^, ~} — ~a~%"
            (first cv) (second cv) (third cv)))
  ;; «охват не заявлен» — только для ВЫВЕДЕННОГО утверждения. У свидетеля (нет основания)
  ;; охвата быть не может: он первичный источник, а не вывод из источников.
  (when (and (jv-base j) (null (jv-cover j)) (null (jv-leaned j)))
    (format t "      ⌕ охват не заявлен — где НЕ искали, не сказано~%")))

(defun show-run (store ledger &key rejected)
  "Единственный вход для показа прогона: утверждения с охватом, затем журнал.
   🔴 REJECTED — программа отвергнута проверяющим. Тогда журнал печатается ПОД ДРУГИМ
   заголовком, и это не косметика (находка Невис, 29.07: она прочла хвост вывода и на
   полминуты решила, что закупка всё же совершилась).
   Печать журнала после отказа читается как «всё равно произошло» — то есть нарушает в
   ПЕЧАТИ ровно то различение, которое язык проводит в семантике: отказ гейта есть ИСХОД
   программы, а отклонение проверяющим значит, что программы НЕ БЫЛО. Всё, что печатается
   после «ОТКЛОНЕНО», есть рассказ о том, чего не случилось, — и заголовок обязан это сказать,
   иначе вывод сам себе противоречит на вид."
  (let ((claims '()))
    (maphash (lambda (k v) (when (jv-p v) (push (cons k v) claims))) store)
    (setf claims (sort claims #'string< :key (lambda (x) (string (car x)))))
    (when claims
      (format t "~&── УТВЕРЖДЕНИЯ~:[~; (программа отклонена — показано, ЧТО БЫЛО БЫ)~] ──~%"
              rejected))
    (dolist (kv claims) (show-claim (car kv) (cdr kv))))
  (when ledger
    (if rejected
        (format t "~&── ЖУРНАЛ: ЧТО БЫЛО БЫ ──~%~
                   🔴 Программа ОТКЛОНЕНА проверяющим — ниже не протокол исполнения, а ЦЕНА:~%~
                   ~3Tчто произошло бы, будь она собрана. Ничего из этого не случилось.~%")
        (format t "~&── ЖУРНАЛ ──~%")))
  (show-ledger ledger))

(defun show-ledger (ledger)
  (dolist (e ledger)
    (destructuring-bind (kind a j &optional b thr lack els) e
      (case kind
        (:performed (format t "~&  ✓ совершено ~a на основании ~a~@[ — вера ~,3f ≥ порог ~,3f~]~%"
                            a j (and thr b) thr))
        (:folded (format t "~&  ⊘ свёрнуто ~a на основании ~a: вера ~,3f < порог ~,3f, ~
                              не хватило ~,3f → ~a~%" a j b thr lack els))
        (:retracted (format t "~&  ✂ ОТОЗВАН свидетель ~a: ~a~%" a j))
        (:revoked (format t "~&  ⛔ ОТОЗВАНО РАЗРЕШЕНИЕ ~a: ~a~%" a j))
        ;; 🔴 Четвёртый статус. Ни «осиротело», ни «непоправимо»: основание ЦЕЛО.
        (:unauthorized
         (format t "~&  ⛔ НЕПРАВОМЕРНО: ~a совершено на основании ~a — основание ЦЕЛО ~
                    (вера ~,3f ≥ порог ~,3f),~%~5Tно разрешение отозвано: ~a~%~
                    ~5Tцитата, на которую ссылались: «~a»~%~
                    ~5TЭто НЕ осиротение: там рухнуло основание, здесь — право.~%"
                 a j (or b 0) (or thr 0) lack els))
        (:ran-on (format t "~&  ⌂ прогон на носителе ~a (склад от носителя НЕ зависит)~%" a))
        ;; 🔴 У возмещения СВОЙ порог и СВОИ корни — оно отдельное действие, а не пометка
        ;; на чужом. `lack` здесь несёт имя возмещаемого действия, `els` — корни основания.
        (:compensating
         (format t "~&  ↩ ВОЗМЕЩЕНИЕ ~a совершено на основании ~a: вера ~,3f ≥ его порог ~,3f~%~
                    ~5Tвозмещает ~a~@[ · корни: ~{~a~^, ~}~]~%" a j b thr lack els))
        (:compensation-folded
         (format t "~&  ⊘ ВОЗМЕЩЕНИЕ ~a НЕ СОВЕРШЕНО: вера ~,3f < его собственный порог ~,3f, ~
                    не хватило ~,3f~%~5Tдействие ~a осталось без возмещения — и это ~
                    записано, а не пропущено~%" a b thr lack els))
        (:irreparable
         (format t "~&  ✖ НЕПОПРАВИМО: ~a на основании ~a — вера ~,3f < порог ~,3f,~%~
                    ~5Tа действие необратимо. Возместить нечем. ВОТ ЗАЧЕМ ГЕЙТ.~%" a j b thr))
        (:orphaned
         (format t "~&  ⚠ ОСИРОТЕЛО ~a: основание ~a пересмотрено, вера ~,3f < порог ~,3f~%    ~
                      ~a~%" a j b thr
                 (cond ((eq els 'irreversible)
                        "действие НЕОБРАТИМО — компенсация невозможна. Вот зачем гейт.")
                       (lack (format nil "требуется компенсация: ~a" lack))
                       (t "класс действия не требует компенсации"))))))))
