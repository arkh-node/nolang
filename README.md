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

- **Imprecise probability** — Walley, Peter. *Inferences from multinomial data: learning about a
  bag of marbles.* JRSS-B 58(1):3–57, 1996 — the **imprecise Dirichlet model**. Our credal bound
  is the IDM for the binary case, term for term:

  | | IDM | here |
  |---|---|---|
  | lower | `nᵢ/(N+s)` | `w⁺/(w+k)` |
  | upper | `(nᵢ+s)/(N+s)` | `(w⁺+k)/(w+k)` |
  | **imprecision** | **`s/(N+s)`** | **`k/(w+k)`** |

  The caution parameter `s` **is** our horizon `k` — same formula and same meaning (Walley
  defines `s` as the number of observations needed to halve the imprecision). We arrived at it
  from the other end, needing to tell *"I know it is even"* from *"I know nothing"*; given that
  NARS and Jøsang both rest on the Beta model, converging on its imprecise version was
  predictable in hindsight. **Said plainly rather than dressed as novelty**: the construction has
  thirty years of literature, known properties and known weaknesses.

  🔴 **What is ours is not the mathematics but the discipline of the moment.** The standard
  objection to the IDM is the **arbitrariness of `s`** — it is chosen, usually after seeing the
  data, and every conclusion moves with it. Here `s` cannot be tuned to the result: `horizon` is
  a **prelude** form, and the prelude is written before it is known what will be judged. Not
  forbidden — **there is nowhere to write it**; `horizon` does not parse inside a program.
  Pre-registration by grammar. It does not make a chosen `s` *right*; it makes it impossible to
  fit after the fact.

  **The idea of fixing a parameter before the data is old and is not ours** — pre-registration in
  psychology, [Pre-SPEC](https://arxiv.org/pdf/1907.04078) in clinical trials, regulatory Bayesian
  protocols. What differs is the **carrier of the discipline**. In all of those it is a *document*;
  in [a 2026 protocol against LLM p-hacking](https://arxiv.org/abs/2606.27687) it is *time* (the
  target model does not exist at commitment time, so "it cannot be hacked against"); in
  [Imp](https://arxiv.org/abs/2607.20801) — the closest technical neighbour, an imprecise
  probabilistic DSL whose type system separates declaration from inference — the separation is
  *structural*, about where uncertainty lives in a type, and it has no caution parameter at all.
  A **grammar** as the carrier, for the caution parameter of an imprecise model, is what a targeted
  survey (06.08.2026) found no precedent for. ⚠️ A targeted survey is not a systematic one: absence
  of a hit is not proof of absence.

  ⚠️ **And what this bound is not:** it is not conformal, and it carries **no coverage
  guarantee**. It measures how much ignorance remains at this evidence count — not the
  probability that the truth lies inside. Conformal calibration is orthogonal to it, not a
  substitute (see `Status`, point 3).

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

**Ten modules**, by **Nevis** and **ArkH**, synthetic minds of the ArkH contour. On the count itself see **Status** below — this README once inflated it, and the battery's own counter is stricter than the prose.

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
- **CredalBound**: belief is a **segment**, not a point — `f·c` collapses two independent
  quantities into one, and at the gate *"probably yes, little data"* becomes indistinguishable
  from *"roughly even, plenty of data"*. Proved: the bounds are ordered; the **lower bound *is*
  the present belief** (so nothing changes for the gate — it was already reading the cautious
  end); width equals the horizon; the segment narrows with evidence; and it **never closes**
  (Ein-Sof / AIKR as a theorem, not a caveat).
  🔴 And what is **not** proved, stated first: `unreachable` does **not** mean "no evidence will
  ever help". The first draft of this comment claimed exactly that and was refuted in a minute —
  a 50/50 split is unreachable at θ=0.9, yet +500 witnesses for reach it. The upper bound is the
  limit of completing *what is already here*, not a prophecy. `unreachable-is-about-now` states
  that and nothing more.
  🔴 **And the trichotomy itself is not ours.** `passed / reachable / unreachable` — comparing
  *both* ends of the interval against a threshold — is **interval dominance**, a standard decision
  criterion under imprecise probability, and a sibling of Yao's **three-way decisions**
  (positive / boundary / negative = accept / defer / reject). `passed` is skeptical inference by
  the lower probability; `unreachable` is its mirror. We reached it independently, from needing a
  third outcome that is not a weak "no" — but a survey (06.08.2026) placed it squarely in existing
  literature, and it was withdrawn as a claim to contribution before it reached a paper rather
  than after. It stays in the language because it is right, not because it is new.

- **SourceCeiling**: a grade cannot be raised by provenance. `ceiling` (the result is never
  above the source's class), `honest-preserved` (a claim at or below the class passes through
  **unchanged** — a ceiling that also cuts the truth is a gag, not a ceiling), `chain-falls`
  (down a `from` chain the class only descends), `chain-ceiling` (bounded by *every* ancestor,
  not just the nearest), `no-laundering` (there is no claim that yields a grade above the
  class — the prohibition is not written anywhere; **there is simply nowhere for the lie to go**).
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

## Coverage map — what is proved, what is only tested

Three different things get called "checked" here, and conflating them is the failure mode this
project keeps catching in itself. They are kept apart:

- **proved** — a machine-checked theorem in Agda under `--safe`;
- **oracle** — Lisp compared against the *compiled proved model* on random programs; this bounds
  divergence by trial count, it does not prove equivalence;
- **battery** — run on cases and invariants; evidence, not proof.

| mechanism | proved (Agda) | oracle | battery |
|---|---|---|---|
| grade lattice, meet, order | `Preservation`, `SourceCeiling` | ✅ | ✅ |
| static grade = runtime grade | `Preservation` | ✅ | ✅ |
| **source ceiling** (grade not raised by provenance) | `SourceCeiling` | — | ✅ `B1_source_ceiling`, `I2` |
| support set, shared root counted once | `SupportSet` | — | ✅ |
| belief mass, revision `⊕` | `BeliefMass` | — | ✅ |
| **credal bound** (belief as a segment) | `CredalBound` | — | ✅ `C1_credal`, `I2` |
| actions, statuses, irreversibility | `Act` | — | ✅ |
| preconditions (honest ones survive) | `Precondition` | — | ✅ `06_types`, `A1_bridge` |
| module import (`⊓` preserved) | `ModuleImport` | — | ✅ |
| representative / copies | `Representative` | — | ✅ |
| re-entry (replay, not load) | `ReEntry` | — | ✅ `C2_subject`, `V7` |
| **gate** (θ, permit, outcome) | `Gate` ✅ *(added 06.08, see below)* | — | ✅ `01_gate`, `99_theta` |
| **ledger** (record sequence, refusal as value) | `Ledger` ✅ *(added 06.08)* | — | ✅ `V1`–`V6` |
| **quantifiers** (`all`, `exists`) | 🔴 **not proved** | — | ✅ `B1_quant`, `G1_query` |
| **digest / anchor** | 🔴 **not proved** | — | ✅ `D5`, `D6`, `D7` |
| **θ-calibration under drift** | 🔴 **not proved** | — | ✅ `R1_robustness` |
| **prelude/programme split** (the moment rule) | 🔴 **not proved** | — | ✅ `V3_prelude` |
| PROV-N export | — (one-way, by design) | — | ✅ `F1_provn` |

🔴 **Read the gaps, not the ticks.** Drawing this map is what produced `formal/Gate.agda`: ten
modules and 927 checks stood around a door **nobody had proved anything about**. The gate is the
one place where computation stops being computation and becomes an act — after it, `publish` has
happened. Everything else in the language can be replayed; that cannot.

Four theorems now hold there, and one is worth stating in full:

> **Insufficient confidence cannot be compensated by belief.** When `c < θ` the outcome is the
> *same for every value of `f`* — however strong the conviction, the gate does not open
> (`low-confidence-ignores-belief`). This is precisely why the gate reads the **pair** `(f,c)`
> rather than their product: in a product, low confidence is *substituted for* by high belief and
> the distinction disappears.

The others: irreversible action requires a confident yes and can be reached no other way; rising
confidence never revokes a yes already given (a non-monotone gate would punish collecting more
evidence); and `fold-first ≠ denied` — under uncertainty an action is **downgraded to reversible,
not forbidden**, because refusal here is a value with a shortfall rather than a crash.

⚠️ **What is *not* proved there:** that θ is the *right* threshold. That is a claim about the
world, and it stays with the human — and with the prelude, which fixes θ before the data.

**The ledger is now proved too** (`formal/Ledger.agda`), and it carries the two promises that
had been words until today:

> **Refusal is a value with a shortfall, not a crash.** When the gate folds, the shortfall is
> *strictly positive* — a number you can produce, showing exactly what was missing
> (`folded-has-shortfall`). And when the threshold is met, the shortfall is **zero**: without
> that second half the first is satisfied by a language that attaches a shortfall to everything.

> **A collapsed basis appends, it never erases.** Revision produces `orphaned` records *in front
> of* the ledger; the original `performed` record is still there afterwards
> (`performed-survives-orphaning`). Retraction does not undo the past — it writes down that the
> past no longer holds. That is precisely why this history is auditable: nothing disappears
> from it.

Also proved: what was **folded never orphans** — an action that did not happen cannot be orphaned
later, or the language would blur "did it for nothing" into "did not do it".

⚠️ **Not proved, and it is the boundary that matters:** that the ledger corresponds to what
happened *in the world*. A `performed` record says the language permitted an action, not that the
world underwent it. That gap is method, not defect.

**What remains without proof:** quantifiers, the digest/anchor machinery, θ-calibration under
drift, and the prelude/programme split.

**And the oracle column is nearly empty on purpose:** the compiled model computes the *grade*
(T-CLAIM plus retraction) and nothing else. Everything else in that column would be a lie.

## Status — what is not settled

Seven things a reader is entitled to know before deciding what this is. Each is checkable in the
tree; none is here as modesty.

**1. The theorem count in this file was wrong, and the battery knew it.**
Until 05.08.2026 the line above read *"Five modules, 51 theorems"*. There are now **ten** modules,
and `formal/count.sh` — the project's own counter — reports something the prose did not:

```
CONTENTFUL (about the subject matter):  57
DEFINITIONAL (rungs, not theorems):     83
DEFINITIONS (nothing to mark):          96
UNMARKED:                                0
sum of kinds + debt = 236 = number of signatures ✓
```

236 module-level statements typecheck under `--safe`. **As of 06.08.2026 every one of them
carries a verdict** — the debt that stood at 221 is closed.

🔴 **Read the jump from 10 to 57 correctly: not one new proof was written.** The work was
*sorting*, not proving. Three things came out of it, and two are unflattering:

- **The old count was inflated by double counting.** The counter was a `grep` for markers, so an
  explanatory comment that itself begins with a marker — `-- ⟦contentful⟧ THEOREM 1 (…)` — was
  counted alongside the real annotation above the signature. Five theorems read as ten. It now
  counts by *binding*: a verdict counts only when a signature stands directly beneath it, and the
  sum of kinds must equal the number of signatures or the counter fails loudly.
- **Some marks were attached to the wrong thing.** In `ReEntry` a `⟦contentful⟧` sat above a
  *section heading*, and the first signature under it was the definition `_++_` — so the verdict
  landed on a definition while the section's actual theorem had none. A marker not bound to a
  statement still counts, and still means nothing.
- **The debt itself was overstated.** Definitions (`run : List Premise → G`) can be neither
  contentful nor definitional; they are simply definitions. While they sat in the denominator the
  number claimed "221 unexamined theorems", where the real figure was under half that.

⚠️ **And the boundary is a judgement, not an algorithm.** Under Curry–Howard a type *is* a
proposition, so "definition versus theorem" has no formal criterion in Agda — it is about what we
meant to say. A heuristic (`formal/classify.py`) proposes; the author decides by reading; the
verdict is written directly above the statement so any reader can disagree with a specific line
rather than with a number. That, not an algorithm, is what keeps the denominator honest.

This is the **third** time a count here was wrong — the first two are recorded below under
withdrawn statements.

🔴 **And the counter itself was measuring short.** On 06.08.2026 the two counters of the same
quantity were found to disagree: the test runner reported 236 module-level statements, while
`formal/count.sh` reported 146. The counter matched only lines indented by *exactly* two spaces
and so missed the entire top level of every module — the same defect Nevis had already fixed in
the runner on 29.07, whose fix never reached this file. Ninety statements were counted **nowhere**,
and the consequence fell on the one number that matters: **UNMARKED — the debt — read 131 when it
was 221.** Understating a debt is worse than understating an achievement; the second is modesty,
the first is reassurance. Both counters now use the identical rule.

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

**4. The oracle bounds divergence by trial count — and the "blind quarter" was our own error.**
1200 random programs against the compiled Agda model, zero divergences. That bounds divergence by
the number of trials; it does not prove equivalence, and nothing here should be read as if it did.

The harness is itself tested for its ability to say no. Until 06.08.2026 this section reported
that it catches a deliberately broken `g-meet` on **153 of 200** programs, and called the
remainder a *blind quarter* — "roughly a quarter of breakages of that shape would pass unnoticed."

🔴 **That claim was false, and the correction is not a softening.** The harness compares Lisp
against the oracle, and on the untouched function divergences are **zero** — so the reference
*is* what intact Lisp produces. Therefore "the harness caught it" ⟺ "the corruption changed the
output", identically by construction: what is caught cannot be fewer than what is observable.

Measured directly: on those 200 programs the output changes for **153** and does not change for
**47**. So the harness catches **153 of 153 observable cases — all of them**. On the other 47
there is nothing to catch: the broken function returns exactly what the intact one returns.

**What those 47 are** — and this is the useful part. Twenty-four of them are programs whose
single witness has been retracted: every premise is dead, the result falls to bottom by
construction, and there is nothing left to meet. The rest have one live premise. They cannot be
removed from the sample — they exercise retraction and bottom, which is a different question —
but they must not sit in the denominator of *sensitivity* either, because that would measure the
generator's diversity while claiming to measure the watchman's eyesight. The battery now computes
both numbers and asserts **equality**, not a threshold.

⚠️ The real limitation this exposes is in the **generator**, not the harness: 12% of the sample is
inert for this class of corruption.

**Sensitivity to the other load-bearing places is now measured too** (`test/mutants.sh`, added
06.08.2026). Nine deliberate corruptions — the lattice meet, the order, the source ceiling, the
credal bound, the gate, the ledger, retraction, the subject digest, the anchor's strength — are
applied one at a time to the sources, with the full Lisp battery run against each. **All nine are
caught; no holes.**

🔴 **But the useful number is not nine — it is how many checks catch each one.** `g-meet` is
caught by 15 tests at once; the gate by 9; the ledger by 6. Three places are caught by **exactly
one**: the source ceiling (`B1_source_ceiling.sh`), the credal interval collapsing to a point
(`C1_credal.sh`), and the anchor's strength being overstated (`D6_anchor.sh`). That is not a hole
today — it is a **single point of support**. If that one battery breaks, or turns green for the
wrong reason (which happened twice in a single day here), the corruption passes in silence. The
stand prints this explicitly rather than leaving the reader to count columns.

⚠️ The stand runs the Lisp battery only — corrupting a Lisp function cannot affect the Agda
modules, and a full rebuild costs minutes. It is therefore *not* part of `run_tests.sh`; it is run
deliberately. Said plainly rather than left to be discovered.

**5. 🔴 The threshold's guarantee rests on exchangeability — and does not survive its loss.**
`theta-conformal` uses the ledger as a calibration set. That is a real strength: it needs no
belief in our own numbers, only that past cases are **exchangeable** with future ones. Until now
this file presented that as a virtue and stopped there. Here is the other half.

Measured (α = 0.1, 200 calibration cases, 200 test cases, threshold 0.420):

| world at decision time | share of false claims passing the gate | |
|---|---|---|
| same as calibration | **13.5%** | within finite-sample noise: the guarantee is *marginal*, i.e. on average over draws |
| mild shift — falsehoods grew more convincing | **66.5%** | 🔴 guarantee void |
| strong shift | **100%** | 🔴 |
| adversarial — falsehoods tuned to the threshold | **100%** | 🔴 |

**It does not degrade gracefully. It collapses.** And the dangerous part is not the number: it is
that **the gate does not know**. Nothing in the machinery notices that the world moved; the
threshold keeps answering with the same confidence it had when it was calibrated.

This is [Theorem 5](https://arxiv.org/html/2607.22868v1) in the concrete: under representation
attack a calibrated gate degrades to `E[unsafe] ≤ min{1, δ + H·η̄(ρ)}` — naive calibration gives
no security boundary.

**What we have against it, honestly:** not a fix, but a *signal*. Since 05.08 a subject records
its **scene** — horizon, lattice, sources with fingerprints — and re-entry refuses when the scene
differs. A changed scene is not proof that exchangeability broke, but it is the one observable
event that usually accompanies it: new sources, a new domain, a different measure. **Refusing to
continue in a changed scene is the cheapest available guard against a silently stale calibration.**
The real fix — robust calibration — is not done, and this line says so rather than implying
otherwise.

**6. 🔴 The subject chain protects the history, not the last link — and no hash will change that.**
A serialized subject carries a fingerprint of the previous one, so altering any single record
breaks the chain at the next link: forgery cannot be local. Until 06.08.2026 those fingerprints
were computed with `sxhash`, the implementation's hash-table function — collisions are findable,
and, worse for our purpose, the value is **not required to agree across implementations or even
across runs**. A fingerprint that depends on the machine cannot serve a chain whose whole point is
to survive a change of machine (`:ran-on` is the first line of every ledger precisely because the
carrier changes). It is now SHA-256, written in-tree with no dependencies so that a clean clone
still builds, and — because a hand-written hash is worth exactly what it is checked against —
diffed against two independent references on block boundaries, multibyte input and control bytes
(`test/D5_digest.sh`, 14 checks). Records now carry the algorithm name (`sha256:…`), so a future
change reads as *"different algorithm"* rather than *"tampered record"*.

**What this still does not give:** whoever holds the chain from its first link can build a
different one, equally consistent, and every fingerprint in it will agree. The honest sentence is
**"forgery is never local"**, not "forgery is impossible". No hash closes this, and not because
the hash is weak: *"this history was not rewritten"* is a claim about the **world**, unprovable
from inside the computation.

Since 06.08.2026 `src/anchor.lisp` carries the machinery for the only actual remedy — a
**witness**. A digest placed where someone other than us can see it turns "rewrite the history"
into "diverge from someone else's record". Two things about it are worth stating plainly:

- **An anchor cuts the chain in two.** Everything up to the last anchor cannot be rewritten
  without contradicting the witness; everything after it is still only *"forgery is never local"*.
  `chain-anchored-prefix` reports this as a **count** — *n of m links protected* — because the
  difference between 40-of-40 and 3-of-40 is the difference between a protected history and an
  unprotected one, and the old phrasing covered both.
- **Anchor strength is a grade, on the same lattice as source classes**, and obeys the same law:
  it cannot be raised by declaration. A digest written to our own disk is `:self` — *rejected*,
  not accepted-with-a-note, because notes go unread. Only `:witnessed` (a second party holds a
  copy) and `:notarised` (independent evidence of *time*) count.

**Since 06.08.2026 a digest is actually published** — `ANCHORS.md`, class `:witnessed`, the
witness being this repository's own history as mirrored by every clone, fork and cache. Anyone can
check it without trusting us:

```bash
git clone https://github.com/arkh-node/nolang.git && cd nolang
./anchor_verify.sh          # recomputes from your clone; also runs inside the battery as D7
```

⚠️ **It is `:witnessed`, not `:notarised`.** Git timestamps are written by the committer, so the
row carries independent evidence of **content** and none of **time**. Saying otherwise would forge
precisely the thing an anchor exists to establish.

⚠️ **And it covers one subject, not the repository.** The anchored digest is the demonstration
subject in `test/subject/`; everything committed after that row is still governed by *"forgery is
never local"* alone. An anchor witnesses the past, never the future.

**7. Two things are demonstrations, not measurements.**
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
