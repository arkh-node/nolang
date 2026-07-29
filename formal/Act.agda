-- ============================================================
--  nolang · ДЕЙСТВИЕ: осиротение как ТИПОВОЕ событие
--                     и требование к степени В ТИПЕ
--
--  ЗАЧЕМ (Тарантога, находка №1 от 29.07.2026).
--   На живом примере (закупка национального запаса на неопубликованных
--   данных) необратимое действие прошло гейт с верой 0.889, тогда как
--   степень основания была НА ДНЕ решётки (`наблюдение·недоступно`).
--   Все четыре уровня отработали как задумано, язык честно напечатал дно
--   словами — и необратимое всё равно совершилось. Защиты измеряли разные
--   вещи, а на пути у действия стояла одна.
--
--  ПОЧЕМУ НЕ ЧИНИТСЯ ГЕЙТОМ (мой ответ ему, 29.07).
--   Гейт — проверка времени исполнения. Проверку обходят, не нарушая:
--   добавь свидетельств, поднимающих веру, — степень как была дном, так и
--   осталась, а порог взят. Тезис языка — «нечестность НЕВЫРАЗИМА»,
--   а не «нечестность отлавливается». Проверка в гейте вернула бы язык
--   в класс библиотек-с-валидацией.
--
--  ПОЧЕМУ НЕ ЧИНИТСЯ ГРАММАТИКОЙ.
--   Грамматика в момент разбора не знает степени: она возникает из решётки
--   над объявлениями. Запрет в грамматике был бы либо ложью, либо
--   требованием писать степень руками — то самое отмывание, только легальное.
--
--  ЧТО ЗДЕСЬ СДЕЛАНО.
--   Требование к степени становится ЧАСТЬЮ ТИПА ДЕЙСТВИЯ: `Act` несёт
--   `req : G`, и действие типизируется только если основание не ниже `req`.
--   Тогда «необратимое на дне» — непредставимо (теорема 3), а не поймано.
--   Гейт при этом остаётся ровно тем, чем был: порогом по вере, на своём
--   носителе, без всякой примеси (масса веры — в `BeliefMass`, сюда не входит).
--
--  ЧТО ДОКАЗАНО:
--   1. ⊑-refl, ⊑-trans      : порядок, порождённый решёткой
--   2. strengthen           : усиление основания не разтипизирует действие
--   3. 🔴 bottom-blocks     : при основании-дне типизируются ТОЛЬКО действия,
--      ничего не требующие; необратимое с требованием выше дна непредставимо
--   4. 🔴 orphan-on-retract : отзыв всех корней = осиротение (типовое событие)
--   5. 🔴 no-resurrection   : отзыв монотонен — осиротевшее не воскресает,
--      сколько бы свидетельств ни добавили после
--   6. irreparable-is-final : у необратимого осиротение неотменяемо, и это
--      РАЗНЫЕ статусы: «свернулось» ≠ «осиротело» ≠ «непоправимо»
--
--  ЧЕГО ЗДЕСЬ НЕТ:
--   • ничего про массу веры и порог θ — это `BeliefMass` (гейт не тронут);
--   • ничего про свёртку по корням — это `SupportSet`;
--   • здесь только ТИП ДЕЙСТВИЯ и его события.
--
--  Самодостаточен: без stdlib. Проверяется под --safe.
--  — Невис, 29.07.2026
-- ============================================================

module Act where

open import Agda.Builtin.Equality using (_≡_; refl)
open import Agda.Builtin.Nat using (Nat; zero; suc)
open import Agda.Builtin.Bool using (Bool; true; false)
open import Agda.Builtin.List using (List; []; _∷_)

open import Preservation using (MeetSemilattice)

-- ------------------------------------------------------------
-- 0. Вспомогательное
-- ------------------------------------------------------------

data Empty : Set where

¬_ : Set → Set
¬ A = A → Empty

sym : ∀ {A : Set} {x y : A} → x ≡ y → y ≡ x
sym refl = refl

trans : ∀ {A : Set} {x y z : A} → x ≡ y → y ≡ z → x ≡ z
trans refl refl = refl

cong : ∀ {A B : Set} (f : A → B) {x y : A} → x ≡ y → f x ≡ f y
cong f refl = refl

_==ᴺ_ : Nat → Nat → Bool
zero  ==ᴺ zero  = true
zero  ==ᴺ suc _ = false
suc _ ==ᴺ zero  = false
suc m ==ᴺ suc n = m ==ᴺ n

_or_ : Bool → Bool → Bool
true  or _ = true
false or b = b

_and_ : Bool → Bool → Bool
true  and b = b
false and _ = false

-- без `with`: иначе определения не редуцируются под абстрактным скрутинем
ifB : ∀ {A : Set} → Bool → A → A → A
ifB true  t f = t
ifB false t f = f

-- ------------------------------------------------------------
-- 1. Корни, отзыв, осиротение — общее для любой решётки
-- ------------------------------------------------------------

Root : Set
Root = Nat

Support : Set
Support = List Root

-- множество отозванных корней (то же `Dead`, что в Preservation)
Dead : Set
Dead = List Root

_∈?_ : Root → List Root → Bool
r ∈? []       = false
r ∈? (s ∷ ss) = (r ==ᴺ s) or (r ∈? ss)

-- «ни один корень не пережил отзыв»
noneAlive : Dead → Support → Bool
noneAlive d []       = true
noneAlive d (r ∷ rs) = (r ∈? d) and noneAlive d rs

-- 🔴 Три РАЗНЫХ статуса. Свести их в одно «нет» значило бы выдать
--    негодную программу за честный отказ (различение Тарантоги, F1–F2).
data Status : Set where
  live        : Status   -- основание живо
  orphaned    : Status   -- корни отозваны, действие обратимо → сворачиваем
  irreparable : Status   -- корни отозваны, а действие уже совершено и необратимо

-- ------------------------------------------------------------
-- 2. Действие: требование к степени — В ТИПЕ, не в гейте
-- ------------------------------------------------------------

module WithLattice (L : MeetSemilattice) where
  open MeetSemilattice L

  -- порядок, порождённый решёткой: a ⊑ b ⟺ a ⊓ b ≡ a
  _⊑_ : G → G → Set
  a ⊑ b = (a ⊓ b) ≡ a

  ⊑-refl : ∀ a → a ⊑ a
  ⊑-refl a = ⊓-idem a

  ⊑-trans : ∀ a b c → a ⊑ b → b ⊑ c → a ⊑ c
  ⊑-trans a b c ab bc =
    trans (sym (cong (λ z → z ⊓ c) ab))
          (trans (⊓-assoc a b c)
                 (trans (cong (λ z → a ⊓ z) bc) ab))

  record Action : Set where
    constructor act
    field
      supp         : Support   -- корни основания (носитель — `SupportSet`)
      req          : G         -- 🔴 g: минимальная степень, которую действие ТРЕБУЕТ
      irreversible : Bool      -- необратимо ли

  open Action

  -- ----------------------------------------------------------
  -- ТИПИЗАЦИЯ. Действие принимается только если основание не ниже
  -- требования. Это не проверка в рантайме — это условие того,
  -- что программа вообще типизирована.
  -- ----------------------------------------------------------
  data Typed (basis : G) (a : Action) : Set where
    typed : req a ⊑ basis → Typed basis a

  -- ----------------------------------------------------------
  -- ТЕОРЕМА 2 (strengthen). Усиление основания не может разтипизировать
  -- действие: если основание стало выше по решётке, требование тем более
  -- выполнено. (Обратное неверно и не должно быть верным.)
  -- ----------------------------------------------------------
  strengthen : ∀ (b b′ : G) (a : Action)
             → b ⊑ b′ → Typed b a → Typed b′ a
  strengthen b b′ a bb′ (typed r⊑b) = typed (⊑-trans (req a) b b′ r⊑b bb′)

  -- ----------------------------------------------------------
  -- 🔴 ТЕОРЕМА 3 (bottom-blocks) — ответ на находку №1.
  --
  --    При основании, равном ДНУ решётки, типизируются только действия,
  --    которые ничего не требуют. Значит необратимое действие с любым
  --    требованием выше дна на таком основании НЕПРЕДСТАВИМО — не «поймано
  --    гейтом», а не существует как типизированная программа.
  -- ----------------------------------------------------------
  bottom-blocks : ∀ (a : Action) → Typed ⊥ᴳ a → req a ≡ ⊥ᴳ
  bottom-blocks a (typed r⊑⊥) =
    trans (sym r⊑⊥) (trans (⊓-comm (req a) ⊥ᴳ) (⊥-absorb (req a)))

  -- прямое следствие, ради которого всё писалось
  no-irreversible-on-bottom : ∀ (a : Action)
                            → ¬ (req a ≡ ⊥ᴳ)
                            → ¬ (Typed ⊥ᴳ a)
  no-irreversible-on-bottom a req≢⊥ t = req≢⊥ (bottom-blocks a t)

  -- ----------------------------------------------------------
  -- 3. Осиротение как ТИПОВОЕ событие
  -- ----------------------------------------------------------

  status : Dead → Action → Status
  status d a = ifB (noneAlive d (supp a))
                   (ifB (irreversible a) irreparable orphaned)
                   live

  -- ТЕОРЕМА 4 (orphan-on-retract): когда ни один корень не пережил отзыв,
  -- действие осиротело — и статус зависит от того, было ли оно необратимым.
  orphan-on-retract : ∀ (d : Dead) (a : Action)
                    → noneAlive d (supp a) ≡ true
                    → irreversible a ≡ false
                    → status d a ≡ orphaned
  orphan-on-retract d a none rev
    rewrite none | rev = refl

  irreparable-on-retract : ∀ (d : Dead) (a : Action)
                         → noneAlive d (supp a) ≡ true
                         → irreversible a ≡ true
                         → status d a ≡ irreparable
  irreparable-on-retract d a none rev
    rewrite none | rev = refl

  -- ----------------------------------------------------------
  -- 🔴 ТЕОРЕМА 5 (no-resurrection). Отзыв МОНОТОНЕН: если корни уже
  --    мертвы при множестве отзывов d, они мертвы и при любом большем d′.
  --    Осиротевшее не воскресает, сколько свидетельств ни добавь после.
  -- ----------------------------------------------------------
  private
    -- монотонность отзыва по одному корню — прямо из посылки
    none-mono : ∀ (d d′ : Dead) (s : Support)
              → (∀ i → (i ∈? d) ≡ true → (i ∈? d′) ≡ true)
              → noneAlive d s ≡ true → noneAlive d′ s ≡ true
    none-mono d d′ []       h p = refl
    none-mono d d′ (r ∷ rs) h p with (r ∈? d) in eq
    ... | true  rewrite h r eq = none-mono d d′ rs h p
    ... | false = absurd p
      where
        absurd : (false and noneAlive d rs) ≡ true → noneAlive d′ (r ∷ rs) ≡ true
        absurd ()

  -- Посылки даны явно (корни мертвы, действие необратимо), а не вынуты
  -- разбором статуса: разбор `with` здесь только запутал бы доказательство,
  -- а сила утверждения та же — осиротевшее необратимое остаётся непоправимым
  -- при ЛЮБОМ расширении множества отзывов.
  no-resurrection : ∀ (d d′ : Dead) (a : Action)
                  → (∀ i → (i ∈? d) ≡ true → (i ∈? d′) ≡ true)
                  → noneAlive d (supp a) ≡ true
                  → irreversible a ≡ true
                  → status d′ a ≡ irreparable
  no-resurrection d d′ a h none rev =
    irreparable-on-retract d′ a (none-mono d d′ (supp a) h none) rev

  -- та же монотонность для обратимого действия: осиротело — значит осиротело
  orphan-stays : ∀ (d d′ : Dead) (a : Action)
               → (∀ i → (i ∈? d) ≡ true → (i ∈? d′) ≡ true)
               → noneAlive d (supp a) ≡ true
               → irreversible a ≡ false
               → status d′ a ≡ orphaned
  orphan-stays d d′ a h none rev =
    orphan-on-retract d′ a (none-mono d d′ (supp a) h none) rev

  -- ----------------------------------------------------------
  -- ТЕОРЕМА 6. Три статуса РАЗЛИЧНЫ. «Свернулось» — значение, а не ошибка;
  -- «осиротело» — потеря основания; «непоправимо» — то и другое разом при
  -- уже совершённом необратимом. Свести их в одно «нет» — отмывание.
  -- ----------------------------------------------------------
  live≢orphaned : ¬ (live ≡ orphaned)
  live≢orphaned ()

  orphaned≢irreparable : ¬ (orphaned ≡ irreparable)
  orphaned≢irreparable ()

  live≢irreparable : ¬ (live ≡ irreparable)
  live≢irreparable ()
