{-# OPTIONS --safe #-}
-- ============================================================
--  nolang · GATE: единственное место, где язык совершает необратимое
--
--  ЗАЧЕМ ЭТОТ ФАЙЛ ПОЯВИЛСЯ ПОСЛЕДНИМ, ХОТЯ ДОЛЖЕН БЫЛ ПЕРВЫМ.
--   Карта покрытия (README, 06.08.2026) показала вещь, которую десять модулей Agda
--   заслоняли числом: формальная часть покрывает СТЕПЕНИ и ДЕЙСТВИЯ, а **гейт не доказан
--   вовсе**. Гейт — то место, где вычисление перестаёт быть вычислением и становится
--   поступком: после него `publish` уже случился. Всё прочее в языке можно переиграть,
--   это — нельзя.
--
--   Десять модулей и 927 проверок стояли вокруг двери, которую никто не проверил.
--
--  ЧТО ЗДЕСЬ ДОКАЗАНО (соответствует `src/gate.lisp` дословно):
--   ⟦содержательное⟧  irreversible-needs-yes : необратимое разрешено ТОЛЬКО при confident-yes
--   ⟦содержательное⟧  low-confidence-ignores-belief : 🔴 при нехватке УВЕРЕННОСТИ величина
--                     ВЕРЫ не влияет ни на что — незнание не компенсируется убеждённостью
--   ⟦содержательное⟧  confidence-monotone : рост уверенности не отменяет уже принятого «да»
--   ⟦содержательное⟧  fold-first-is-not-denial : неопределённость ПОНИЖАЕТ класс действия,
--                     а не запрещает его — отказ есть значение, а не крах
--   ⟦определительное⟧ trichotomy / reversible-always-allowed
--
--  🔴 ЧЕГО ЗДЕСЬ НЕТ. Не доказано, что порог θ выбран ПРАВИЛЬНО — это вопрос о мире, а не о
--  вычислении, и он остаётся за человеком (и за предрегистрацией θ в прелюдии). Доказано
--  только, что объявленный порог соблюдается и что его нельзя обойти верой.
--
--  Носитель — натуральные (уверенность и вера в сотых долях), как в `CredalBound`: сравнение
--  дробей с общим знаменателем есть сравнение числителей, и вещественные здесь не нужны.
-- ============================================================

module Gate where

open import Agda.Builtin.Equality using (_≡_; refl)
open import Agda.Builtin.Nat using (Nat; zero; suc)

data ⊥ : Set where

-- ⟦определение⟧
¬_ : Set → Set
¬ A = A → ⊥

data Bool : Set where
  true false : Bool

-- «меньше» и «не меньше» на натуральных, решающе
-- ⟦определение⟧
_<?_ : Nat → Nat → Bool
zero  <? zero  = false
zero  <? suc _ = true
suc _ <? zero  = false
suc a <? suc b = a <? b

-- ⟦определение⟧
_≤?_ : Nat → Nat → Bool
zero  ≤? _     = true
suc _ ≤? zero  = false
suc a ≤? suc b = a ≤? b

-- ── ИСХОД ГЕЙТА ─────────────────────────────────────────────────────────────
data Outcome : Set where
  confident-yes confident-no undecided : Outcome

-- Дословно `outcome` из gate.lisp: сперва смотрим УВЕРЕННОСТЬ, и только если её хватает —
-- ВЕРУ. Порядок ветвей здесь несёт смысл, а не стиль: он и есть содержание теоремы 2.
-- ⟦определение⟧
outcome : (θ half c f : Nat) → Outcome
outcome θ half c f with c <? θ
... | true  = undecided
... | false with half ≤? f
...   | true  = confident-yes
...   | false = confident-no

-- ── ПРАВО НА ДЕЙСТВИЕ ───────────────────────────────────────────────────────
data Class : Set where
  reversible irreversible : Class

data Permission : Set where
  allowed fold-first denied : Permission

-- ⟦определение⟧
permit : Class → Outcome → Permission
permit reversible   _             = allowed
permit irreversible confident-yes = allowed
permit irreversible undecided     = fold-first
permit irreversible confident-no  = denied

-- ── 1. НЕОБРАТИМОЕ ТРЕБУЕТ УВЕРЕННОГО «ДА» ──────────────────────────────────
-- Обратное направление тоже верно и тривиально; ценность в ЭТОМ: из разрешения следует
-- уверенное да, то есть разрешение нельзя получить ничем другим.
-- ⟦содержательное⟧
irreversible-needs-yes : ∀ o → permit irreversible o ≡ allowed → o ≡ confident-yes
irreversible-needs-yes confident-yes _  = refl
irreversible-needs-yes confident-no  ()
irreversible-needs-yes undecided     ()

-- ── 2. 🔴 НЕЗНАНИЕ НЕ КОМПЕНСИРУЕТСЯ УБЕЖДЁННОСТЬЮ ──────────────────────────
-- Если уверенности не хватает (c < θ), то исход ОДИН И ТОТ ЖЕ при любой вере: сколь угодно
-- сильное «я убеждён» не переводит гейт в «да». Это главное свойство конструкции и,
-- пожалуй, главная причина, по которой гейт смотрит на пару (f,c), а не на их произведение:
-- в произведении низкая уверенность ЗАМЕЩАЕТСЯ высокой верой, и различие исчезает.
-- ⟦содержательное⟧
low-confidence-ignores-belief :
  ∀ θ half c f₁ f₂ → (c <? θ) ≡ true → outcome θ half c f₁ ≡ outcome θ half c f₂
low-confidence-ignores-belief θ half c f₁ f₂ p with c <? θ
low-confidence-ignores-belief θ half c f₁ f₂ refl | true = refl

-- ── 3. РОСТ УВЕРЕННОСТИ НЕ ОТМЕНЯЕТ «ДА» ────────────────────────────────────
-- Гейт монотонен по уверенности: если при данной c он сказал «да», то и при большей c
-- скажет «да» — вера не менялась. Немонотонный гейт был бы неустойчив к добавлению
-- свидетельств: собрал больше данных — потерял разрешение.
-- ⟦содержательное⟧
confidence-monotone :
  ∀ θ half c c′ f
  → (c <? θ) ≡ false → (c′ <? θ) ≡ false
  → outcome θ half c f ≡ confident-yes
  → outcome θ half c′ f ≡ confident-yes
confidence-monotone θ half c c′ f pc pc′ eq with c <? θ | c′ <? θ
confidence-monotone θ half c c′ f refl refl eq | false | false = eq

-- ── 4. НЕОПРЕДЕЛЁННОСТЬ ПОНИЖАЕТ КЛАСС, А НЕ ЗАПРЕЩАЕТ ──────────────────────
-- `fold-first` ≠ `denied`. Различие несущее: при неопределённости действие не запрещается,
-- а СВОРАЧИВАЕТСЯ до обратимого (снимок, потом обратимая часть). Отказ здесь — значение с
-- недостачей, а не крах; язык заведён ровно на этом различении.
-- ⟦содержательное⟧
fold-first-is-not-denial : ¬ (fold-first ≡ denied)
fold-first-is-not-denial ()

-- ⟦определительное⟧
undecided-folds : permit irreversible undecided ≡ fold-first
undecided-folds = refl

-- ── 5. ОБРАТИМОЕ ПРОХОДИТ ВСЕГДА ────────────────────────────────────────────
-- Верно по определению, и записано ради границы: гейт стережёт НЕОБРАТИМОЕ. Обратимое
-- действие не нуждается в разрешении, потому что его можно отменить — цена ошибки конечна.
-- ⟦определительное⟧
reversible-always-allowed : ∀ o → permit reversible o ≡ allowed
reversible-always-allowed confident-yes = refl
reversible-always-allowed confident-no  = refl
reversible-always-allowed undecided     = refl

-- ── 6. ТРИХОТОМИЯ ИСХОДОВ ───────────────────────────────────────────────────
-- Три исхода различимы попарно. Это свойство ОПРЕДЕЛЕНИЯ (конструкторы разных ветвей),
-- и сказано так, чтобы не выдать конструкцию за доказательство — счёт теорем в этом
-- проекте уже трижды оказывался завышен.
-- ⟦определительное⟧
yes≢no : ¬ (confident-yes ≡ confident-no)
yes≢no ()

-- ⟦определительное⟧
yes≢undecided : ¬ (confident-yes ≡ undecided)
yes≢undecided ()

-- ⟦определительное⟧
no≢undecided : ¬ (confident-no ≡ undecided)
no≢undecided ()
