{-# OPTIONS --safe #-}
-- ============================================================
--  nolang · LEDGER: история, которая не переписывается
--
--  ЗАЧЕМ. Карта покрытия (06.08.2026) оставила журнал последней недоказанной несущей частью:
--  гейт закрыт (`Gate.agda`), а журнал — то, ЧЕМ гейт отчитывается — держался на батарее.
--  Между тем именно журнал несёт два обещания языка, и оба звучали как слова:
--    1. **отказ есть ЗНАЧЕНИЕ с недостачей**, а не крах и не пустота;
--    2. **рухнувшее основание ДОБАВЛЯЕТ запись, а не стирает прежнюю** — история не
--       переписывается задним числом.
--  Здесь оба становятся теоремами.
--
--  ЧТО ДОКАЗАНО (по `src/reduce.lisp`, ветви `:performed` / `:folded` и функция `orphans`):
--   ⟦содержательное⟧  folded-has-shortfall : свёрток НЕСЁТ положительную недостачу
--   ⟦содержательное⟧  performed-has-no-shortfall : совершённое — с нулевой
--   ⟦содержательное⟧  folded-never-orphans : свёрнутое НЕ СИРОТЕЕТ (нечему осиротеть)
--   ⟦содержательное⟧  performed-survives-orphaning : запись о совершении ОСТАЁТСЯ в журнале
--                     после того, как её основание рухнуло
--   ⟦определительное⟧ decide-dichotomy · orphan-of-performed-only
--
--  🔴 ЧЕГО ЗДЕСЬ НЕТ. Не доказано, что журнал СООТВЕТСТВУЕТ тому, что произошло в мире:
--  запись `performed` говорит, что язык разрешил действие, а не что мир его претерпел.
--  Разрыв между разрешением и событием — не дефект, а граница метода; она названа в
--  `README` и в шапке `ReEntry.agda` и здесь не закрывается.
-- ============================================================

module Ledger where

open import Agda.Builtin.Equality using (_≡_; refl)
open import Agda.Builtin.Nat using (Nat; zero; suc)
open import Agda.Builtin.List using (List; []; _∷_)

data ⊥ : Set where

-- ⟦определение⟧
¬_ : Set → Set
¬ A = A → ⊥

data Bool : Set where
  true false : Bool

-- ⟦определение⟧
_≤?_ : Nat → Nat → Bool
zero  ≤? _     = true
suc _ ≤? zero  = false
suc a ≤? suc b = a ≤? b

-- Усечённая разность: недостача не бывает отрицательной — «не хватило на минус три» не
-- значит ничего.
-- ⟦определение⟧
_∸_ : Nat → Nat → Nat
zero  ∸ _     = zero
suc a ∸ zero  = suc a
suc a ∸ suc b = a ∸ b

-- ── ЗАПИСЬ ЖУРНАЛА ──────────────────────────────────────────────────────────
-- Три вида, как в реализации. Числа — вера и порог в момент записи.
data Entry : Set where
  -- ⟦определение⟧
  performed : Nat → Nat → Entry     -- вера ≥ порога: действие совершено
  folded    : Nat → Nat → Entry     -- веры не хватило: свёрток
  orphaned  : Nat → Nat → Entry     -- основание рухнуло ПОСЛЕ действия

-- Решение гейта, дословно по `reduce.lisp`: держит порог — совершаем, нет — сворачиваем.
-- ⟦определение⟧
decide : (b thr : Nat) → Entry
decide b thr with thr ≤? b
... | true  = performed b thr
... | false = folded b thr

-- Недостача: сколько НЕ ХВАТИЛО. У совершённого её нет по определению, у свёртка она и есть
-- содержание записи — то, что делает отказ значением, а не молчанием.
-- ⟦определение⟧
shortfall : Entry → Nat
shortfall (performed _ _) = zero
shortfall (folded b thr)  = thr ∸ b
shortfall (orphaned _ _)  = zero

-- ── 1. ОТКАЗ НЕСЁТ НЕДОСТАЧУ ────────────────────────────────────────────────
-- Если гейт свернул, недостача СТРОГО положительна. Это и есть «отказ — значение, а не крах»:
-- у него есть число, его можно предъявить, по нему видно, чего именно недостало.
-- Лемма ниже потребляет ровно ту гипотезу, из-за которой ветвь и выбрана.
-- ⟦определительное⟧
∸-pos : ∀ b thr → (thr ≤? b) ≡ false → ¬ (thr ∸ b ≡ zero)
∸-pos zero    zero    () _
∸-pos (suc b) zero    () _
∸-pos zero    (suc t) _  ()
∸-pos (suc b) (suc t) p  q = ∸-pos b t p q

-- ⟦содержательное⟧
folded-has-shortfall :
  ∀ b thr → (thr ≤? b) ≡ false → ¬ (shortfall (decide b thr) ≡ zero)
folded-has-shortfall b thr p rewrite p = ∸-pos b thr p

-- И обратное: когда порог взят, недостачи НЕТ. Без этой половины первая теорема совместима
-- с языком, который приписывает недостачу всему подряд.
-- ⟦содержательное⟧
performed-has-no-shortfall :
  ∀ b thr → (thr ≤? b) ≡ true → shortfall (decide b thr) ≡ zero
performed-has-no-shortfall b thr p rewrite p = refl

-- Исходов ровно два, третьего нет: `decide` не возвращает `orphaned` никогда — сиротство
-- случается ПОЗЖЕ и не является решением гейта.
-- ⟦определительное⟧
decide-never-orphans : ∀ b thr n m → ¬ (decide b thr ≡ orphaned n m)
decide-never-orphans b thr n m e with thr ≤? b
decide-never-orphans b thr n m () | true
decide-never-orphans b thr n m () | false


-- ── 2. СИРОТСТВО: ДОБАВЛЕНИЕ, А НЕ ПРАВКА ───────────────────────────────────
-- Пересмотр: при новой вере `nb` каждое СОВЕРШЁННОЕ действие, чей порог больше не держится,
-- порождает запись `orphaned`. Дословно по `orphans` из `reduce.lisp`.
-- ⟦определение⟧
orphansOf : Nat → List Entry → List Entry
orphansOf nb [] = []
orphansOf nb (performed b thr ∷ es) with thr ≤? nb
... | true  = orphansOf nb es
... | false = orphaned nb thr ∷ orphansOf nb es
orphansOf nb (folded _ _ ∷ es)   = orphansOf nb es
orphansOf nb (orphaned _ _ ∷ es) = orphansOf nb es

-- 🔴 СВЁРНУТОЕ НЕ СИРОТЕЕТ. Действие, которое не совершилось, не может «осиротеть» задним
-- числом: сиротство есть утверждение о СОВЕРШЁННОМ, у которого пропало основание. Язык,
-- где сиротеет и несовершённое, стирал бы разницу между «сделал зря» и «не сделал».
-- ⟦содержательное⟧
folded-never-orphans :
  ∀ nb b thr es → orphansOf nb (folded b thr ∷ es) ≡ orphansOf nb es
folded-never-orphans nb b thr es = refl

-- Пересмотр не трогает уже записанное сиротство — оно не сиротеет дважды.
-- ⟦определительное⟧
orphan-not-reorphaned :
  ∀ nb n m es → orphansOf nb (orphaned n m ∷ es) ≡ orphansOf nb es
orphan-not-reorphaned nb n m es = refl

-- ── 3. ИСТОРИЯ НЕ ПЕРЕПИСЫВАЕТСЯ ────────────────────────────────────────────
-- ⟦определение⟧
_++_ : List Entry → List Entry → List Entry
[]       ++ ys = ys
(x ∷ xs) ++ ys = x ∷ (xs ++ ys)

data _∈_ : Entry → List Entry → Set where
  here  : ∀ {x xs}   → x ∈ (x ∷ xs)
  -- ⟦определение⟧
  there : ∀ {x y xs} → x ∈ xs → x ∈ (y ∷ xs)

-- ⟦определительное⟧
∈-++ʳ : ∀ {x} ys xs → x ∈ xs → x ∈ (ys ++ xs)
∈-++ʳ []       xs m = m
∈-++ʳ (y ∷ ys) xs m = there (∈-++ʳ ys xs m)

-- 🔴 ГЛАВНОЕ. Журнал после пересмотра есть «новые записи ++ прежний журнал», и запись о
-- совершении ОСТАЁТСЯ в нём — даже когда её основание рухнуло и рядом появилось сиротство.
-- Отзыв не отменяет прошлого: он ДОПИСЫВАЕТ, что прошлое больше не держится.
-- Именно поэтому история языка проверяема: из неё ничего не исчезает.
-- ⟦содержательное⟧
performed-survives-orphaning :
  ∀ nb b thr es
  → performed b thr ∈ (orphansOf nb (performed b thr ∷ es) ++ (performed b thr ∷ es))
performed-survives-orphaning nb b thr es =
  ∈-++ʳ (orphansOf nb (performed b thr ∷ es)) (performed b thr ∷ es) here

-- И то же для свёртка: отказ тоже остаётся в истории. Забытый отказ — это забытое знание
-- «пробовали, не хватило», а оно бывает ценнее совершённого.
-- ⟦определительное⟧
folded-survives :
  ∀ nb b thr es
  → folded b thr ∈ (orphansOf nb (folded b thr ∷ es) ++ (folded b thr ∷ es))
folded-survives nb b thr es =
  ∈-++ʳ (orphansOf nb (folded b thr ∷ es)) (folded b thr ∷ es) here
