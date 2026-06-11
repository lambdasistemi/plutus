# Plutus on wasm32 — a 32-bit-correct fork

This is a fork of [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) that makes Plutus
**evaluate correctly on wasm32** (`WORD_SIZE_IN_BITS == 32`) — byte-identical to the 64-bit on-chain
evaluator — and proves it by running upstream's own test suite under `wasmtime`.

It exists for **client-side / browser evaluation of Cardano scripts** — wallets, untrusted verifiers,
budget/fee estimation (the use case in [IntersectMBO/plutus#6040](https://github.com/IntersectMBO/plutus/issues/6040)).
Upstream assumes a 64-bit machine word and silently diverges on wasm32; this fork fixes that **without
changing what the node compiles**.

**▶ Try it live:** [lambdasistemi.github.io/plutus-browser](https://lambdasistemi.github.io/plutus-browser/) —
paste/edit UPLC and evaluate it in your browser (result + `ExBudget`), powered by this fork's `uplc.wasm`. The
browser app is its own project: [lambdasistemi/plutus-browser](https://github.com/lambdasistemi/plutus-browser)
(this fork is the evaluator library it depends on).

## Releases (we track upstream)

Fork releases are tagged **`<upstream-version>-wasm32.<rev>`**:

- `<upstream-version>` — the exact upstream Plutus release this is rebased onto.
- `<rev>` — our revision/bugfix counter against that upstream base. It increments for each fork release on
  the same base and **resets when the upstream version bumps** (e.g. `1.66.x.x-wasm32.1`). The first cut on a
  base may omit the `.<rev>` suffix.

Tags are **immutable**: a fix ships as the next `.<rev>`, never by moving a published tag. The GitHub Releases
are the changelog of our divergence — each documents what changed and ships the prebuilt `uplc.wasm`. Pin the
exact tag you want.

| Fork tag | Tracks upstream | Status |
|----------|-----------------|--------|
| `1.65.0.0-wasm32.1` | `1.65.0.0` | **recommended** — full suite green; 64-bit neutral (platform-`Int` unlift hardened) |
| `1.65.0.0-wasm32` | `1.65.0.0` | superseded by `.1` (non-neutral platform-`Int` unlift) |

## What we changed vs upstream

Every behavioural change is gated behind `#if WORD_SIZE_IN_BITS == 64`, so **the source a 64-bit node
compiles is byte-identical to upstream** (verified: the affected suites pass unchanged on x86_64). The
fork's job is to *preserve* on-chain semantics on a platform the node never runs on, not to change them.

| Area | Change | Why |
|------|--------|-----|
| builtins | bounds-check index/length in `Integer` space **before** narrowing to platform `Int` — `sliceByteString`, `indexByteString`, `readBit`, `indexArray`, `shiftByteString`, `rotateByteString`, `integerToByteString` | platform `Int` is 32-bit on wasm32, so the old narrow-then-check silently wraps; the `#if WORD_SIZE_IN_BITS==64` branch keeps the node path identical |
| KnownType | real `Int`/`Word` lift/unlift instances on 32-bit | upstream's `#else` branch is a poison pill (`error "UPLC evaluation is not supported on non-64-bit platforms"`) |
| tests | enable the suites on wasm32: lift `buildable: False`, gate `-threaded` off (no threaded wasm RTS), compare goldens in-process (WASI can't spawn `diff`), 32-bit signature golden set under `Signatures32/`, SatInt test derives width from its `Int64` payload, `flat-big-test` gated (multi-GB stress, incompatible with wasm32's 4 GB space) | run upstream's own suite as the proof |
| CI | cachix-cached `runs-on: nixos` wasm32 testsuite — `nix/wasm/mkPlutusWasmTests.nix` (two-phase FOD) → `.#wasm-<suite>` → `wasmtime` | reproducible proof; the wasm dep closure compiles once and is cached |

Verified on the `1.65.0.0-wasm32.1` release: `plutus-core-test` 2294, `untyped-plutus-core-test` 870,
`plutus-ir-test` 332, `index-envs-test` 36, `satint-test` 17, `flat-test` 1491 — all green under wasmtime.

## How to use the wasm artifacts

### 1. Embed in your own wasm (wallets, verifiers) — source dependency

Plutus is a *library* you link into your own wasm. Pin this fork and cross-compile:

```cabal
source-repository-package
  type: git
  location: https://github.com/lambdasistemi/plutus.git
  tag: 1.65.0.0-wasm32.1
  subdir: plutus-core plutus-ledger-api plutus-tx
```

Builds are cached in the `paolino` cachix cache, so you pull the prebuilt wasm dep closure instead of
recompiling. This is how `cardano-ledger-wasi` and `cardano-mpfs-offchain` consume the fork.

**Verified end-to-end:** repinning `cardano-ledger-wasi` to this rev builds `wasm-tx-inspector.wasm`
with no API changes, and its `tx.evaluate.scripts` smoke evaluates a real transaction's Plutus scripts
on wasm32 → `ExUnits` `memory=376813, steps=369294715` (within budget). The corrected builtins evaluate
identically to the 64-bit chain inside the real consumer.

### 2. Standalone evaluator — `uplc.wasm` (no Haskell toolchain)

Download `uplc.wasm` from the [release](https://github.com/lambdasistemi/plutus/releases) and run the
real CEK + cost model on a UPLC program. Verified under wasmtime:

```sh
printf '(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])' > add.uplc
wasmtime run --dir . --dir /tmp uplc.wasm -- evaluate -i add.uplc       # -> (con integer 42)
wasmtime run --dir . --dir /tmp uplc.wasm -- evaluate -i add.uplc -c    # adds CPU budget: 181308 / Memory budget: 602
```

`-i` reads a UPLC program file (or pipe to stdin); `-c` adds the `ExBudget`. It runs the same under a
browser WASI shim — the "real CEK in the browser" use case.

### 3. Reproduce the proof (verified end-to-end)

Needs a checkout — the goldens / `test/data` are in the source, not the `.wasm`:

```sh
git clone -b 1.65.0.0-wasm32.1 https://github.com/lambdasistemi/plutus && cd plutus
nix build .#wasm-plutus-core-test
WASMTIME=$(nix build --no-link --print-out-paths .#wasm-toolchain)/bin/wasmtime
( cd plutus-core && "$WASMTIME" run --dir . --dir /tmp \
    ../result/plutus-core-test.wasm --hedgehog-tests 1000 --no-create )
# -> All 2294 tests passed
```

To just *build* the artifact without cloning: `nix build github:lambdasistemi/plutus/1.65.0.0-wasm32.1#wasm-plutus-core-test`
— **the ref is required**; bare `github:lambdasistemi/plutus` is the default branch and has no wasm targets.

The `🕸️ Wasm32 Testsuite` workflow (`.github/workflows/wasm32-testsuite.yml`, `runs-on: nixos`,
cachix-cached) runs the full matrix on every push.

## Maintaining the fork (rebasing onto a new upstream release)

The fork is a thin stack of ~7 commits on the upstream release tag — a "rebase machine":

1. `git rebase --onto <new-upstream-tag> <old-upstream-tag> wasm32-<old>`.
2. Resolve conflicts — they only occur where upstream edited the same gated denotation, which is exactly
   the signal to re-derive the 32-bit variant.
3. Regenerate `Signatures32/` goldens if signatures changed (run the suite with `--accept`).
4. Push the branch and wait for `wasm32-testsuite.yml` to go green (it re-proves the full matrix).
5. Cut the release **only after the branch is green**: pick the tag per the scheme above — `<new-upstream>-wasm32.1`
   after a rebase, or the next `.<rev>` for a bugfix on the same base. Optionally hand-write
   `wasm32-release-notes/<tag>.md` (otherwise notes are generated from the changelog). Then tag and push:

   ```sh
   git tag <tag>
   git push git@github.com:lambdasistemi/plutus.git <tag>   # SSH: the OAuth token lacks `workflow` scope
   ```

   The `🕸️ Wasm32 Release` workflow (`.github/workflows/wasm32-release-assets.yml`) then builds `.#wasm-uplc`,
   smoke-tests it under wasmtime, and publishes the GitHub Release with `uplc.wasm` + `SHA256SUMS` attached —
   no manual upload. (A tag-push runs the workflow from the *tagged* commit's tree, so make sure the tagged
   commit contains this workflow.)
