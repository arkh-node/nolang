# formal/ — the machine-checked part

Seven modules, all under `--safe`: no postulates, no holes, no `{-# TERMINATING #-}`.
Nothing here is trusted because it was written carefully; it is trusted because Agda rebuilt it.

## What you need

| | |
|---|---|
| **Agda** | 2.6.4.3 (the version this is checked with; 2.6.4.x should be fine) |
| **standard library** | `standard-library` registered in `~/.agda/libraries` and listed in `~/.agda/defaults` |

Only these stdlib modules are used — the surface is deliberately small:

```
Agda.Builtin.{Bool, Equality, List, Nat}
Data.Nat · Data.Nat.Properties · Data.Product
Relation.Binary.PropositionalEquality · Relation.Nullary
```

On Debian/Ubuntu the library usually lands at
`/usr/share/agda-stdlib/standard-library.agda-lib`; check with `cat ~/.agda/libraries`.

## How to check it

```bash
cd formal
rm -f *.agdai                 # 🔴 without this you are checking the cache, not the file
for a in *.agda; do agda --safe "$a"; done
```

`./run_tests.sh` in the repository root does exactly this and reports a missing Agda as a
**failure**, not as a pass. Verified from a fresh clone on 05.08.2026: all seven modules build
from scratch, `.agdai` is gitignored and absent from the published tree.

## The modules

| module | what it carries |
|---|---|
| `Preservation.agda` | the grade the compiler assigns *is* the grade the machine computes — stated as equality of **functions** from the retracted set to grades, because retraction *changes* the grade |
| `BeliefMass.agda` | `⊕` is a commutative monoid with silence as unit and is **not** idempotent; `⊓` is idempotent and only degrades |
| `SupportSet.agda` | mass defined by **membership**: `∪-idem` (a shared ancestor counts once), `∪-comm`, `derived≡direct` — idempotence is structural, not a convention |
| `Act.agda` | `bottom-blocks`, `no-irreversible-on-bottom`, `no-resurrection` — an orphaned action never revives, however much evidence arrives later |
| `ModuleImport.agda` | `φ(a ⊓ b) = φ(a) ⊓ φ(b)` and `φ(⊥) = ⊥` are **equivalent** to "map-then-fold = fold-then-map"; monotonicity is a consequence |
| `Precondition.agda` | what an action requires before it may be typed at all |
| `Representative.agda` | the representative of a class, and what survives when the class is re-entered |

Everything is carried **without a single real number**: comparing fractions with positive
denominators is comparing products, so the carrier is pairs of weights in ℕ.

## On counting

`count.sh` reports three numbers and refuses to add them, because they are different kinds:

```
CONTENTFUL (passed the second gate) · DEFINITIONAL (rungs, not proofs) · UNMARKED
```

**Unmarked is a debt, not a result.** 189 module-level statements typecheck; how many are
theorems worth naming is open, and the README's `Status` section says so. A count that mixes
definitions with proofs has already been inflated twice in this project's history — once by a
broken regex, once by prose that outran the counter.

## The boundary, said plainly

🔴 **Agda proves the model, not the Lisp.** `chk` and `red` here are freshly written definitions.
What is proved is that the checker's algorithm equals the machine's; that our Lisp implements
*those* algorithms rests on the oracle (1200 random programs, zero divergences — which bounds
divergence by the number of trials and does not prove equivalence), on the battery, and on
reading.
