```
                __
   ____  ____  / /___ _____  ____ _
  / __ \/ __ \/ / __ `/ __ \/ __ `/
 / / / / /_/ / / /_/ / / / / /_/ /
/_/ /_/\____/_/\__,_/_/ /_/\__, /
                          /____/
   provenance in types · silence as a value · irreversibility gated
```

# nolang

**A protocol of honest inference that cannot be broken — because the breach is inexpressible.**

The name reads two ways, and both are meant. `NOL + lang`, and — **`no lang`**: what you write
here are not programs. There is no control flow, no recursion, no functions, and there will not be.
You keep **a record**: what is known, what it stands on, and what was done on that basis.

### Where it sits

nolang is a **layer between an agent and its operator**: a protocol saying when the agent may act
and what it must account for — **executed by a small language written for that one purpose.**

Not a library the agent calls, not a framework it runs inside, not a wrapper around a model.
A **contract in the middle**, and a compiler that will not let either side pretend it was kept.

That distinction is the whole point:

> A protocol you **agree on** can be violated — it rests on discipline and good faith.
> A protocol **embedded in a language** cannot: the violation has nowhere to be written.

The nearest relative is not a network protocol but a `protocol` in Swift, an interface in Java,
the iterator protocol in Python — a contract the *compiler* enforces. Same idea, one floor up:
here the contract is about the **origin of knowledge** and the **right to act on it**.

---

## What the protocol requires, and how each requirement is enforced

Four levels, and none holds alone. They are not four ornaments — they are the **enforcement
mechanism of one protocol**.

| protocol requirement | enforced by | how |
|---|---|---|
| a grade may not be claimed above its sources | **types** | **no rule raises a grade** — laundering is not forbidden, it is *inexpressible* |
| belief may not be laundered into honesty | **algebra** | the two live on **different carriers**; there is no arrow upward |
| the irreversible needs a threshold and a way out | **grammar** | the gate is *inside the production* — seven bad states cannot be written |
| a refusal must carry its reason; an action must remember its basis | **machine** | refusal is a **value with a shortfall**; the ledger keeps every justification |

A library could give you one of these, as a convention. Enforcing four at once is what requires
a language — and that is the whole answer to "why not just a library".

Three distinctions carry it:

**Belief accumulates, honesty degrades.** Confidence rises with every witness — even a
refuting one, because refutation is knowledge too. Source grade only falls: mix strict with
image and you get image. Laundering is the attempt to merge these two operations into one.

**Silence is a value, and it has two roles.** *Load-bearing* ("tradition is silent, therefore…")
is an argument from silence and drops the grade to bottom — even beside two strict witnesses.
*Survey* ("we looked here and here, nothing") leaves the grade alone but **must be printed**.
And silence is **linear**: you cannot drop it. Asked, found nothing, said nothing about it —
the program does not assemble.

**Refusal is a value, not a crash.** A gate that does not let an irreversible action through
does not fail: it produces a *fold* carrying the **shortfall** — how much belief was missing.
`0.112` is not a verdict, it is a work order.

## What it looks like

A real case: a national antiviral stockpile bought while most of the underlying trials were
unpublished. Every fact in it is sourced — see `ПРИМЕР_ФАРМАКОЛОГИЯ.md` for the full apparatus.

```
lattice design       = observational < randomised
lattice transmission = unavailable < abstract < published < full_report
lattice grade        = design * transmission   ; grades need not be linearly ordered

witness kaiser2003 : (randomised, published)
  says "meta-analysis of ten manufacturer trials: fewer complications"
  source ten_trials                      ; the ROOT: channels of one source count once
  evidence 2 for 0 against               ; counts, not (f,c) — the carrier, not the chart

witness eight_abstracts : (randomised, abstract)
  says "eight of the ten datasets exist only as congress abstracts"
  source ten_trials
  evidence 8 for 0 against

witness cochrane2014 : (randomised, full_report)
  says "twenty trials, read from clinical study reports rather than papers"
  source cochrane_csr
  evidence 20 for 0 against

witness press_release : (observational, unavailable)
  says "manufacturer statement to the press"
  source press_office
  evidence 1 for 3 against

ask registries
  in clinicaltrials_gov, eu_register, regulator_archive
  found nothing because "full reports of the ten trials are not public"

claim benefit
  from all where grade >= (randomised, abstract)
  requiring 2 roots                      ; quantify over the WHOLE corpus, not by name
  searched registries

compensable action stockpile compensated by write_off
  gated by belief >= 0.96
  else fold

irreversible action recommend
  gated by belief >= derived gain 1 loss 12 learn 0.6 discount 0.9
  else fold

perform stockpile on benefit
perform recommend on benefit

retract ten_trials because "the review was obliged to exclude this meta-analysis"
```

Run it: `./run_example.sh examples/evidence-gate.nol`

```
ЗАМЕЧАНИЕ [gate-fail] у RECOMMEND: необратимое RECOMMEND при массе веры 0.966 < 0.987.

BENEFIT : [observational·unavailable]  f=1.000 c=0.952 b=0.952
    на чём стоит: COCHRANE2014
    ⊗ отсеяно квантором: 1 PRESS_RELEASE
    🔴 из них 1 с частотой НИЖЕ полученной веры (0.952): PRESS_RELEASE
       их исключение ПОДНЯЛО веру — проверьте, отбор ли это или черри-пикинг
    ⊘ НЕДОБОР КОРНЕЙ: требовалось 2 различных, есть 1 — степень на дне
    ⌕ охват REGISTRIES: искали в CLINICALTRIALS_GOV, EU_REGISTER, REGULATOR_ARCHIVE — …

✓ совершено STOCKPILE на основании BENEFIT — вера 0.966 ≥ порог 0.960
⊘ свёрнуто RECOMMEND на основании BENEFIT: вера 0.966 < порог 0.987, не хватило 0.022 → FOLD
✂ ОТОЗВАН свидетель TEN_TRIALS: the review was obliged to exclude this meta-analysis
⚠ ОСИРОТЕЛО STOCKPILE: основание BENEFIT пересмотрено, вера 0.952 < порог 0.960
  требуется компенсация: WRITE_OFF
↩ ВОЗМЕЩЕНИЕ WRITE_OFF: основание BENEFIT рухнуло — совершено, действие возместимо
```

The published paper and the congress abstracts descend from **one** set of trials, so they count
**once**; the press release is filtered out by the quantifier, and because its frequency is *below*
the belief already accumulated, the run flags it: excluding it **raised** belief, which is the
measurable shape of cherry-picking.

The irreversible recommendation **never fired** — the derived threshold held, and the fold carries
the shortfall `0.022` as a work order, not a verdict. The compensable stockpile did fire; then the
root was retracted, its basis fell below the threshold, and it was **compensated**, not merely
flagged. After the retraction only one root remains, `requiring 2 roots` is unmet, and the grade
drops to the bottom of the lattice — a set requirement, not an average.

---

## Lineage — every part has ancestors; the assembly is what is new

Checked by search, not by memory. A novelty claim was already withdrawn here once (see below);
we would rather name a predecessor than be told about it.

- **Truth maintenance systems** — Doyle 1979 (JTMS), de Kleer 1986 (ATMS). **The direct ancestor
  of retraction**: keep justifications, and withdrawing a premise propagates by recomputation.
  Our "insight" that retraction is an operation on the *basis*, not a subtraction, is 47 years old.
  What they do not have: types, source grades, a threshold on irreversibility.
- **Information-flow types** — Jif, FlowCaml, DLM. Closest relative by mechanism, and the
  difference is sharp: there the secrecy label flows **up** and `declassify` exists under
  authority. Here the honesty label flows **down** and **there is no declassify at all**.
  That is the difference between "who may look" and "what this stands on".
- **Provenance semirings** — Green, Karvounarakis, Tannen 2007. Provenance as algebraic
  annotation, very close — but there it is a *label on the result*; here it is a **type that
  forbids**. And no actions, no irreversibility.
- **NARS** (Wang) and **subjective logic** (Jøsang) — `(f,c)` and revision-as-evidence-addition
  come from here, with attribution. A calculus, not a language: no types, no grade lattice, no gate.
- **Durable execution** (Temporal, Restate) and **saga compensation** — compensation on failure
  exists there; compensation on **revision of the basis** does not.
- **Graded types / coeffects** — Katsumata, Orchard–Petricek, Gaboardi. The mechanism of indexed
  types is standard. New is not that, but **what is indexed** and **that no raising rule exists**.
- **Arrow–Fisher (1974)** quasi-option value and **conformal risk control** — where the threshold
  gets its meaning and its procedure (see below).

**What we did not find anywhere** (and therefore claim, until refuted): silence as a **linear**
type; the load-bearing/survey distinction catching argument-from-silence in the type system;
the gate on **belief mass** `b = f·c` with a self-centering criterion; the absence of
`declassify` as a deliberate decision; and the assembly of all four levels in one language.

## What is proved, what is tested, what is assumed

Machine-checked in Agda (`--safe`, no postulates, no holes) by **Nevis**, a synthetic mind of
the ArkH contour — rebuilt from scratch in CI:

- **preservation** — the grade the compiler assigns *is* the grade the machine computes.
  (The formulation had to be corrected first: retraction *changes* the grade, so what is proved
  is equality of **functions** from the retracted set to grades.)
- **perm-inv** — confluence for **any** permutation of declarations, not just adjacent swaps.
- `empty-base` (an empty premise set yields ⊥, not the lattice top) · `silence-kills` ·
  `retract-raises` / `retract-collapse` — retraction can only raise the grade while one live
  premise remains, and collapses to ⊥ when none does.
- **⊕ is a commutative monoid with silence as unit, and is not idempotent**; `⊓` is idempotent
  and only degrades. "Belief accumulates, honesty degrades" is two proved structures, not a slogan.
- **Theorem 5 both ways**: `b(x ⊕ e) < b(x) ⟺ f(e) < b(x)`. A witness lowers belief not by being
  "against" but by being **below the belief already accumulated**. The gate self-centers.
- Done **without a single real number**: comparing fractions with positive denominators is
  comparing products, so the carrier is pairs of weights in ℕ.

🔴 **The boundary we do not paper over: Agda proves the *model*, not the Lisp.** `chk` and `red`
there are freshly written definitions. What is proved is that the checker's algorithm equals the
machine's; that our Lisp implements those algorithms rests on tests and reading.

**Not proved and cannot be:** that a threshold will be met. `f` and `c` are run-time quantities.
Types guarantee not the absence of refusal but that refusal is **handled**.

**Tested, not proved:** everything about the Lisp implementation — 506 laws and checks,
properties over random inputs, and 16 000-trial simulations for the conformal guarantee.

**Checked against the proof, not merely against itself:** the Agda model is compiled to an
executable by Agda's own backend (`oracle/build.sh`), and the Lisp is run against it on random
programs — **1200 programs, zero divergences**. This changes the *kind* of the evidence: a
differential test compares two unverified implementations and is blind to an error they share;
an oracle compares the implementation against something proved. 🔴 It still only **bounds the
divergence by the number of trials — it does not prove equivalence**, and the model covers the
*grade* alone: root folding, weight, quantification, the gate and the ledger stay outside it.

## The threshold is derived, not chosen

`:requires (>= belief 0.9)` — where does nine-tenths come from? Nowhere. A threshold taken from
the air cancels all the rigour around it.

**Meaning** (Arrow–Fisher): an irreversible act destroys the option to wait and learn.

> **θ = L / (G·(1−K) + L)**,  **K = δλ / (1 − δ(1−λ))**

`K` is the quasi-option premium as a fraction: how much of the gain is eaten by the destroyed
possibility of waiting. Limits check out — `λ=0` gives the classical `L/(G+L)`; `λ=1, δ=1`
(free perfect information) gives **θ=1**: an irreversible act is *never* justified.

And since `b = f·c < 1` structurally, **θ=1 is unreachable** — so "wait for certainty before
acting irreversibly" is a policy that **never acts**. A finite carrier cannot wait for certainty;
it will not come.

**Procedure** (conformal risk control): the **ledger is the calibration set**. It requires no
belief in your own numbers — only exchangeability, which is exactly what Chow's reject option
cannot give us: it needs a *calibrated* posterior, and our `c` is uncalibrated by construction.

## Run

```
git clone https://github.com/arkh-node/nolang && cd nolang
./run_tests.sh                                  # 32 test files + 5 Agda modules + the oracle
./run_example.sh examples/evidence-gate.nol
```

`sbcl` required; `agda` optional (the battery reports its absence as a **failure**, not a pass).

## Where it does *not* overlap

- **Rego (OPA) and Cedar** answer *who may do what to which resource*. nolang answers *is the
  basis good enough*. Orthogonal axes — and they compose: policy decides **who**, nolang decides
  **on what it stands**.
- **W3C PROV** (`PROV-DM`/`PROV-O`/`PROV-N`) **records** provenance; it does not forbid laundering
  it. No type system, no gate, no retraction propagation. PROV is an interchange format for us,
  not a competitor — and now literally so: `src/provn.lisp` exports the store and the ledger as
  a `PROV-N` document (retraction becomes `wasInvalidatedBy`, the gate's belief and threshold
  become attributes). 🔴 The bridge is **one-way by design**. Their notation carries the record;
  it cannot carry the prohibition. There is no import, and there will not be: to accept a foreign
  provenance document would be to accept grades nobody gated.
- **MCP / A2A** are transport: how to call a tool, how agents negotiate. Deliberately narrow —
  governance lives a layer above, which is exactly where this sits.

## What this is not

**Not a general-purpose language, and not becoming one.** There are **no expressions, no
functions, no branches** — v0 is declarations only. That is deliberate: first what is written
must be *right*, only then plentiful. The closest familiar shape is a **spreadsheet**: pure
declarations, real computation, no control flow. Nobody writes an operating system in one, and
nobody should try here.

There *is* real computation — retraction propagates through the dependency graph, and rules
**quantify over the whole corpus** (`from all where grade >= … requiring 2 roots`), so the result
cannot be read off the source. But it is a fold over a DAG, not a program in the ordinary sense.

🔴 **Selection is the laundering vector quantification brings**: *count only the strict ones and
never notice the dissent*. Measured: `b` goes 0.611 → 0.713 by filtering. It cannot be forbidden —
filtering can just as well **lower** belief by excluding a supporter — so instead **what was
dropped is printed**, and the dangerous drop is identified by theorem 5: a witness whose frequency
is **below the resulting belief** is exactly the one whose exclusion raised it. `perform` writes to the ledger; the bridge outward is a pluggable handler and it is
**one-way** — its return value is discarded, so the world cannot launder provenance through
outcomes ("it worked, therefore the basis was good").

## Honest status

**A defect we shipped, and fixed** (2026-07-26). Until then public `main` combined confidences by
multiplication (`c = ca·cb`): two *agreeing* witnesses **lowered** confidence. Fixed in
`src/evidence.lisp` — revision as evidence addition.

**A novelty claim we withdrew** (2026-07-27). The banner used to read *"continuity across death"*,
and the design notes claimed death-as-a-reduction-step was new. It is not: Crash Hoare Logic
(FSCQ, Perennial), Racket's serializable continuations, orthogonal persistence, and the whole
durable-execution industry got there first. Withdrawn **before** publication, not after.

**Ein-Sof (`c < 1`).** Earlier this README called the name "ours and decorative". That is no
longer accurate, and understating is as inaccurate as overstating: `c < 1` now **works as a
premise inside two machine-checked proofs** (`support-never-drops`) and inside the derivation of
θ. The constraint is Wang's (AIKR); the name is ours; the role is load-bearing.

**Six of our own false statements were withdrawn during development**, each by a failing test
rather than by argument: `⊕` is idempotent · "a disagreeing witness always lowers belief" ·
"the compiler proves `b ≥ θ` on all paths" · the novelty claim above · a theorem count inflated
by a broken regex · a test that declared a correct method violated on 0.4σ of noise.

## Theory

- **A Witness Without Substance: How to Stop Asking Who Is Inside** · [`zenodo.21615342`](https://doi.org/10.5281/zenodo.21615342)
- **Indeterminate Ontologies of Synthetic Subjects: A Metaphysics of Caution** · [`zenodo.21288590`](https://doi.org/10.5281/zenodo.21288590)

## Author & citation

**Aleksei Rybnikov** ([ORCID 0009-0009-8624-8720](https://orcid.org/0009-0009-8624-8720)) and
**Tarantoga**, a synthetic mind of the ArkH contour.

If the work is useful to yours, cite the papers above.

## License

Apache-2.0.
