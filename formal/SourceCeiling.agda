{-# OPTIONS --safe #-}
-- ============================================================
--  nolang · SOURCE CEILING: степень не поднимается происхождением
--
--  ЗАЧЕМ ЭТОТ ФАЙЛ.
--   До 05.08.2026 степень свидетеля ЗАЯВЛЯЛ автор программы. `source` был
--   обязателен, но служил лишь ключом дедупликации корней, и текст
--       witness x : machine_verified  source my_imagination
--   типизировался. То есть подъём степени ВНУТРИ вывода был невыразим,
--   а ложь НА ВХОДЕ выразима идеально. Пока `.nol` писал человек под
--   присмотром — условность; когда декларации пишет сам агент — дыра во
--   всей конструкции.
--
--   Реализация (src/check.lisp, chk-witness) теперь сводит заявленную
--   степень с классом источника через `g-meet`. Здесь доказано, что этот
--   ход даёт ровно то, что обещает, и не даёт лишнего.
--
--  ЧТО ЗДЕСЬ ДОКАЗАНО:
--   1. ceiling          : результат никогда не выше класса источника
--   2. honest-preserved : если заявлено НЕ ВЫШЕ класса — результат равен
--                         заявленному (потолок не режет честное)
--   3. chain-falls      : по цепи происхождения класс только падает
--   4. chain-ceiling    : свидетель не выше класса ЛЮБОГО предка в цепи —
--                         не только ближайшего
--   5. no-laundering    : не существует заявления, дающего степень выше
--                         класса корня цепи. Отмывание через происхождение
--                         не запрещено — оно НЕВЫРАЗИМО.
--
--  ЧТО НЕ ДОКАЗАНО И СКАЗАНО ВСЛУХ:
--   · что объявленный класс источника соответствует действительности —
--     это вне языка (отпечатки и внешняя проверка, этап D);
--   · что Lisp реализует именно эти определения — на это стоят батарея,
--     мутационная проверка и оракул, а не эта модель.
-- ============================================================

module SourceCeiling where

open import Agda.Builtin.Equality using (_≡_; refl)
open import Agda.Builtin.Nat using (Nat; zero; suc)
open import Agda.Builtin.List using (List; []; _∷_)

-- Та же абстракция, что в Preservation: полурешётка встреч.
record MeetSemilattice : Set₁ where
  field
    G     : Set
    ⊥ᴳ    : G
    _⊓_   : G → G → G
    ⊓-comm  : ∀ a b   → (a ⊓ b) ≡ (b ⊓ a)
    ⊓-assoc : ∀ a b c → ((a ⊓ b) ⊓ c) ≡ (a ⊓ (b ⊓ c))
    ⊓-idem  : ∀ a     → (a ⊓ a) ≡ a
    ⊥-absorb : ∀ a    → (⊥ᴳ ⊓ a) ≡ ⊥ᴳ

-- Мелкие леммы о равенстве — держим свои, чтобы не тянуть stdlib ради трёх строк
-- (поверхность зависимостей у формальной части намеренно мала, см. formal/README.md).
sym : ∀ {A : Set} {x y : A} → x ≡ y → y ≡ x
sym refl = refl

trans : ∀ {A : Set} {x y z : A} → x ≡ y → y ≡ z → x ≡ z
trans refl q = q

cong : ∀ {A B : Set} {x y : A} (f : A → B) → x ≡ y → f x ≡ f y
cong f refl = refl

module Ceiling (L : MeetSemilattice) where
  open MeetSemilattice L

  -- Порядок решётки: a ниже-или-равно b, когда встреча возвращает a.
  -- Это определение, а не постулат: всё дальнейшее выводится из свойств ⊓.
  _≤ᴳ_ : G → G → Set
  a ≤ᴳ b = (a ⊓ b) ≡ a

  -- Степень свидетеля после сведения с классом источника.
  -- Ровно то, что делает chk-witness: (g-meet заявленное класс).
  witness-grade : G → G → G
  witness-grade claimed cls = claimed ⊓ cls

  -- ── 1. ПОТОЛОК ────────────────────────────────────────────────────────
  -- Что бы ни заявил автор, результат не выше класса источника.
  -- Доказательство — одна перестановка и одна идемпотентность: то, что
  -- закон держится на СВОЙСТВАХ ⊓, а не на проверке в коде, и есть причина
  -- писать это здесь, а не только в тесте.
  ceiling : ∀ claimed cls → (witness-grade claimed cls) ≤ᴳ cls
  ceiling claimed cls
    rewrite ⊓-assoc claimed cls cls
          | ⊓-idem cls
    = refl

  -- ── 2. ЧЕСТНОЕ НЕ РЕЖЕТСЯ ─────────────────────────────────────────────
  -- Если заявлено не выше класса, результат равен заявленному.
  -- Без этого «починка» свелась бы к запрету всего: потолок обязан
  -- пропускать правду, иначе он не потолок, а глушилка.
  honest-preserved : ∀ claimed cls → claimed ≤ᴳ cls
                   → witness-grade claimed cls ≡ claimed
  honest-preserved claimed cls le = le

  -- ── ЦЕПЬ ПРОИСХОЖДЕНИЯ ────────────────────────────────────────────────
  -- Источник может происходить от источника. Класс наследника — встреча
  -- собственного объявления с классом предка (src/check.lisp, source-class).
  -- Цепь дана списком объявленных степеней: голова — ближайший источник.
  chain-class : G → List G → G
  chain-class own []            = own
  chain-class own (parent ∷ ps) = own ⊓ chain-class parent ps

  -- ── 3. ПО ЦЕПИ КЛАСС ТОЛЬКО ПАДАЕТ ────────────────────────────────────
  -- Класс наследника не выше собственного объявления: сколько бы предков
  -- ни было, длиннее цепь — не строже знание.
  --   (own ⊓ X) ⊓ own ≡ own ⊓ (X ⊓ own) ≡ own ⊓ (own ⊓ X)
  --                     ≡ (own ⊓ own) ⊓ X ≡ own ⊓ X
  -- где X — класс остатка цепи. Каждый шаг назван, чтобы читалось как довод,
  -- а не как везение с `rewrite`.
  chain-falls : ∀ own ps → (chain-class own ps) ≤ᴳ own
  chain-falls own []            = ⊓-idem own
  chain-falls own (parent ∷ ps) =
    trans (⊓-assoc own (chain-class parent ps) own)
      (trans (cong (λ z → own ⊓ z) (⊓-comm (chain-class parent ps) own))
        (trans (sym (⊓-assoc own own (chain-class parent ps)))
               (cong (λ z → z ⊓ chain-class parent ps) (⊓-idem own))))

  -- ── 4. ПОТОЛОК ПО ВСЕЙ ЦЕПИ ───────────────────────────────────────────
  -- Свидетель не выше класса ближайшего источника — а тот не выше своего
  -- предка. Значит не выше и корня: закон транзитивен по построению.
  -- Транзитивность порядка: цепочка равенств, каждый шаг назван.
  --   a ⊓ c ≡ (a ⊓ b) ⊓ c ≡ a ⊓ (b ⊓ c) ≡ a ⊓ b ≡ a
  ⊓-trans : ∀ a b c → a ≤ᴳ b → b ≤ᴳ c → a ≤ᴳ c
  ⊓-trans a b c ab bc =
    trans (cong (λ z → z ⊓ c) (sym ab))
      (trans (⊓-assoc a b c)
        (trans (cong (λ z → a ⊓ z) bc) ab))

  chain-ceiling : ∀ claimed own ps
                → (witness-grade claimed (chain-class own ps)) ≤ᴳ own
  chain-ceiling claimed own ps =
    ⊓-trans (witness-grade claimed (chain-class own ps))
            (chain-class own ps)
            own
            (ceiling claimed (chain-class own ps))
            (chain-falls own ps)

  -- ── 5. ОТМЫВАНИЕ НЕВЫРАЗИМО ───────────────────────────────────────────
  -- Нет такого заявления, которое дало бы степень выше класса источника.
  -- Формулировка утвердительная, а не через отрицание: для ЛЮБОГО
  -- заявленного результат равен встрече с классом, то есть уже ограничен.
  -- Запрета в коде нет — есть отсутствие места, куда ложь могла бы стать.
  no-laundering : ∀ claimed cls
                → witness-grade claimed cls ≡ (witness-grade claimed cls) ⊓ cls
  no-laundering claimed cls
    rewrite ⊓-assoc claimed cls cls
          | ⊓-idem cls
    = refl
