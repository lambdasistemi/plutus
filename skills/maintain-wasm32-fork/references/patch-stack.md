# Patch-stack contract

## Canonical layers

Every release revision contains exactly one commit for each layer, in this order:

| Layer | Owns | Must not contain |
| --- | --- | --- |
| `semantics` | 32-bit evaluator corrections and 64-bit-neutral guards | test harness, Nix, CI, docs |
| `tests` | WASI portability, properties, goldens, Cabal test declarations | evaluator behavior, Nix, CI |
| `build` | Cabal wasm projects, Nix cross toolchain, C libraries, flake outputs | GitHub workflows, prose |
| `automation` | wasm test, release, and redirect workflows | evaluator or test source |
| `docs` | `WASM32.md` and curated release notes | agent policy or executable code |
| `governance` | `AGENTS.md`, repository skills, discovery pointers | evaluator or build behavior |

This order makes dependencies flow forward: semantics are testable, tests are buildable, outputs are
automated, automation is documented, and the finished shape becomes the next maintenance contract.

## Required commit shape

Use a focused conventional subject and these exact trailers:

```text
fix(wasm): preserve evaluator semantics on 32-bit hosts

Wasm32-Patch: semantics
Wasm32-Upstream: 1.67.0.0
```

Valid `Wasm32-Patch` values are the six layer names above. `Wasm32-Upstream` is the exact upstream tag, not
a branch, SHA abbreviation, or fork release tag.

## Clarity rules

- One layer owns each changed path. Repeated path ownership usually means the commits narrate repair order
  instead of presenting the final design.
- Fold conflict adaptation into the layer whose invariant changed.
- Drop net-zero experiments such as adding and later removing an application.
- Keep generated goldens with the tests that consume them.
- Keep the standalone evaluator output with the build layer; keep its publication with automation.
- Never leave `fixup!`, `squash!`, `WIP`, typo-only, or incident-only commits in a release stack.
- Each intermediate commit should remain structurally valid. The full wasm runtime gate applies to the
  complete stack because earlier layers intentionally precede their build harness.

## Review commands

```sh
git log --reverse --format='%h %s%n%(trailers:key=Wasm32-Patch,valueonly)' <upstream-tag>..HEAD
skills/maintain-wasm32-fork/scripts/check-stack.sh <upstream-tag> --complete \
  --release-tag <upstream-version>-wasm32.<rev>
git diff --check <upstream-tag>..HEAD
```

For a same-base revision, compare the new and previous release trees. Exclude only named intentional
documentation/governance changes; every unexplained code or build difference is a blocker.
