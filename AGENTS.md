# Repository Agent Guide

This repository tracks upstream `IntersectMBO/plutus`. Fork branches named `wasm32-*` add a
32-bit-correct evaluator, WASI test/build outputs, and release automation without changing the source a
64-bit Cardano node compiles.

## How to work here

- Preserve upstream behavior on 64-bit targets. Keep platform-specific semantic changes visibly gated.
- Treat release tags as immutable; publish a new `-wasm32.<rev>` tag for every repair.
- Do not rewrite a published release branch or tag. Build a new revision branch from the upstream tag.
- Run the repository-provided wasm checks and remote `Wasm32 Testsuite` before publication.

## Skills

Activatable procedures live under `skills/`.

- [`maintain-wasm32-fork`](skills/maintain-wasm32-fork/SKILL.md) — load whenever reorganizing the wasm
  patch stack, rebasing onto a new upstream Plutus tag, cutting a `wasm32` release, changing
  `.github/workflows/wasm32-*`, or updating `WASM32.md` and downstream artifact pins.

The skill owns the canonical patch order, required commit trailers, upstream-bump procedure, release gate,
and downstream handoff.
