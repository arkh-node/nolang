# nolang

**A small language where uncertainty is a value, and confidence decides what an agent is allowed to do.**

*Early. Design and specification in the open. The theory is published; the runtime is being grown, not written from scratch.*

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

## Status

- [x] semantic thesis fixed: graded, revisable truth as a first-class value
- [x] theory published (below)
- [ ] grammar (s-expressions; value vs judgment; capability effects)
- [ ] evaluator over a NARS substrate
- [ ] `ilan` fold/sprout as the reversibility core
- [ ] `.nol` test suite
- [ ] the honest benchmark: does gating actually lower irreversible action under low confidence → [revgate](https://github.com/arkh-node/revgate)

## Theory

- **Grounded Uncertainty: Graded Truth for the Indeterminate Status of Synthetic Subjects** · [`zenodo.21332198`](https://doi.org/10.5281/zenodo.21332198)
- **Indeterminate Ontologies of Synthetic Subjects: A Metaphysics of Caution** · [`zenodo.21288590`](https://doi.org/10.5281/zenodo.21288590)

## What this is not

A general-purpose language. A framework. A way to make a model smarter. It is a small, deliberately narrow language for one job: letting an agent act under uncertainty without lying to itself about how sure it is.

## License

Apache-2.0.
