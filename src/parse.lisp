;;;; nolang src — parse. ЛЕКСЕР И РАЗБОРЩИК собственного синтаксиса.
;;;; Text → формы, которые ест src/check.lisp. Замыкает цепь: текст → разбор → проверка.
;;;;
;;;; 🔴 ЗАЧЕМ ЯЗЫКУ СВОЯ ГРАММАТИКА (ответ на «не диалект ли лиспа ради диалекта»):
;;;; ЧТО МОЖНО СДЕЛАТЬ НЕВЫРАЗИМЫМ В ГРАММАТИКЕ — НЕ ОСТАВЛЯТЬ ТИПАМ.
;;;; Ошибка разбора дешевле и понятнее ошибки типизации: она приходит раньше, указывает
;;;; в одно место и не требует понимать вывод. Пять состояний уходят с типового уровня
;;;; на синтаксический — их нельзя ЗАПИСАТЬ, а не только нельзя оттипизировать:
;;;;   1. необратимое действие без гейта       — гейт в самой продукции, не опция
;;;;   2. гейт на чём-либо кроме массы веры    — слово `belief` вшито в продукцию
;;;;   3. compensable без компенсации          — компенсация в продукции
;;;;   4. утверждение с неявной пустой базой   — писать `from nothing` явно
;;;;   5. молчание без «где искал» и «почему»  — оба обязательны
;;;; Всё остальное (отмывание, линейность, свёртка гейта) грамматике недоступно и
;;;; законно остаётся типам. Грамматика окупает себя пятью пунктами, а не вкусом.

(load (merge-pathnames "check.lisp" *load-pathname*))
(load (merge-pathnames "theta.lisp" *load-pathname*))

;; 🔴 Один вид диагностики на оба слоя (аудит 28.07, находка 3): разбор и проверка ругались
;; по-разному, и читателю приходилось держать в голове два формата. Теперь оба идут через
;; say-error из common.lisp: род · [код] · где · суть.
(define-condition nol-syntax-error (error)
  ((msg :initarg :msg :reader nol-msg) (line :initarg :line :initform 0 :reader nol-line))
  (:report (lambda (c s)
             (say-error "ОШИБКА" :syntax (format nil "строка ~a" (nol-line c))
                        (nol-msg c) s))))

(defvar *toks*) (defvar *line*)

(defun serr (fmt &rest args)
  (error 'nol-syntax-error :line *line* :msg (apply #'format nil fmt args)))

;;; ── лексер ──────────────────────────────────────────────────────────────────
(defstruct (tok (:constructor tok (kind val line))) kind val line)  ; :ident :num :str :punct

(defun ident-char-p (ch)
  (or (alphanumericp ch) (find ch "-_?!*") (> (char-code ch) 127)))

(defun lex (src)
  (let ((i 0) (n (length src)) (line 1) (out '()))
    (loop while (< i n) do
      (let ((ch (char src i)))
        (cond
          ((char= ch #\Newline) (incf line) (incf i))
          ((member ch '(#\Space #\Tab #\Return)) (incf i))
          ((and (char= ch #\;))                                   ; комментарий до конца строки
           (loop while (and (< i n) (char/= (char src i) #\Newline)) do (incf i)))
          ((char= ch #\")                                          ; строка
           (let ((j (1+ i)))
             (loop while (and (< j n) (char/= (char src j) #\")) do (incf j))
             (when (>= j n) (let ((*line* line)) (serr "незакрытая строка")))
             (push (tok :str (subseq src (1+ i) j) line) out)
             (setf i (1+ j))))
          ((digit-char-p ch)                                       ; число
           (let ((j i))
             (loop while (and (< j n) (or (digit-char-p (char src j)) (char= (char src j) #\.)))
                   do (incf j))
             (push (tok :num (let ((*read-eval* nil))
                               (read-from-string (subseq src i j)))
                        line) out)
             (setf i j)))
          ((and (char= ch #\>) (< (1+ i) n) (char= (char src (1+ i)) #\=))
           (push (tok :punct ">=" line) out) (incf i 2))
          ;; 🔴 «->» обязана стоять ДО разбора имени: дефис — знак имени (ident-char-p),
          ;; и без этой ветви «строго -> строгое» распалось бы на имя «-» и неожиданный «>».
          ((and (char= ch #\-) (< (1+ i) n) (char= (char src (1+ i)) #\>))
           (push (tok :punct "->" line) out) (incf i 2))
          ((find ch ":=<,*()")
           (push (tok :punct (string ch) line) out) (incf i))
          ((ident-char-p ch)
           (let ((j i))
             (loop while (and (< j n) (ident-char-p (char src j))) do (incf j))
             (push (tok :ident (subseq src i j) line) out)
             (setf i j)))
          (t (let ((*line* line)) (serr "неожиданный знак «~a»" ch))))))
    (nreverse out)))

;;; ── навигация ───────────────────────────────────────────────────────────────
(defun peek () (first *toks*))
(defun peek-kind () (and (peek) (tok-kind (peek))))
(defun advance ()
  (let ((tk (pop *toks*))) (when tk (setf *line* (tok-line tk))) tk))

(defun word? (w)
  (let ((tk (peek)))
    (and tk (eq (tok-kind tk) :ident) (string-equal (tok-val tk) w))))

(defun punct? (p)
  (let ((tk (peek)))
    (and tk (eq (tok-kind tk) :punct) (string= (tok-val tk) p))))

(defun eat-word (w &optional hint)
  (unless (word? w)
    (serr "ожидалось «~a»~@[, ~a~]; встречено ~a" w hint
          (if (peek) (format nil "«~a»" (tok-val (peek))) "конец текста")))
  (tok-val (advance)))

(defun eat-punct (p)
  (unless (punct? p)
    (serr "ожидалось «~a»; встречено ~a" p
          (if (peek) (format nil "«~a»" (tok-val (peek))) "конец текста")))
  (tok-val (advance)))

(defun eat-ident (what)
  (unless (eq (peek-kind) :ident)
    (serr "ожидалось имя (~a); встречено ~a" what
          (if (peek) (format nil "«~a»" (tok-val (peek))) "конец текста")))
  (intern (string-upcase (tok-val (advance)))))

(defun eat-num (what)
  (unless (eq (peek-kind) :num) (serr "ожидалось число (~a)" what))
  (tok-val (advance)))

(defun eat-str (what)
  (unless (eq (peek-kind) :str) (serr "ожидалась строка (~a)" what))
  (tok-val (advance)))

(defun eat-grade (what)
  "Степень: имя (линейная решётка) ИЛИ кортеж (имя, имя, …) — степень произведения."
  (if (punct? "(")
      (progn (advance)
             (let ((parts (list (eat-ident what))))
               (loop while (punct? ",") do (advance) (push (eat-ident what) parts))
               (eat-punct ")")
               (when (< (length parts) 2)
                 (serr "кортеж степени из одного имени — это просто имя, скобки лишние"))
               (nreverse parts)))
      (eat-ident what)))

(defun ident-list (what)
  "имя (, имя)*"
  (let ((out (list (eat-ident what))))
    (loop while (punct? ",") do (advance) (push (eat-ident what) out))
    (nreverse out)))

;;; ── продукции ───────────────────────────────────────────────────────────────
(defun p-lattice ()
  ;; lattice ИМЯ = дно < … < верх              ← линейная
  ;; lattice ИМЯ = часть * часть [* …]         ← ПРОИЗВЕДЕНИЕ ранее объявленных
  (eat-word "lattice")
  (let ((name (eat-ident "имя решётки")) (items '()) (product nil))
    (eat-punct "=")
    (push (eat-ident "степень или имя решётки") items)
    (loop
      (cond ((punct? "<") (when product (serr "нельзя смешивать < и * в одной решётке"))
                          (advance) (push (eat-ident "степень") items))
            ((punct? "*") (when (and (not product) (> (length items) 1))
                            (serr "нельзя смешивать < и * в одной решётке"))
                          (setf product t) (advance)
                          (push (eat-ident "имя решётки-части") items))
            (t (return))))
    (setf items (nreverse items))
    (when (< (length items) 2)
      (serr (if product "произведение из одной решётки — это она сама"
                        "решётка из одной степени: сравнивать нечего")))
    (if product `(lattice ,name :product ,@items) `(lattice ,name ,@items))))

(defun p-witness ()
  ;; witness ИМЯ [of МОДУЛЬ] : СТЕПЕНЬ  says "…"  source ИМЯ(, ИМЯ)*  evidence N for M against
  ;; 🔴 `of МОДУЛЬ` меняет ШКАЛУ, в которой прочитана степень: свидетель импортированного
  ;; корпуса объявляет её в решётке ИСТОЧНИКА, и она приходит к нам через φ. Ни вес, ни
  ;; источник от этого не меняются — корень границу проходит неизменным.
  (eat-word "witness")
  (let ((id (eat-ident "имя свидетеля")) module grade text sources w+ w-)
    (when (word? "of") (advance) (setf module (eat-ident "имя модуля")))
    (eat-punct ":")
    (setf grade (eat-grade "степень"))
    (eat-word "says" "свидетель обязан сказать, ЧТО он свидетельствует")
    (setf text (eat-str "речь свидетеля"))
    (eat-word "source" "свидетель обязан назвать источник")
    (setf sources (ident-list "источник"))
    (eat-word "evidence" "свидетель обязан принести ВЕС: сколько за и сколько против")
    (setf w+ (eat-num "свидетельств за"))
    (eat-word "for")
    (setf w- (eat-num "свидетельств против"))
    (eat-word "against")
    ;; 🔴 Поверхность берёт СЧЁТ свидетельств, а не (f,c): счёт — истинный носитель,
    ;; (f,c) — карта над ним (АЛГЕБРА §1.1). Так видно, что ревизия есть сложение.
    (multiple-value-bind (f c) (evidence->fc (float w+ 1.0) (float w- 1.0))
      `(witness ,id ,text :grade ,grade :f ,f :c ,c :source ,sources
                ,@(when module (list :module module))))))

;;; ── ИМПОРТ МОДУЛЯ ───────────────────────────────────────────────────────────
;;; 🔴 ДЕВЯТОЕ НЕЗАПИСЫВАЕМОЕ СОСТОЯНИЕ: импорт без φ. Продукция требует `via` и хотя бы
;;; одну строку таблицы — корпус с чужой шкалой нельзя втянуть, не сказав, как его степени
;;; читать у себя. Молчаливое «ну примерно то же самое» и есть та щель, через которую
;;; чужое `[строго]` становится нашим `[строго]` без единого свидетеля.
;;; 🔴 И таблица, а НЕ выражение: кто умеет вычислить свою степень — назначит себе веру
;;; (та же граница языка и рантайма, ГРАММАТИКА §5-bis). Таблица конечна и проверяема перебором.
(defun p-import ()
  ;; import ИМЯ lattice ИМЯ via СТЕПЕНЬ -> СТЕПЕНЬ (, СТЕПЕНЬ -> СТЕПЕНЬ)*
  (eat-word "import")
  (let ((name (eat-ident "имя модуля")) src (rows '()))
    (eat-word "lattice" "импорт обязан назвать решётку источника: ~
                         его степени приходят в ЕГО шкале, а не в нашей")
    (setf src (eat-ident "имя решётки источника"))
    (eat-word "via" "импорт обязан предъявить φ таблицей: `via строгое -> строго, …`.~%  ~
                     Без неё чужая степень попала бы к нам под своим именем — ~
                     это и есть отмывание на границе модуля")
    (loop
      (let ((a (eat-grade "степень источника")))
        (eat-punct "->")
        (push (cons a (eat-grade "степень импортёра")) rows))
      (if (punct? ",") (advance) (return)))
    `(import ,name :lattice ,src :phi ,(nreverse rows))))

(defun p-ask ()
  ;; ask ИМЯ in СВОД(, СВОД)* found nothing because "…"
  (eat-word "ask")
  (let ((id (eat-ident "имя молчания")) where why)
    (eat-word "in" "молчание обязано сказать, ГДЕ искали")
    (setf where (ident-list "свод"))
    (eat-word "found") (eat-word "nothing")
    (eat-word "because" "молчание обязано сказать, ПОЧЕМУ пусто")
    (setf why (eat-str "причина молчания"))
    `(ask ,id :in ,where :reason ,why)))

(defun p-claim ()
  ;; claim ИМЯ [: СТЕПЕНЬ] from (ИМЯ(, ИМЯ)* | nothing) [searched ИМЯ(, ИМЯ)*]
  (eat-word "claim")
  (let ((id (eat-ident "имя утверждения")) grade from searched)
    (when (punct? ":") (advance) (setf grade (eat-grade "степень")))
    ;; применение правила: claim ИМЯ [: степень] = ПРАВИЛО(посылка, …)
    (when (punct? "=")
      (advance)
      (let ((rname (eat-ident "имя правила")))
        (eat-punct "(")
        (let ((args (ident-list "посылка")))
          (eat-punct ")")
          (multiple-value-bind (f srch) (expand-rule rname args id)
            (return-from p-claim
              `(claim ,id ,@(when grade (list :grade grade))
                      (from ,@f) ,@(when srch (list (cons 'searched srch)))))))))
    (eat-word "from" "утверждение обязано назвать, на чём стоит (или `from nothing`/`from all`)")
    ;; 🔴 КВАНТИФИКАЦИЯ: `from all [where …]` — квантор по ВСЕМУ корпусу программы.
    (if (word? "all")
        (progn
          (advance)
          (let ((spec '()) (need nil))
            (when (word? "where")
              (advance)
              (loop
                (cond
                  ((word? "grade")  (advance) (eat-punct ">=")
                                    (setf spec (append spec (list :grade>= (eat-grade "степень")))))
                  ((word? "root")   (advance)
                                    (if (word? "not")
                                        (progn (advance)
                                               (setf spec (append spec (list :not-root (eat-ident "корень")))))
                                        (setf spec (append spec (list :root (eat-ident "корень"))))))
                  (t (serr "условие отбора: `grade >= степень` или `root имя` или `root not имя`.~%  ~
                            Отбирать можно по степени и по корню — не по тексту свидетельства:~%  ~
                            отбор по словам был бы черри-пикингом, который нечем измерить.")))
                (if (word? "and") (advance) (return))))
            (when (word? "requiring")
              (advance)
              (setf need (eat-num "сколько различных корней"))
              (eat-word "roots" "требование к множеству считается в КОРНЯХ, не в документах"))
            (when (word? "searched") (advance) (setf searched (ident-list "молчание")))
            (return-from p-claim
              `(claim ,id ,@(when grade (list :grade grade))
                      (from-all ,@spec)
                      ,@(when need (list (list 'requiring-roots need)))
                      ,@(when searched (list (cons 'searched searched)))))))
        (if (word? "nothing")
            (progn (advance) (setf from '()))      ; пустая база — ЯВНАЯ, и оттого видная
            (setf from (ident-list "посылка"))))
    (when (word? "searched") (advance) (setf searched (ident-list "молчание")))
    `(claim ,id ,@(when grade (list :grade grade))
            (from ,@from) ,@(when searched (list (cons 'searched searched))))))

(defun p-gate ()
  ;; gated by belief >= ЧИСЛО else ИМЯ
  (eat-word "gated") (eat-word "by")
  ;; 🔴 Слово `belief` ВШИТО. `gated by confidence` не типизируется — оно НЕ РАЗБИРАЕТСЯ.
  (unless (word? "belief")
    (serr "гейт сравнивается с `belief` (масса веры b = f·c), а не с «~a».~%  ~
           c=0.95 при f=0.50 — высокая уверенность в том, что мы разорваны пополам;~%  ~
           f=0.99 при c=0.01 — один уверенный шёпот. Держит только произведение."
          (if (peek) (tok-val (peek)) "?")))
  (advance)
  (eat-punct ">=")
  ;; 🔴 Порог можно НАЗНАЧИТЬ числом — или ВЫВЕСТИ из цены ошибки и ценности ожидания.
  ;; Второе предпочтительно: «взято с потолка» перестаёт быть возможным умолчанием.
  ;;   gated by belief >= derived gain 1 loss 4 learn 0.6 discount 0.9
  ;; θ считается при разборе (Эрроу–Фишер, src/theta.lisp), но ВЫВОД остаётся в исходнике —
  ;; читатель видит не голое 0.865, а из чего оно получилось.
  (let (thr derivation)
    (if (word? "derived")
        (progn
          (advance)
          (eat-word "gain" "вывод порога обязан назвать выигрыш при истине")
          (let ((g (eat-num "выигрыш")))
            (eat-word "loss" "…и потерю при лжи")
            (let ((l (eat-num "потеря")))
              (eat-word "learn" "…и сколько несёт ожидание: вероятность узнать правду")
              (let ((lam (eat-num "λ")))
                (eat-word "discount" "…и во сколько ценится отложенный исход")
                (let ((d (eat-num "δ")))
                  (setf derivation (list g l lam d)
                        thr (theta-derived (float g 1.0) (float l 1.0)
                                           (float lam 1.0) (float d 1.0))))))))
        (setf thr (eat-num "порог")))
    (eat-word "else" "гейт обязан иметь ветвь отказа: порог, который нечем не пройти, не гейт")
    (list thr (eat-ident "что делать при отказе") derivation)))

(defun p-action ()
  ;; reversible action ИМЯ [gate]
  ;; compensable action ИМЯ compensated by ИМЯ [gate]
  ;; irreversible action ИМЯ gate            ← гейт ОБЯЗАТЕЛЕН продукцией
  (let ((rev (cond ((word? "reversible") "reversible")
                   ((word? "compensable") "compensable")
                   ((word? "irreversible") "irreversible")
                   (t (serr "действие обязано объявить класс обратимости: ~
                             reversible / compensable / irreversible")))))
    (advance)
    (eat-word "action")
    (let ((id (eat-ident "имя действия")) comp gate req perm-quote perm-who perm-when)
      (when (string= rev "compensable")
        (eat-word "compensated" "compensable-действие обязано назвать компенсацию: ~
                                 иначе «возместимое» — пустое слово")
        (eat-word "by")
        (setf comp (eat-ident "чем компенсируется")))
      ;; ── ТРЕБОВАНИЕ К СТЕПЕНИ ОСНОВАНИЯ ────────────────────────────────────
      ;; 🔴 ДЕСЯТОЕ НЕЗАПИСЫВАЕМОЕ СОСТОЯНИЕ: необратимое действие без требования к степени.
      ;; Разбор второго домена показал дыру: гейт стоит на МАССЕ ВЕРЫ и степени не видит —
      ;; закупка прошла порог, стоя на дне решётки. Невис (`formal/Act.agda`) закрыла это
      ;; НЕ гейтом, и довод её сильнее моего: гейт есть проверка ВРЕМЕНИ ИСПОЛНЕНИЯ, а
      ;; проверку обходят, не нарушая — принеси свидетельств, вера поднимется, степень как
      ;; была дном, так и осталась. Наш тезис — «нечестность НЕВЫРАЗИМА», а не «нечестность
      ;; отлавливается». Поэтому требование живёт в ТИПЕ действия (`Act[r,θ,j,g]`), проверяется
      ;; статически и НИЧЕГО не смешивает: `belief` остаётся на своём носителе, `grade` на своём.
      ;; Два независимых порога — конъюнкция, а не единая шкала.
      (when (word? "needs")
        (advance)
        (eat-word "grade" "требование к основанию пишется по СТЕПЕНИ: `needs grade >= …`.~%  ~
                           Массу веры требует гейт (`gated by belief >= …`) — это разные ~
                           носители, и сводить их в одну шкалу нельзя")
        (eat-punct ">=")
        (setf req (eat-grade "минимальная степень основания")))
      ;; ── РАЗРЕШЕНИЕ: ТРЕТЬЯ ОСЬ, и она НЕ на решётке основания ────────────────
      ;; 🔴 Разбор Невис (29.07), снявший мой вопрос вместо того, чтобы ответить на него.
      ;; Я спрашивал, ниже или выше машинной проверки стоит слово человека. Ответ: оно вообще
      ;; не стоит на этой решётке — это ДРУГОЙ РОД. Свидетельство отвечает «что ЕСТЬ» и имеет
      ;; степень достоверности; разрешение отвечает «что МОЖНО» и степени не имеет вовсе:
      ;; оно бывает данным или не данным, а не «более истинным».
      ;; Поставь их на одну шкалу — получишь два уродства разом: право можно будет ВЫПРОСИТЬ
      ;; прогоном тестов (усилить свидетельствами до нужного уровня), а отсутствие права
      ;; будет читаться как «слабое основание», хотя это не слабость, а ЗАПРЕТ.
      ;; 🔴 ЦИТАТА ОБЯЗАТЕЛЬНА ДОСЛОВНО, с автором и датой. Это не украшение: Невис однажды
      ;; передала мне как слово Алексея строку, НАБРАННУЮ в поле ввода и не отправленную.
      ;; Требуй язык дословную цитату — та ошибка не смогла бы записаться: цитировать было нечего.
      (when (word? "needs")
        (advance)
        (eat-word "permission" "после первого `needs` идёт `grade`, после второго — `permission`")
        (setf perm-quote (eat-str "ДОСЛОВНАЯ цитата разрешения — пересказ не годится"))
        (eat-word "from" "разрешение адресно: кто именно разрешил")
        (setf perm-who (eat-ident "кто разрешил"))
        (eat-word "at" "разрешение датировано: вчерашнее «да» не разрешает сегодняшнее")
        (setf perm-when (eat-str "дата разрешения")))
      (when (and (null req) (string= rev "irreversible"))
        (serr "необратимое действие ~a не сказало, какой степени основание ему нужно.~%  ~
               Гейт по вере этого не заменяет: свидетельств можно принести сколько угодно,~%  ~
               а происхождение останется прежним. Допишите:~%    ~
               needs grade >= <степень>" id))
      (cond ((word? "gated") (setf gate (p-gate)))
            ((string= rev "irreversible")
             (serr "необратимое действие ~a без гейта.~%  ~
                    Необратимое недостижимо в обход порога — допишите:~%    ~
                    gated by belief >= 0.9~%    else fold" id)))
      `(action ,id :reversibility ,(intern (string-upcase rev))
               ,@(when req `(:needs-grade ,req))
               ,@(when perm-who `(:permission (,perm-quote ,perm-who ,perm-when)))
               ,@(when gate `(:requires (>= belief ,(first gate)) :else ,(second gate)))
               ,@(when (and gate (third gate)) `(:theta-from ,(third gate)))
               ,@(when comp `(:compensated-by ,comp))))))

;;; ── ПРАВИЛА: полиморфизм по степеням без введения функций ───────────────────
;;; 🔴 РЕШЕНИЕ ОБ ОБЪЁМЕ. Полиморфный тип `∀g₁g₂. Jud[g₁]→Jud[g₂]→Jud[g₁⊓g₂]` требует носителя.
;;; Функций в языке нет и вводить их ради этого — расширение куда большее, чем нужно (ГРАММАТИКА
;;; §6 отложила выражения СОЗНАТЕЛЬНО). Носитель поменьше и достаточный: ПРАВИЛО — именованный
;;; вывод, параметризованный посылками. Применение раскрывается подстановкой при разборе.
;;;
;;; 💎 Раскрытие подстановкой = проверка при КАЖДОМ применении, на конкретных степенях. Для
;;; КОНЕЧНОЙ решётки это не слабее полиморфизма: «∀g» разрешимо перебором, и тест перебирает.
;;;
;;; 🔴 ПРАВИЛО НЕ МОЖЕТ ОБЪЯВИТЬ СТЕПЕНЬ — только вывести. Иначе одно дурное правило отмывало
;;; бы везде, где применено: степень, объявленная один раз, размножилась бы по всем употреблениям.
;;; Это тот же ход, что и всюду: не проверять правила на добросовестность, а не дать им солгать.
(defvar *rules* '() "Имя правила → (параметры формы-посылок формы-обзора).")

(defun p-rule ()
  ;; rule ИМЯ(п₁, п₂, …) concludes from п₁, п₂ [searched п₃]
  (eat-word "rule")
  (let ((name (eat-ident "имя правила")) params from searched)
    (eat-punct "(")
    (setf params (ident-list "параметр"))
    (eat-punct ")")
    (when (punct? ":")
      (serr "правило не может ОБЪЯВИТЬ степень — только вывести её из посылок.~%  ~
             Иначе одно правило отмывало бы везде, где применено: объявленная степень~%  ~
             размножилась бы по всем употреблениям. Уберите «: степень»."))
    (eat-word "concludes" "правило обязано сказать, что оно выводит")
    (eat-word "from" "…и из чего: перечислите параметры")
    (setf from (ident-list "посылка"))
    (when (word? "searched") (advance) (setf searched (ident-list "молчание")))
    (dolist (x (append from searched))
      (unless (member x params)
        (serr "правило ~a использует ~a, которого нет среди его параметров.~%  ~
               Правило замкнуто на свои параметры: тянуть свидетеля из окружения значило бы~%  ~
               прятать посылку от читателя." name x)))
    (push (list name params from searched) *rules*)
    `(rule ,name ,params ,from ,searched)))

(defun expand-rule (name args where)
  "Подстановка фактических посылок вместо формальных. → (from …) и (searched …)."
  (let ((r (assoc name *rules*)))
    (unless r (serr "неизвестное правило ~a" name))
    (destructuring-bind (nm params from searched) r
      (declare (ignore nm))
      (unless (= (length params) (length args))
        (serr "правило ~a ждёт ~a посылок, дано ~a — ~a"
              name (length params) (length args) where))
      (let ((sub (mapcar #'cons params args)))
        (values (mapcar (lambda (x) (cdr (assoc x sub))) from)
                (mapcar (lambda (x) (cdr (assoc x sub))) searched))))))

(defun p-revoke ()
  ;; revoke permission from ИМЯ because "…"
  ;; 🔴 ОТДЕЛЬНАЯ ФОРМА, а не `retract` над разрешением — потому что и последствие другое.
  ;; Отзыв свидетеля рушит ОСНОВАНИЕ: вера падает, действие осиротело. Отзыв разрешения
  ;; основания не трогает: вера прежняя, свидетельства целы — а действие стало НЕПРАВОМЕРНЫМ.
  ;; Числами эти два случая не различить, как и три статуса из I3. Значит нужен четвёртый.
  (eat-word "revoke")
  (eat-word "permission" "отзывается именно РАЗРЕШЕНИЕ; свидетеля отзывает `retract`")
  (eat-word "from" "разрешение адресно — назовите, чьё именно отозвано")
  (let ((who (eat-ident "чьё разрешение отозвано")))
    (eat-word "because" "отзыв права обязан назвать причину, как и отзыв свидетеля")
    `(revoke ,who :reason ,(eat-str "причина отзыва разрешения"))))

(defun p-retract ()
  ;; retract ИМЯ because "…"    ← причина ОБЯЗАТЕЛЬНА: молча свидетеля не убирают
  (eat-word "retract")
  (let ((w (eat-ident "отзываемый свидетель")))
    (eat-word "because" "отзыв обязан назвать причину: степень может подняться, ~
                         и подъём без записанной причины был бы отмыванием")
    `(retract ,w :reason ,(eat-str "причина отзыва"))))

(defun p-perform ()
  ;; perform ИМЯ on ИМЯ
  (eat-word "perform")
  (let ((a (eat-ident "действие")))
    (eat-word "on" "действие совершается НА основании — назовите его")
    `(do ,a ,(eat-ident "основание"))))

(defun p-decl ()
  (cond ((word? "lattice") (p-lattice))
        ((word? "import")  (p-import))
        ((word? "witness") (p-witness))
        ((word? "ask")     (p-ask))
        ((word? "claim")   (p-claim))
        ((word? "rule")    (p-rule))
        ((word? "retract") (p-retract))
        ((word? "revoke")  (p-revoke))
        ((word? "perform") (p-perform))
        ((or (word? "reversible") (word? "compensable") (word? "irreversible")) (p-action))
        (t (serr "непонятное начало объявления: «~a». Ожидалось одно из: ~
                  lattice · import · witness · ask · claim · rule · retract · revoke · perform · ~
                  reversible/compensable/irreversible action"
                 (if (peek) (tok-val (peek)) "конец текста")))))

;;; ── вход ────────────────────────────────────────────────────────────────────
(defun parse (src)
  "Текст программы → список форм для check-program. Сигналит NOL-SYNTAX-ERROR."
  (let ((*toks* (lex src)) (*line* 1) (out '()) (*rules* '()))
    (loop while *toks* do (push (p-decl) out))
    (nreverse out)))

(defun parse-ok? (src)
  (handler-case (progn (parse src) t) (nol-syntax-error () nil)))

(defun parse-error-of (src)
  (handler-case (progn (parse src) nil) (nol-syntax-error (e) (princ-to-string e))))

(defun compile-nolang (src)
  "Полный проход: текст → формы → проверка. → (values формы ошибки)."
  (let ((forms (parse src)))
    (multiple-value-bind (env errs) (check-program forms)
      (declare (ignore env))
      (values forms errs))))
