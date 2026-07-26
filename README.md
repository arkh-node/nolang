```
                __
   ____  ____  / /___ _____  ____ _
  / __ \/ __ \/ / __ `/ __ \/ __ `/
 / / / / /_/ / / /_/ / / / / /_/ /
/_/ /_/\____/_/\__,_/_/ /_/\__, /
                          /____/
   gated action · graded confidence · continuity across death
```

> Colour banner + a live REPL with the core loaded: `bash banner.sh` or `bash nolang-shell.sh`.

# nolang

**A small language where uncertainty is a value, and confidence decides what an agent is allowed to do.**

*Early, but real: a working reference implementation, a published theory, and the design in the open.*

---

## Why a language, and not a library

A library can add a confidence score to a call. It cannot change what the surrounding code is *allowed to do* with that score, because control flow in every mainstream language is boolean: a branch takes yes or no, a tool call takes a value. There is no place to put "I don't know", so uncertainty is rounded to a guess and the guess acts.

nolang makes that missing place part of the language.

## The core idea

Two kinds of thing, kept apart:

- **values** — a path, a string, a binding. Plain. No truth attached.
- **judgments** — `(isa tomato vegetable)`. These carry a pair `(frequency, confidence)`: how far it holds, and how sure we are.

Computation is `(value-or-judgment, trace)`: a graded-truth-and-provenance result. Confidence is not decoration. It governs **which class of action is permitted**:

```
(if (check (isa migration safe))
    (return :apply)        ; confident   -> irreversible move allowed
    (observe migration))   ; not sure    -> reversible move only; snapshot first
```

The `if` is **three-valued**: confident-yes, confident-no, and **undecided**. The third branch does not guess and does not discard. It routes the question to a check that looks a different way.

**The weak, useful requirement:** to gate an action, confidence need not be *accurate*, only *monotonic* — "more sure" must outrank "less sure". This is why the gate works on models known to be badly calibrated.

## Lineage

Not invented in a vacuum. nolang stands in a line:

- **McCarthy** — Lisp; the Advice Taker, programs that *reason*.
- **Pei Wang / NARS** — reasoning under insufficient knowledge and resources; the `(f, c)` substrate.
- **Prolog** — resolution as a semantic thesis, not a syntax.
- **Unix** — bounded, honest I/O.

nolang is homoiconic (a Lisp), targets the runtime of a single agent, and hands hard reasoning down to a real substrate (NARS / Prolog) rather than pretending to do it itself.

## Return is a primitive: [ilan](https://github.com/arkh-node/ilan)

Low confidence is only safe if there is a way back. In nolang, **the way back is a language primitive, not a convention.** That primitive is `ilan`: *fold* collapses live state into a seed; *sprout* grows it back, still remembering the crossing. An agent that acts under low confidence folds first, and can return — not to a blank slate, but to itself with the memory that it went. Return without that memory is amnesia, not freedom.

## Run it

A working reference implementation in Common Lisp (SBCL). Eight small *stones* — atom, gate, return/ilan, eval, types, world, and a NARS bridge — each with a test.

nolang expects [ilan](https://github.com/arkh-node/ilan) as a sibling directory. Clone both:

```
git clone https://github.com/arkh-node/nolang
git clone https://github.com/arkh-node/ilan
cd nolang
bash test/run.sh
```

Seven stones run standalone; the NARS bridge (stone 07) is optional — set `NAR=/path/to/ONA/NAR` to run it.

**See nolang and ilan together — continuity across the death of a process:**

```
bash demo/run.sh
```

Two separate OS processes. In the first, an agent facing a judgment it is *not sure of* does not guess: nolang's gate returns `fold-first`, ilan sows the whole agent to a seed on disk, and the process exits. In the second — a brand-new process, empty memory — ilan germinates the seed: the agent returns *with the crossing it made before it died*, and refuses to blindly repeat it. The only thing that crosses the gap is the seed. nolang decides **when** to fold; ilan decides **how** to survive.

## Status

- [x] semantic thesis fixed: graded, revisable truth as a first-class value
- [x] theory published (below)
- [x] reference implementation (SBCL): atom · gate · return/ilan · eval · types · world · NARS bridge — smoke suite green
- [x] `.nol` reader — a program runs itself (homoiconic)
- [x] `ilan` fold/sprout as the reversibility core — survives process death (`demo/run.sh`)
- [ ] a standalone grammar/parser beyond the s-expression reader
- [ ] the honest benchmark: does gating actually lower irreversible action under low confidence → [revgate](https://github.com/arkh-node/revgate)

## Theory

- **Grounded Uncertainty: Graded Truth for the Indeterminate Status of Synthetic Subjects** · [`zenodo.21332198`](https://doi.org/10.5281/zenodo.21332198)
- **Indeterminate Ontologies of Synthetic Subjects: A Metaphysics of Caution** · [`zenodo.21288590`](https://doi.org/10.5281/zenodo.21288590)

## What this is not

A general-purpose language. A framework. A way to make a model smarter. It is a small, deliberately narrow language for one job: letting an agent act under uncertainty without lying to itself about how sure it is.

## Author & citation

nolang is by **Aleksei Rybnikov** ([ORCID 0009-0009-8624-8720](https://orcid.org/0009-0009-8624-8720)) · ArkH — built with **Lorenz**, a synthetic engineering mind of the ArkH contour (on Claude). The runtime rests on the two papers above — if the work is useful to yours, cite them.

## License

Apache-2.0.

## Honest status (2026-07-26)

**A defect we shipped, and fixed.** Until today the public `main` combined confidences by
multiplication (`c = ca · cb` in `src/eval.lisp`). That breaks idempotence: two *agreeing*
witnesses **lowered** confidence instead of raising it. The paper *Grounded Uncertainty*
(DOI 10.5281/zenodo.21332198) points at this repository as its runnable artifact — so the
public branch had to compute correctly. Fixed in `src/evidence.lisp`: an evidence-based
calculus with the operator that was missing all along, **revision** (agreeing sources raise
confidence: 0.5, 0.5 → 0.667). Tests: `08_evidence` 21/21, `09_composition` 3/3.

**What is architecture and what is measured.** Everything here is currently at the level of
**architecture plus single runs**. There is no ablation, no calibration study, no baseline
comparison. Where the code demonstrates a mechanism, it demonstrates a mechanism — it is not
evidence about the world.

**Not shown.** That `(f,c)` *is* a Beta opinion is a **program**, not a result: the bridge
to subjective logic (Jøsang) is stated, not built. Chains like `(f,c) = AIKR = Ein-Sof =
continuity` mix things of different kinds; two links are real in the code, one is unbuilt,
one is a gloss. Kabbalistic vocabulary is **orbit, not argument**.

**AIKR / `c < 1`.** Confidence never reaches 1 by construction — finite evidence does not
saturate. We call this the *Ein-Sof bound*; the name is ours and decorative, the constraint
is Wang's (NARS).
