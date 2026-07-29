-- ============================================================
--  nolang · ОРАКУЛ: доказанная модель, собранная в исполнимое
--
--  ЗАЧЕМ ЭТО, А НЕ ЕЩЁ ОДИН ТЕСТ (название и довод — Невис, 28.07).
--   Дифференциальный тест `chk-claim` против `red-claim` сравнивает ДВЕ НЕПРОВЕРЕННЫЕ
--   реализации: он ловит расхождение, но не ловит общую ошибку обеих. Если же одну
--   сторону взять из Agda, где степень ДОКАЗАНА, природа теста меняется: это уже
--   проверка реализации ПРОТИВ ДОКАЗАННОГО. Общая ошибка становится невозможной
--   с той стороны, где доказано.
--
--  🔴 ЧТО ЭТОТ ФАЙЛ НЕ ДЕЛАЕТ И НЕ ПРИТВОРЯЕТСЯ, ЧТО ДЕЛАЕТ.
--   1. Он НЕ доказывает эквивалентность Лиспа и модели. Он ограничивает расхождение
--      ЧИСЛОМ ИСПЫТАНИЙ. Тысяча совпавших прогонов — это тысяча совпавших прогонов.
--   2. Модель считает СТЕПЕНЬ (T-CLAIM + отзыв), и только её. Свёртка по корням, вес,
--      квантор, гейт, журнал — вне модели, и харнесс обязан подавать программы,
--      на которых эти черты не срабатывают (у каждого свидетеля свой корень).
--   3. Здесь есть `postulate` — четыре штуки, все на ввод-вывод. Доказанные модули
--      (`formal/*.agda`) остаются `--safe` и с нулём постулатов; этот файл НЕ входит
--      в их число и НЕ лежит в `formal/`, чтобы батарея его не считала теоремами.
--   4. Законы решётки здесь ДОКАЗАНЫ (min-comm/assoc/idem и подъём их на кортежи),
--      а не постулированы: иначе оракул стоял бы на песке, а выглядел бы как скала.
--
--  Сборка: oracle/build.sh   ·   Протокол ввода-вывода: см. §3.
-- ============================================================

module Oracle where

open import Agda.Builtin.Equality using (_≡_; refl)
open import Agda.Builtin.Nat using (Nat; zero; suc; _+_; _*_; _-_)
open import Agda.Builtin.Bool using (Bool; true; false)
open import Agda.Builtin.List using (List; []; _∷_)
open import Agda.Builtin.Char using (Char; primCharToNat)
open import Agda.Builtin.String using (String; primStringToList; primStringAppend)
open import Agda.Builtin.IO using (IO)
open import Agda.Builtin.Unit using (⊤)

-- `module Core` — именно так, со словом `module`: в списке `using` подмодуль
-- называется иначе, чем значение, и без этого слова Agda его не видит.
open import Preservation using (MeetSemilattice; module Core)

sucCong : ∀ {x y : Nat} → x ≡ y → suc x ≡ suc y
sucCong refl = refl

-- ------------------------------------------------------------
-- 1. КОНКРЕТНАЯ РЕШЁТКА: кортеж индексов, грань покомпонентно
--
--    Ровно то, что делает `g-meet-in` в src/common.lisp: на линейной решётке —
--    минимум по положению, на произведении — покомпонентно. Кортеж записываем
--    списком; ДНО — пустой список.
--
--    🔴 Почему дно именно `[]`, а не «все нули». Закон решётки требует `⊥ ⊓ a = ⊥`
--    для ЛЮБОГО a. При «всех нулях» это верно лишь для кортежей той же длины — то есть
--    закон пришлось бы доказывать при внешнем условии, которого в записи решётки нет.
--    Пустой список поглощает всё первым же уравнением `mt`, и закон выходит без оговорок.
--    Соответствие с Лиспом от этого не страдает: у нолanga дно линейной решётки —
--    нулевой индекс, у произведения — все нулевые, и харнесс читает `[]` как «дно».
--    Иных длин в прогоне не возникает: грань двух кортежей длины n снова длины n.
-- ------------------------------------------------------------

min : Nat → Nat → Nat
min zero    _       = zero
min (suc _) zero    = zero
min (suc a) (suc b) = suc (min a b)

min-comm : ∀ a b → min a b ≡ min b a
min-comm zero    zero    = refl
min-comm zero    (suc _) = refl
min-comm (suc _) zero    = refl
min-comm (suc a) (suc b) = sucCong (min-comm a b)

min-assoc : ∀ a b c → min (min a b) c ≡ min a (min b c)
min-assoc zero    _       _       = refl
min-assoc (suc _) zero    _       = refl
min-assoc (suc _) (suc _) zero    = refl
min-assoc (suc a) (suc b) (suc c) = sucCong (min-assoc a b c)

min-idem : ∀ a → min a a ≡ a
min-idem zero    = refl
min-idem (suc a) = sucCong (min-idem a)

Tuple : Set
Tuple = List Nat

mt : Tuple → Tuple → Tuple
mt []       _        = []
mt (_ ∷ _)  []       = []
mt (x ∷ xs) (y ∷ ys) = min x y ∷ mt xs ys

consCong : ∀ {x y : Nat} {xs ys : Tuple} → x ≡ y → xs ≡ ys → (x ∷ xs) ≡ (y ∷ ys)
consCong refl refl = refl

mt-comm : ∀ a b → mt a b ≡ mt b a
mt-comm []       []       = refl
mt-comm []       (_ ∷ _)  = refl
mt-comm (_ ∷ _)  []       = refl
mt-comm (x ∷ xs) (y ∷ ys) = consCong (min-comm x y) (mt-comm xs ys)

mt-assoc : ∀ a b c → mt (mt a b) c ≡ mt a (mt b c)
mt-assoc []       _        _        = refl
mt-assoc (_ ∷ _)  []       _        = refl
mt-assoc (_ ∷ _)  (_ ∷ _)  []       = refl
mt-assoc (x ∷ xs) (y ∷ ys) (z ∷ zs) = consCong (min-assoc x y z) (mt-assoc xs ys zs)

mt-idem : ∀ a → mt a a ≡ a
mt-idem []       = refl
mt-idem (x ∷ xs) = consCong (min-idem x) (mt-idem xs)

mt-bot : ∀ a → mt [] a ≡ []
mt-bot _ = refl

-- Экземпляр решётки. Все четыре закона доказаны выше — оракул стоит на той же земле,
-- что и теоремы, а не на честном слове.
LAT : MeetSemilattice
LAT = record
  { G = Tuple ; ⊥ᴳ = [] ; _⊓_ = mt
  ; ⊓-comm = mt-comm ; ⊓-assoc = mt-assoc ; ⊓-idem = mt-idem ; ⊥-absorb = mt-bot }

open Core LAT using (Premise; wit; sil; chk; red)

-- ------------------------------------------------------------
-- 2. Ввод-вывод (единственное место с постулатами)
-- ------------------------------------------------------------

postulate
  getContents : IO String
  putStr      : String → IO ⊤
  natToStr    : Nat → String
  _>>=_       : {A B : Set} → IO A → (A → IO B) → IO B

{-# FOREIGN GHC import qualified Data.Text    as T #-}
{-# FOREIGN GHC import qualified Data.Text.IO as TIO #-}
{-# COMPILE GHC getContents = TIO.getContents #-}
{-# COMPILE GHC putStr      = TIO.putStr #-}
{-# COMPILE GHC natToStr    = T.pack . show #-}
{-# COMPILE GHC _>>=_       = \_ _ -> (>>=) #-}

-- ------------------------------------------------------------
-- 3. ПРОТОКОЛ. Вход — поток целых, разделённых чем угодно нецифровым. Одна задача:
--
--      n            арность решётки (1 — линейная, k — произведение k частей)
--      k            сколько посылок
--      k раз:  вид  (0 — свидетель, иначе молчание)
--              id
--              если свидетель: n индексов степени
--      d            сколько отозванных
--      d раз:  id
--
--    Задачи идут подряд; кончился поток — кончилась работа. На каждую печатается строка
--      <длина> <значения…> | <длина> <значения…>
--    слева — проверяющий (`chk`), справа — машина (`red`). Дно печатается как длина 0.
--
--    🔴 Печатаются ОБА, хотя `preservation` доказывает их равенство. Именно поэтому и
--    печатаются: доказанное равенство становится видимым в выводе, а не только в файле
--    с доказательством. Если они когда-нибудь разойдутся в собранном виде — значит
--    сломалась сборка, и это надо увидеть глазами, а не предполагать.
-- ------------------------------------------------------------

len : {A : Set} → List A → Nat
len []       = zero
len (_ ∷ xs) = suc (len xs)

_≤ᴺ_ : Nat → Nat → Bool
zero  ≤ᴺ _     = true
suc _ ≤ᴺ zero  = false
suc a ≤ᴺ suc b = a ≤ᴺ b

_&&_ : Bool → Bool → Bool
true  && b = b
false && _ = false

isDig : Nat → Bool
isDig c = (48 ≤ᴺ c) && (c ≤ᴺ 57)

ifL : {A : Set} → Bool → A → A → A
ifL true  t _ = t
ifL false _ f = f

-- ── лексер: поток символов → список чисел ──
mutual
  scan : List Char → Nat → Bool → List Nat
  scan []       acc inN = ifL inN (acc ∷ []) []
  scan (c ∷ cs) acc inN = step (isDig (primCharToNat c)) (primCharToNat c) cs acc inN

  step : Bool → Nat → List Char → Nat → Bool → List Nat
  step true  v cs acc _   = scan cs (acc * 10 + (v - 48)) true
  step false _ cs acc inN = ifL inN (acc ∷ scan cs zero false) (scan cs zero false)

nats : String → List Nat
nats s = scan (primStringToList s) zero false

takeN : Nat → List Nat → List Nat
takeN zero    _        = []
takeN (suc _) []       = []
takeN (suc k) (x ∷ xs) = x ∷ takeN k xs

dropN : Nat → List Nat → List Nat
dropN zero    xs       = xs
dropN (suc _) []       = []
dropN (suc k) (_ ∷ xs) = dropN k xs

record Pair (A B : Set) : Set where
  constructor _,_
  field
    fst : A
    snd : B
open Pair

-- ── разбор посылок ──
readPrems : Nat → Nat → List Nat → Pair (List Premise) (List Nat)
readPrems _ zero    xs = [] , xs
readPrems _ (suc _) [] = [] , []
readPrems _ (suc _) (_ ∷ []) = [] , []
readPrems n (suc k) (zero ∷ i ∷ rest) =
  (wit i (takeN n rest) ∷ fst nxt) , snd nxt
  where nxt = readPrems n k (dropN n rest)
readPrems n (suc k) (suc _ ∷ i ∷ rest) =
  (sil i ∷ fst nxt) , snd nxt
  where nxt = readPrems n k rest

showList : List Nat → String
showList []       = ""
showList (x ∷ xs) = primStringAppend (natToStr x) (primStringAppend " " (showList xs))

showT : Tuple → String
showT t = primStringAppend (natToStr (len t)) (primStringAppend " " (showList t))

-- ── прогон всех задач. ТОПЛИВО — не украшение: без него завершаемость не видна
--    проверяющему, а обещать её на слово в этом языке не принято. Топлива берём
--    ровно длину входа: каждая задача съедает не меньше двух чисел. ──
runAll : Nat → List Nat → String
runAll zero    _              = ""
runAll (suc _) []             = ""
runAll (suc _) (_ ∷ [])       = ""
runAll (suc f) (n ∷ k ∷ rest) = tail (snd pr)
  where
    pr : Pair (List Premise) (List Nat)
    pr = readPrems n k rest

    line : List Nat → String
    line d = primStringAppend
               (showT (chk d (fst pr)))
               (primStringAppend "| "
                 (primStringAppend (showT (red d (fst pr)))
                   (primStringAppend "\n" (runAll f (dropN (len d) (dropN 1 (snd pr)))))))

    tail : List Nat → String
    tail []        = ""
    tail (d ∷ ds)  = line (takeN d ds)

main : IO ⊤
main = getContents >>= λ s → putStr (runAll (len (nats s)) (nats s))
