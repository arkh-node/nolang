{-# OPTIONS --safe #-}
-- ============================================================
--  nolang · PRESERVATION: статическая степень = динамической
--
--  ЗАЧЕМ ЭТОТ ФАЙЛ.
--   В §8 записки Тарантоги здравость держится на дифференциальном тесте
--   двух реализаций (`chk-claim` и `red-claim`), которые обе зовут одну
--   `g-meet`. Такой тест поймает расхождение проверяющего с машиной, но
--   НЕ поймает общую ошибку обеих. Здесь они становятся двумя РАЗНЫМИ
--   определениями, равенство которых доказано, а не проверено.
--
--  ПОПРАВКА К ФОРМУЛИРОВКЕ (Невис, 28.07).
--   «Тип неизменен вдоль прогона» — ложно: отзыв свидетеля МЕНЯЕТ степень
--   (РЕДУКЦИЯ_v0 §7.4). Правильное утверждение: типизация выводит ФУНКЦИЮ
--   из множества мёртвых свидетелей в степень, а машина эту функцию
--   вычисляет. Доказывается поточечное равенство функций.
--
--  ЧТО ЗДЕСЬ ДОКАЗАНО (теоремы, не тесты):
--   1. preservation : chk ≡ red для любого множества отзывов D
--   2. empty-base   : пустая база даёт ⊥, а не верх решётки
--                     (тот самый баг «отмывание из ничего»)
--   3. silence-kills: молчание в основании роняет всё до ⊥, даже рядом
--                     со свидетелями [строго]  (АЛГЕБРА_v0 §2.5)
--   4. swap-inv     : перестановка двух соседних объявлений не меняет степени
--                     — ядро конфлюэнтности (§4.2), у Тарантоги проверенной
--                     200 топосортировками
--
--   5. retract-raises + live-sub + retract-raises-live :
--      ОТЗЫВ ПОДНИМАЕТ СТЕПЕНЬ, пока после него остаётся хоть одна живая
--      посылка. Это не баг реализации, а теорема о решётке — значит защита
--      может быть только в записи (журнал, обязательная причина), как и
--      сказано в §7.4. Мост `live-sub` доказан отдельно: рост мёртвого
--      множества даёт именно подпоследовательность живых посылок.
--   6. retract-collapse : на пустой базе степень обваливается в ⊥.
--      Вместе 5 и 6 дают ТОЧНУЮ форму вектора злоупотребления §7.4.
--
--   7. perm-inv : конфлюэнтность для ЛЮБОЙ перестановки объявлений
--      (у Тарантоги §4.2 — 200 топосортировок; здесь доказано индукцией).
--
--  ЧТО ЕЩЁ НЕ ДОКАЗАНО (сказано вслух, чтобы на этот файл не сослались):
--   • ничего не сказано про `(f,c)` и массу веры: этот файл про СТЕПЕНЬ.
--     Гейт на `b = f·c` живёт в рантайме и здесь не затронут.
--
--  Доказано для ЛЮБОЙ объявленной решётки: модуль параметризован
--  полурешёткой, как и задумано в ГРАММАТИКЕ_v0 (решётку объявляет
--  программа). Значит смена `lattice provenance = …` не трогает эти теоремы.
--
--  Самодостаточен: без stdlib, только Agda.Builtin. Проверяется под --safe.
-- ============================================================

module Preservation where

open import Agda.Builtin.Equality using (_≡_; refl)
open import Agda.Builtin.Nat using (Nat; zero; suc)
open import Agda.Builtin.Bool using (Bool; true; false)
open import Agda.Builtin.List using (List; []; _∷_)

-- ------------------------------------------------------------
-- 0. Вспомогательное
-- ------------------------------------------------------------

cong : ∀ {A B : Set} (f : A → B) {x y : A} → x ≡ y → f x ≡ f y
cong f refl = refl

sym : ∀ {A : Set} {x y : A} → x ≡ y → y ≡ x
sym refl = refl

trans : ∀ {A : Set} {x y z : A} → x ≡ y → y ≡ z → x ≡ z
trans refl refl = refl

subst : ∀ {A : Set} (P : A → Set) {x y : A} → x ≡ y → P x → P y
subst P refl px = px

_==ᴺ_ : Nat → Nat → Bool
zero  ==ᴺ zero  = true
zero  ==ᴺ suc _ = false
suc _ ==ᴺ zero  = false
suc m ==ᴺ suc n = m ==ᴺ n

-- ------------------------------------------------------------
-- 1. Решётка степеней — параметр, а не константа
--    (ГРАММАТИКА_v0: «решётка объявляется программой»)
-- ------------------------------------------------------------

record MeetSemilattice : Set₁ where
  field
    G     : Set
    ⊥ᴳ    : G                         -- молчание: низ решётки
    _⊓_   : G → G → G
    ⊓-comm  : ∀ a b   → (a ⊓ b) ≡ (b ⊓ a)
    ⊓-assoc : ∀ a b c → ((a ⊓ b) ⊓ c) ≡ (a ⊓ (b ⊓ c))
    ⊓-idem  : ∀ a     → (a ⊓ a) ≡ a
    ⊥-absorb : ∀ a    → (⊥ᴳ ⊓ a) ≡ ⊥ᴳ   -- ниже молчания не падают

module Core (L : MeetSemilattice) where
  open MeetSemilattice L

  Id : Set
  Id = Nat

  -- Посылка: свидетель со степенью, либо молчание (степень ⊥ по T-CLAIM)
  data Premise : Set where
    wit : Id → G → Premise
    sil : Id → Premise

  pid : Premise → Id
  pid (wit i _) = i
  pid (sil i)   = i

  grade-of : Premise → G
  grade-of (wit _ g) = g
  grade-of (sil _)   = ⊥ᴳ            -- «традиция молчит, следовательно…» → ⊥

  -- Множество отозванных свидетелей D
  Dead : Set
  Dead = List Id

  -- без `with`: иначе определения не редуцируются под абстрактным скрутинем,
  -- и лемма live-sub (§10) не проходит
  _or_ : Bool → Bool → Bool
  true  or _ = true
  false or b = b

  ifL : Bool → List Premise → List Premise → List Premise
  ifL true  t f = t
  ifL false t f = f

  _∈?_ : Id → Dead → Bool
  i ∈? []       = false
  i ∈? (j ∷ js) = (i ==ᴺ j) or (i ∈? js)

  live : Dead → List Premise → List Premise
  live d []       = []
  live d (p ∷ ps) = ifL (pid p ∈? d) (live d ps) (p ∷ live d ps)

  -- ----------------------------------------------------------
  -- 2. ДВЕ РАЗНЫЕ реализации степени утверждения
  -- ----------------------------------------------------------

  -- (а) ПРОВЕРЯЮЩИЙ. Как в ТИПЫ_v0 §3, T-CLAIM: g* = ⊥ при n = 0,
  --     иначе ⨅ по посылкам. Пустая база НЕ даёт верх решётки.
  chkOn : List Premise → G
  chkOn []          = ⊥ᴳ
  chkOn (p ∷ [])    = grade-of p
  chkOn (p ∷ q ∷ r) = grade-of p ⊓ chkOn (q ∷ r)

  -- (б) МАШИНА. Идёт по объявлениям и копит склад в аккумуляторе —
  --     другой алгоритм, не другая запись того же.
  walk⁺ : G → List Premise → G
  walk⁺ acc []         = acc
  walk⁺ acc (p ∷ rest) = walk⁺ (acc ⊓ grade-of p) rest

  redOn : List Premise → G
  redOn []      = ⊥ᴳ
  redOn (p ∷ r) = walk⁺ (grade-of p) r

  chk : Dead → List Premise → G
  chk d ps = chkOn (live d ps)

  red : Dead → List Premise → G
  red d ps = redOn (live d ps)

  -- ----------------------------------------------------------
  -- 3. ТЕОРЕМА 1 (preservation): проверяющий = машина
  -- ----------------------------------------------------------

  private
    -- ключевая лемма: аккумулятор выносится наружу (ассоциативность ⊓)
    walk⁺-out : ∀ (a : G) (p : Premise) (ps : List Premise)
              → walk⁺ (a ⊓ grade-of p) ps ≡ (a ⊓ chkOn (p ∷ ps))
    walk⁺-out a p []       = refl
    walk⁺-out a p (q ∷ ps) =
      trans (walk⁺-out (a ⊓ grade-of p) q ps)
            (⊓-assoc a (grade-of p) (chkOn (q ∷ ps)))

    walk⁺-chk : ∀ (p : Premise) (ps : List Premise)
              → walk⁺ (grade-of p) ps ≡ chkOn (p ∷ ps)
    walk⁺-chk p []       = refl
    walk⁺-chk p (q ∷ ps) = walk⁺-out (grade-of p) q ps

    agree : ∀ (qs : List Premise) → chkOn qs ≡ redOn qs
    agree []          = refl
    agree (p ∷ [])    = refl
    agree (p ∷ q ∷ r) = sym (walk⁺-chk p (q ∷ r))

  preservation : ∀ (d : Dead) (ps : List Premise) → chk d ps ≡ red d ps
  preservation d ps = agree (live d ps)

  -- ----------------------------------------------------------
  -- 4. ТЕОРЕМА 2: пустая база даёт ⊥ («отмывание из ничего» невозможно)
  -- ----------------------------------------------------------

  empty-base : ∀ (d : Dead) → chk d [] ≡ ⊥ᴳ
  empty-base d = refl

  -- ----------------------------------------------------------
  -- 5. ТЕОРЕМА 3: молчание в основании роняет всё до ⊥,
  --    даже рядом со свидетелями [строго]  (АЛГЕБРА_v0 §2.5)
  -- ----------------------------------------------------------

  silence-kills : ∀ (i : Id) (ps : List Premise)
                → chk [] (sil i ∷ ps) ≡ ⊥ᴳ
  silence-kills i []       = refl
  silence-kills i (q ∷ ps) = ⊥-absorb _

  -- ----------------------------------------------------------
  -- 6. ТЕОРЕМА 4 (ядро конфлюэнтности): соседняя перестановка
  --    не меняет степени. Порядок объявлений не влияет на склад.
  -- ----------------------------------------------------------

  swap-inv : ∀ (p q : Premise) (r : List Premise)
           → chkOn (p ∷ q ∷ r) ≡ chkOn (q ∷ p ∷ r)
  swap-inv p q []       = ⊓-comm (grade-of p) (grade-of q)
  swap-inv p q (z ∷ r) =
    trans (sym (⊓-assoc (grade-of p) (grade-of q) (chkOn (z ∷ r))))
      (trans (cong (λ x → x ⊓ chkOn (z ∷ r)) (⊓-comm (grade-of p) (grade-of q)))
             (⊓-assoc (grade-of q) (grade-of p) (chkOn (z ∷ r))))

  -- ----------------------------------------------------------
  -- 7. ПОРЯДОК ⊑ и его законы (выводятся из полурешётки, не постулируются)
  -- ----------------------------------------------------------

  _⊑_ : G → G → Set
  a ⊑ b = (a ⊓ b) ≡ a

  ⊑-refl : ∀ a → a ⊑ a
  ⊑-refl a = ⊓-idem a

  ⊑-trans : ∀ {a b c} → a ⊑ b → b ⊑ c → a ⊑ c
  ⊑-trans {a} {b} {c} p q =
    trans (cong (λ x → x ⊓ c) (sym p))
      (trans (⊓-assoc a b c)
        (trans (cong (λ x → a ⊓ x) q) p))

  meet-lower₁ : ∀ a b → (a ⊓ b) ⊑ a
  meet-lower₁ a b =
    trans (⊓-assoc a b a)
      (trans (cong (λ x → a ⊓ x) (⊓-comm b a))
        (trans (sym (⊓-assoc a a b))
               (cong (λ x → x ⊓ b) (⊓-idem a))))

  meet-lower₂ : ∀ a b → (a ⊓ b) ⊑ b
  meet-lower₂ a b = trans (⊓-assoc a b b) (cong (λ x → a ⊓ x) (⊓-idem b))

  meet-mono-r : ∀ a {b c} → b ⊑ c → (a ⊓ b) ⊑ (a ⊓ c)
  meet-mono-r a {b} {c} q =
    trans (⊓-assoc a b (a ⊓ c))
      (trans (cong (λ x → a ⊓ x) (sym (⊓-assoc b a c)))
        (trans (cong (λ x → a ⊓ (x ⊓ c)) (⊓-comm b a))
          (trans (cong (λ x → a ⊓ x) (⊓-assoc a b c))
            (trans (sym (⊓-assoc a a (b ⊓ c)))
              (trans (cong (λ x → x ⊓ (b ⊓ c)) (⊓-idem a))
                     (cong (λ x → a ⊓ x) q))))))

  -- ----------------------------------------------------------
  -- 8. ТЕОРЕМА 5 (монотонность по отзыву)
  --    Отзыв свидетеля ПОДНИМАЕТ степень — пока база не опустела.
  --    Это и есть точная форма вектора злоупотребления из РЕДУКЦИЯ_v0 §7.4:
  --    вычеркнуть неудобного свидетеля и стать сильнее — не баг реализации,
  --    а теорема о решётке. Значит защита может быть только в записи.
  -- ----------------------------------------------------------

  -- подпоследовательность: ys получается из xs выбрасыванием
  data Sub : List Premise → List Premise → Set where
    sub-nil  : Sub [] []
    sub-keep : ∀ {x xs ys} → Sub xs ys → Sub (x ∷ xs) (x ∷ ys)
    sub-drop : ∀ {x xs ys} → Sub xs ys → Sub (x ∷ xs) ys

  data NE : List Premise → Set where
    ne : ∀ p ps → NE (p ∷ ps)

  sub-NE : ∀ {xs ys} → Sub xs ys → NE ys → NE xs
  sub-NE (sub-keep {x} {xs} s) _ = ne x xs
  sub-NE (sub-drop {x} {xs} s) _ = ne x xs

  -- голова свёртки: на непустом хвосте chkOn (x ∷ xs) = grade x ⊓ chkOn xs
  chk-cons : ∀ (x : Premise) {xs} → NE xs → chkOn (x ∷ xs) ≡ (grade-of x ⊓ chkOn xs)
  chk-cons x (ne p ps) = refl

  -- случай, когда от хвоста не осталось ничего, а голова сохранена
  keep-last : ∀ (x : Premise) {xs} → chkOn (x ∷ xs) ⊑ chkOn (x ∷ [])
  keep-last x {[]}     = ⊑-refl (grade-of x)
  keep-last x {z ∷ zs} = meet-lower₁ (grade-of x) (chkOn (z ∷ zs))

  retract-raises : ∀ {xs ys} → Sub xs ys → NE ys → chkOn xs ⊑ chkOn ys
  retract-raises (sub-keep {x} {xs} {[]}     s) _ = keep-last x {xs}
  retract-raises (sub-keep {x} {xs} {y ∷ ys} s) _ with sub-NE s (ne y ys)
  ... | nxs = subst (λ u → u ⊑ (grade-of x ⊓ chkOn (y ∷ ys)))
                    (sym (chk-cons x nxs))
                    (meet-mono-r (grade-of x) (retract-raises s (ne y ys)))
  retract-raises (sub-drop {x} {xs} {ys} s) nys with sub-NE s nys
  ... | nxs = subst (λ u → u ⊑ chkOn ys)
                    (sym (chk-cons x nxs))
                    (⊑-trans (meet-lower₂ (grade-of x) (chkOn xs))
                             (retract-raises s nys))

  -- ----------------------------------------------------------
  -- 9. ТЕОРЕМА 6 (обвал): когда отозвано ВСЁ, степень падает в ⊥,
  --    а не поднимается. Ровно граница, на которой ломается теорема 5.
  -- ----------------------------------------------------------

  retract-collapse : ∀ {xs} → Sub xs [] → chkOn [] ≡ ⊥ᴳ
  retract-collapse _ = refl

  -- ----------------------------------------------------------
  -- 10. МОСТ к правилу R-RETRACT: добавление свидетеля в мёртвое
  --     множество даёт именно подпоследовательность живых посылок.
  --     Без этой леммы теорема 5 доказана «про списки», а не «про отзыв».
  -- ----------------------------------------------------------

  live-sub : ∀ (i : Id) (d : Dead) (ps : List Premise)
           → Sub (live d ps) (live (i ∷ d) ps)
  live-sub i d []       = sub-nil
  live-sub i d (p ∷ ps) with pid p ==ᴺ i | pid p ∈? d
  ... | true  | true  = live-sub i d ps
  ... | true  | false = sub-drop (live-sub i d ps)
  ... | false | true  = live-sub i d ps
  ... | false | false = sub-keep (live-sub i d ps)

  -- Итог в терминах отзыва: пока после отзыва остаётся хоть одна живая
  -- посылка, степень утверждения не падает.
  retract-raises-live : ∀ (i : Id) (d : Dead) (ps : List Premise)
                      → NE (live (i ∷ d) ps)
                      → chk d ps ⊑ chk (i ∷ d) ps
  retract-raises-live i d ps nz = retract-raises (live-sub i d ps) nz

  -- ----------------------------------------------------------
  -- 11. ТЕОРЕМА 7 (конфлюэнтность): степень не зависит от порядка
  --     объявлений — для ЛЮБОЙ перестановки, а не только соседней.
  --     У Тарантоги (§4.2) это проверено 200 топосортировками; здесь доказано.
  -- ----------------------------------------------------------

  data Perm : List Premise → List Premise → Set where
    perm-nil   : Perm [] []
    perm-skip  : ∀ x {xs ys} → Perm xs ys → Perm (x ∷ xs) (x ∷ ys)
    perm-swap  : ∀ x y xs → Perm (x ∷ y ∷ xs) (y ∷ x ∷ xs)
    perm-trans : ∀ {xs ys zs} → Perm xs ys → Perm ys zs → Perm xs zs

  perm-NE : ∀ {xs ys} → Perm xs ys → NE xs → NE ys
  perm-NE perm-nil ()
  perm-NE (perm-skip x {xs} {ys} p) _ = ne x ys
  perm-NE (perm-swap x y xs) _        = ne y (x ∷ xs)
  perm-NE (perm-trans p q) n          = perm-NE q (perm-NE p n)

  perm-empty : ∀ {ys} → Perm [] ys → ys ≡ []
  perm-empty perm-nil = refl
  perm-empty (perm-trans p q) with perm-empty p
  ... | refl = perm-empty q

  perm-inv : ∀ {xs ys} → Perm xs ys → chkOn xs ≡ chkOn ys
  perm-inv perm-nil            = refl
  perm-inv (perm-swap x y xs)  = swap-inv x y xs
  perm-inv (perm-trans p q)    = trans (perm-inv p) (perm-inv q)
  perm-inv (perm-skip x {[]} p) with perm-empty p
  ... | refl = refl
  perm-inv (perm-skip x {z ∷ zs} p) with perm-NE p (ne z zs)
  ... | nys = trans (chk-cons x (ne z zs))
                (trans (cong (λ u → grade-of x ⊓ u) (perm-inv p))
                       (sym (chk-cons x nys)))
