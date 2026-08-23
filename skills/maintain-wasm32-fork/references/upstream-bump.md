# Upstream bump and release guideline

## Choose the version

- New upstream base: `<upstream-version>-wasm32.0`.
- Repair on the same base: increment the fork revision (`.0` → `.1` → `.2`).
- Never reuse or move a published tag.

## Rebuild the branch

1. Fetch and verify the exact upstream tag.
2. Create a separate worktree and branch named `wasm32-<upstream-version>-r<rev>` at that tag.
3. Re-derive the six patches in canonical order. Use the previous final tree as evidence, not as permission
   to replay obsolete chronology.
4. Resolve upstream edits semantically. In particular, re-check every `WORD_SIZE_IN_BITS` guard and every
   conversion that narrows `Integer` to platform `Int` or `Word`.
5. Regenerate 32-bit signatures and other goldens from the new upstream code.
6. Refresh Cabal index states, fixed-output hashes, package lists, test counts, release notes, usage examples,
   and every operational version pin.
7. Run the stack checker after every commit and with `--complete --release-tag <fork-tag>` at the end. The
   release-tag check rejects stale download, Cabal, clone, Nix, or curated-note pins.

## Prove the candidate

Before push, run every permitted structural and warm gate: stack checker, `git diff --check`, YAML parse,
target workflow lint, release-repository regression, and exact tree comparison for same-base revisions.
Respect host build interlocks; do not turn a blocked cold realization into an undocumented exception.

Push the revision branch without force. The remote `Wasm32 Testsuite` must pass every build and runtime
step, including the upstream conformance corpus. Record the exact branch SHA and run/job URLs.

## Publish and verify

1. Confirm the tag is absent locally and remotely.
2. Create a lightweight immutable tag at the green branch SHA and push it without force.
3. Monitor the tag-triggered release workflow. The tag's tree must contain the publication workflow.
4. Query the public release and confirm: correct tag, non-draft, non-prerelease, latest, and the exact assets.
5. Download `uplc.wasm` and `SHA256SUMS` into a fresh directory and run `sha256sum -c SHA256SUMS`.
6. Confirm the public tag resolves to the candidate SHA and record the artifact digest and size.

## Update downstreams

Only after publication verification, update consumers such as `lambdasistemi/plutus-browser` to the exact
new tag or release URL and checksum. Run the downstream's own build and browser smoke tests, push its branch,
and verify remote CI. Never point a consumer at a branch or an asset that is merely expected to appear.
