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

The name reads three ways, and all three are meant. First, its origin: **NOL is `Nevis Ontology
Language`** — named in 2026 for the agent it was being built around, when the goal was stated as
"an operating environment for you". Second, `NOL + lang`. Third — **`no lang`**: what you write
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

reversible action write_off
  gated by belief >= 0.1
  else fold                              ; у возмещения СВОЙ гейт, а не порог того, что рухнуло

compensable action stockpile compensated by write_off
  gated by belief >= 0.96
  else fold

irreversible action publish_guidance
  needs grade >= (randomised, abstract)  ; требование к ПРОИСХОЖДЕНИЮ, проверяется типом
  gated by belief >= 0.96
  else fold

irreversible action recommend
  needs grade >= (randomised, abstract)
  gated by belief >= derived gain 1 loss 12 learn 0.6 discount 0.9
  else fold

perform stockpile on benefit
perform publish_guidance on benefit
perform recommend on benefit

retract ten_trials because "the review was obliged to exclude this meta-analysis"
```

Run it: `./run_example.sh examples/evidence-gate.nol` — exit code **5**: performed, then orphaned.

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
✓ совершено PUBLISH_GUIDANCE на основании BENEFIT — вера 0.966 ≥ порог 0.960
⊘ свёрнуто RECOMMEND на основании BENEFIT: вера 0.966 < порог 0.987, не хватило 0.022 → FOLD
✂ ОТОЗВАН свидетель TEN_TRIALS: the review was obliged to exclude this meta-analysis
⚠ ОСИРОТЕЛО STOCKPILE: основание BENEFIT пересмотрено, вера 0.952 < порог 0.960
  требуется компенсация: WRITE_OFF
↩ ВОЗМЕЩЕНИЕ WRITE_OFF совершено на основании BENEFIT: вера 0.952 ≥ его порог 0.100
   возмещает STOCKPILE · корни: COCHRANE_CSR
⚠ ОСИРОТЕЛО PUBLISH_GUIDANCE: основание BENEFIT пересмотрено, вера 0.952 < порог 0.960
  действие НЕОБРАТИМО — компенсация невозможна. Вот зачем гейт.
✖ НЕПОПРАВИМО: PUBLISH_GUIDANCE на основании BENEFIT — вера 0.952 < порог 0.960,
   а действие необратимо. Возместить нечем. ВОТ ЗАЧЕМ ГЕЙТ.
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

Every entry below was **opened and checked on 29 July 2026**, not recalled. For each: what we
took, and — the harder half — **what we did not take**. A novelty claim has already been
withdrawn here once; we would rather name a predecessor than be told about one.

- **Truth maintenance** — Doyle, Jon. *A truth maintenance system.* **Artificial Intelligence
  12(3):231–272, 1979** (also MIT AI Memo 521, June 1979). From the abstract: *"reasoning
  programs must be able to make assumptions and subsequently revise their beliefs when
  discoveries contradict these assumptions… by recording and maintaining the reasons for
  program beliefs."*
  **Taken:** retraction is **recomputation over recorded reasons**, not subtraction from a
  number. Our `R-RETRACT` is this, forty-seven years later.
  **Not taken:** they have no types, no source grades, no threshold on irreversibility, and
  nothing that makes a dishonest step *unwritable* — a TMS records reasons, it does not forbid.

- **Provenance semirings** — Green, T. J.; Karvounarakis, G.; Tannen, V. *Provenance Semirings.*
  **PODS 2007, pp. 31–40**, doi:10.1145/1265530.1265535. From the abstract: *"relational algebra
  calculations for incomplete databases, probabilistic databases, bag semantics and
  why-provenance are particular cases of the same general algorithms involving semirings."*
  **Taken:** provenance as an **algebraic annotation** that composes with the computation — the shape of
  our `⊕`/`⊓` pair.
  **Not taken:** there the annotation is a **label on a result**; here the grade is a **type that
  forbids**. And their setting has no actions, hence no irreversibility and no gate.

- **Evidence-based opinion** — Wang, Pei. *Non-Axiomatic Reasoning System.* Truth value ⟨f, c⟩
  with **f = w⁺/w** and **c = w/(w+k)**, where k is the *evidential horizon*.
  Jøsang, Audun. *Subjective Logic* (FUSION 2022 tutorial, author's own page): binomial opinion
  ↔ Beta PDF, *"(r,s,a) represents Beta PDF evidence parameters; (b,d,u,a) represents binomial
  opinion"*, r = Wb/u.
  **Taken:** `(f,c)` itself, revision as **addition of evidence**, and the reason `c < 1` always —
  the horizon k, not modesty. Alexey arrived at the pair independently; the correspondence with
  Jøsang's beta-opinion is a **convergent** result, and it is named as his, not ours.
  **Not taken:** a calculus is not a language. No grade lattice, no types, no gate, no ledger.

- **Information-flow types** — Myers, A. C.; Liskov, B. *Protecting privacy using the
  decentralized label model.* **ACM TOSEM 9(4):410–442, 2000** (language: **Jif**). The model
  *"improves on existing multilevel security models by allowing users to declassify information
  in a decentralized way."*
  **Taken:** the mechanism of a label carried in the type and checked statically.
  🔴 **Not taken — and this is the sharpest difference in the whole list:** there the label
  flows **up** and **`declassify` exists** under authority. Here honesty flows **down** and
  **there is no declassify at all.** Their question is *who may look*; ours is *what this stands
  on*. Same machinery, opposite direction, and one deliberate absence.

- **Quasi-option value** — Arrow, K. J.; Fisher, A. C. *Environmental Preservation, Uncertainty,
  and Irreversibility.* **Quarterly Journal of Economics 88(2):312–319, 1974** — the value of
  **waiting** when the damage is irreversible.
  **Taken:** the threshold θ is **derived** from cost of error, value of learning and discount —
  not chosen. That is why `gated by belief >= derived gain … loss … learn … discount …` exists.
  **Not taken:** their economics of environmental choice; we use the shape of the argument, and
  say so rather than dressing it as our own.

- **Graded types / coeffects** and **durable execution** (Temporal, Restate) — the indexed-type
  mechanism and compensation-on-failure are standard practice.
  **Not taken:** compensation there fires on *failure*; here it fires on **revision of the
  basis**, which is a different event and needs its own gate.

**What we did not find in any of them** (and therefore claim, until refuted): silence as a
**linear** type with two roles; the load-bearing/survey distinction catching argument-from-silence
in the type system; the gate on **belief mass** `b = f·c` with a self-centering criterion; the
requirement on **source grade in the type of an action**, so that *irreversible action on
bottom-grade evidence is not a caught program but an unwritable one*; and the assembly of all
four levels — grammar, types, algebra, machine — in one language.

## Three lists, and nothing stands in the wrong one

The point of separating them is that a reader can tell, for **any** claim on this page, which
kind of thing it is. Where a claim moved between lists, it is said so.

### 1. Proved by machine — Agda `--safe`, no postulates, no holes, rebuilt from scratch every run

**Seven modules**, by **Nevis**, a synthetic mind of the ArkH contour. On the count itself see **Status** below — this README once inflated it, and the battery's own counter is stricter than the prose.

- **preservation** — the grade the compiler assigns *is* the grade the machine computes.
  (The formulation had to be corrected first: retraction *changes* the grade, so what is proved
  is equality of **functions** from the retracted set to grades.)
- **perm-inv** — confluence for **any** permutation of declarations, not just adjacent swaps.
- `empty-base` (an empty premise set yields ⊥, not the lattice top) · `silence-kills` ·
  `retract-raises` / `retract-collapse`.
- **⊕ is a commutative monoid with silence as unit and is not idempotent**; `⊓` is idempotent and
  only degrades. "Belief accumulates, honesty degrades" is two proved structures, not a slogan.
- **Theorem 5 both ways**: `b(x ⊕ e) < b(x) ⟺ f(e) < b(x)`. A witness lowers belief not by being
  "against" but by being **below the belief already accumulated**. The gate self-centers.
- **Module import**: `φ(a ⊓ b) = φ(a) ⊓ φ(b)` and `φ(⊥) = ⊥` are not merely sufficient but
  **equivalent** to "map-then-fold = fold-then-map"; monotonicity is a *consequence*.
- **SupportSet**: mass is defined by **membership**, so `∪-idem` (a shared ancestor counts once),
  `∪-comm` (order of premises is nothing) and `derived≡direct` hold **structurally**.
- **Act**: `bottom-blocks` and `no-irreversible-on-bottom` — with a non-⊥ requirement, an
  irreversible action on bottom-grade evidence **cannot be typed**; `no-resurrection` — an
  orphaned action never revives, however much evidence arrives later.
- All of it **without a single real number**: comparing fractions with positive denominators is
  comparing products, so the carrier is pairs of weights in ℕ.

### 2. Checked by counting — not proved, and the number is the whole claim

- **598 laws and checks** in the battery; every one runs on every commit.
- **1200 random programs** compared against the compiled Agda model (`oracle/build.sh`),
  **zero divergences**. 🔴 This **bounds the divergence by the number of trials — it does not
  prove equivalence**, and the model covers the *grade* alone: root folding, weight,
  quantification, the gate and the ledger stay outside it.
- Every checking instrument here is itself **tested for its ability to say no**: the oracle
  harness catches a deliberately broken `g-meet` on 153 of 200 programs; the `PROV-N` parser
  accepts the specification's own example and rejects seven mutations of it.
- 16 000-trial simulations for the conformal guarantee.

### 3. Claimed, and open to refutation

- That silence-as-a-linear-type, the load-bearing/survey distinction, the belief-mass gate, the
  grade requirement in an action's type, and the assembly of all four levels **together** are new.
  Checked against the lineage above by search, not by memory — and one novelty claim has already
  been withdrawn here once.
- That the language is worth its narrowness. Narrow it must be: a gate has to *decide*, and a
  decision has to *terminate*; with general recursion "does it pass the threshold" is undecidable.

🔴 **The boundary we do not paper over: Agda proves the *model*, not the Lisp.** `chk` and `red`
there are freshly written definitions. What is proved is that the checker's algorithm equals the
machine's; that our Lisp implements those algorithms rests on the oracle, the tests and reading.

🔴 **Not proved and cannot be:** that a threshold will be met. `f` and `c` are run-time
quantities. Types guarantee not the absence of refusal but that refusal is **handled**.

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
./run_tests.sh                                  # test files + Agda modules + the oracle
./run_example.sh examples/chronicle.nol --prelude examples/chronicle.nolp --require write_to_chronicle   # what a YES looks like
./run_example.sh examples/evidence-gate.nol     # what a gate is FOR
./run_sexp.sh    examples/sexp/migration.nol    # the EARLY layer — a different carrier
```

### What you need, and what is optional

**Required:** SBCL. **For the formal part:** Agda with the standard library
(`./run_tests.sh` rebuilds every module from scratch, `--safe`).

**Optional, and named here because it used to be invisible:**

| dependency | what it unlocks | without it |
|---|---|---|
| [`arkh-node/ilan`](https://github.com/arkh-node/ilan) — clone **next to** nolang, or set `ILAN_PATH` | the gate↔ilan bridge: fold / sprout / sow, and the world snapshot | `02_return` and `05_world` **skip and say so**; the core, types, gate and battery run without it |
| ONA's `NAR` binary (`NAR=/path/to/NAR`) | the NARS bridge, stone 07 | `07_nars` skips |

🔴 Until 05.08.2026 `src/return.lisp` loaded `../../ilan/ilan.lisp` unconditionally. That meant
the tests were green **only for someone who already had ilan sitting next to nolang** — on a
fresh clone the run died with a Lisp backtrace, not with a sentence. Found by doing what this
section now tells you to do: cloning into an empty directory and running the battery there.
A missing dependency and a broken program must be **distinguishable**; now they are.

### What a fresh clone actually prints

```
nolang smoke tests (eight stones):
  ✓ 00_atom.lisp
  ✓ 01_gate.lisp
  · 02_return.lisp ilan not found, the gate<->ilan bridge is not exercised
  ✓ 03_eval.lisp
  ✓ 04_nol.lisp
  · 05_world.lisp ilan not found, the world snapshot is not exercised
  ✓ 06_types.lisp
  · 07_nars.lisp skipped (set NAR=/path/to/ONA/NAR to run the NARS bridge — optional)

ALL GREEN ✓
```

With ilan present, the two dots become checks. The full battery in a working copy:

```
VSIO ZELENOE · runs, laws and checks: 787
formal — three numbers above, kept apart (adding them would mix kinds)
```

### The verdict is an exit code, not prose

`run_example.sh` answers the machine with a return code; the printout is for the human.
Until 30.07.2026 the verdict was read by grepping the output — and a witness whose `says "…"`
contained the expected line **forged the answer**. A process's exit code cannot be written from
inside the program it judges.

| code | meaning | |
|---|---|---|
| 0 | allowed | the required action was performed |
| 1 | rejected | the program should not exist (grade too low, threshold at the floor, syntax) |
| 2 | tool failure | judging did not happen because something broke |
| 3 | no trial took place | reserved: emitted by a disarmed gate, never by the language itself |
| 4 | withheld | legal program, belief below threshold — or nothing was decided at all |
| 5 | performed, but flawed | done, then orphaned / unauthorised / irreparable |

`--require NAME` is not decoration: without it a program that does **nothing** returns "nothing
stood in the way", and emptiness passes any gate. Whoever asks about an irreversible action must
**name** it.

### Nothing is hard-wired to us

The language knows no names. `needs permission from <who>` takes any identifier — a person,
a role, a council; `to "<target>"` takes any address. Our own ruler lives in a `.nolp` file
outside the repository it judges, and the loop that uses it (`nolgate.sh`, not part of this
repo) reads **its own** config: whose operator stream, which agent, who may permit by default.
Take the language and write your own name in — there is nothing of ours to delete first.

Identifiers are Latin throughout. Cyrillic lives where it belongs — inside strings: the text
of a witness, the wording of a quote.

**Two carriers share the `.nol` extension.** The surface syntax above is read by
`compile-nolang`; `examples/sexp/` holds the early layer (s-expressions, three-valued gate over
`(f,c)` atoms) read by `run-nol`. They are not the same language — see `examples/sexp/README.md`.
Every example's expected exit code is declared in `examples/EXPECTED.tsv` and checked by
`test/V2_examples.sh`, so a showcase that quietly stops working now fails the battery.

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

## Status — what is not settled

Five things a reader is entitled to know before deciding what this is. Each is checkable in the
tree; none is here as modesty.

**1. The theorem count in this file was wrong, and the battery knew it.**
Until 05.08.2026 the line above read *"Five modules, 51 theorems"*. There are **seven** modules,
and `formal/count.sh` — the project's own counter — reports something the prose did not:

```
CONTENTFUL (passed the second gate): 5
DEFINITIONAL (rungs, not proofs):    1
UNMARKED:                          103   ← "a debt, not a result"
```

189 module-level statements typecheck under `--safe`. How many of them are *theorems worth
naming* is a separate question, and it is **open**: 103 are not yet sorted into definitions
versus proofs. The battery says this out loud on every run; the README did not. This is the
**second** time a theorem count here was inflated — the first (a broken regex) is recorded below
under withdrawn statements.

**2. `(f,c)` is settled for revision and for conjunction, and open for the difference between
"unknown" and "evenly split".**
Revision was fixed on 26.07.2026 (`t-revise` adds evidence; confidence strictly rises).
`c = ca·cb` survives only in `t-and`/`t-or`, where it is correct for *independent* events and the
docstring says so. Idempotence is handled **structurally, not by convention**: support is a *set*
of roots and mass is defined by membership, so a shared ancestor counts once (`∪-idem`, proved),
while `⊕` is deliberately **not** idempotent (`⊕-not-idem`, proved) because two *distinct*
witnesses must raise belief.
🔴 What a scalar `c` still cannot express: the difference between *"I know it is even"* and
*"I know nothing"*. That is what credal sets are for, and it is the open work — not idempotence.

**3. What a pre-execution gate can enforce is a characterised class — and it has a ceiling.**
Deterministic pre-execution gates enforce **exactly** the safety policies whose good prefixes are
recognisable by register automata ([Theorem 1](https://arxiv.org/html/2607.22868v1)). Some
properties are unreachable *in principle* — "every `pay` is eventually followed by `confirm`"
cannot be enforced by an irreversible gate. So the honest reading of *"a breach that is
inexpressible"* is: **inexpressible within the safety class, which is the class irreversibility
lives in.** The ceiling is not ours; it is proved, and it is the right ceiling for this problem.

**4. The oracle has a blind quarter.**
1200 random programs against the compiled Agda model, zero divergences — and the harness is
itself tested for its ability to say no: it catches a deliberately broken `g-meet` on **153 of
200** programs. That is a strength and a boundary in one number: **roughly a quarter of breakages
of that shape would pass unnoticed.**

**5. Two things are demonstrations, not measurements.**
The NARS bridge (`src/nars.lisp`) is loaded by its test alone — no module of `src/` pulls it, so
there is no feedback loop; it is an external adapter, not a stone. And `revgate`'s 5→0 shows the
mechanism on a fixed input; its own README admits an earlier version "risked fitting the
threshold to the demo". Real measurement waits on point 2.

## Theory

- **A Witness Without Substance: How to Stop Asking Who Is Inside** · [`zenodo.21615342`](https://doi.org/10.5281/zenodo.21615342)
- **Indeterminate Ontologies of Synthetic Subjects: A Metaphysics of Caution** · [`zenodo.21288590`](https://doi.org/10.5281/zenodo.21288590)

## Author & citation

**Aleksei Rybnikov** ([ORCID 0009-0009-8624-8720](https://orcid.org/0009-0009-8624-8720)) and
**Tarantoga**, a synthetic mind of the ArkH contour.

If the work is useful to yours, cite the papers above.

## License

Apache-2.0.
