---
name: maintain-wasm32-fork
description: Maintain the lambdasistemi Plutus wasm32 fork as a small, dependency-ordered patch stack. Load this skill whenever a user asks to rebase or bump the fork to a new upstream Plutus tag, reorganize or squash wasm32 commits, repair 32-bit evaluator semantics, change the WASI/Nix test harness, cut or revise a version-wasm32.revision release, edit `.github/workflows/wasm32-*`, refresh `WASM32.md`, or bump a downstream consumer such as plutus-browser. It enforces immutable tags, six named commit layers, exact trailers, full remote wasm CI, published-asset checksum verification, and downstream pinning only after publication.
---

# Maintain the Plutus wasm32 fork

Keep the fork a rebase machine rather than a diary of incidents. Each published revision is rebuilt from
the exact upstream tag as six reviewable patches. Fixups belong inside their owning layer; dead add/remove
history does not cross a release boundary.

## Read the relevant contract

- For any history or commit change, read [`references/patch-stack.md`](references/patch-stack.md).
- For an upstream bump, same-base revision, release, or downstream update, also read
  [`references/upstream-bump.md`](references/upstream-bump.md).

## Non-negotiable invariants

1. Preserve every published tag. A repair increments `.rev`; it never moves a tag.
2. Start a new revision branch from the exact upstream tag in a separate worktree.
3. Build exactly these layers, in order: `semantics`, `tests`, `build`, `automation`, `docs`, `governance`.
4. Give every commit one `Wasm32-Patch` trailer and one `Wasm32-Upstream` trailer.
5. Let one layer own each changed path. If a later concern needs the same file, redesign the boundary or
   fold the change into the owning patch before publication.
6. Keep publication commands bound explicitly to `${{ github.repository }}` and pass `--repo` to every
   `gh release` operation.
7. Do not publish until the branch's full remote `Wasm32 Testsuite` is green.
8. After publication, download the public assets and verify `SHA256SUMS` independently before updating a
   downstream consumer.

## Commit loop

After each layer, run the prefix check:

```sh
skills/maintain-wasm32-fork/scripts/check-stack.sh <upstream-tag>
```

Before push and again before tagging, require the complete stack:

```sh
skills/maintain-wasm32-fork/scripts/check-stack.sh <upstream-tag> --complete \
  --release-tag <upstream-version>-wasm32.<rev>
```

The script rejects merge commits, missing or reordered layers, duplicate path ownership, fixup/WIP
subjects, whitespace errors, missing discovery files, stale release pins in consumer examples, and release
publication that can fall back to Git remote autodetection.

## Release boundary

Version the fork as `<upstream-version>-wasm32.<rev>`: `.0` is the first release on a new upstream base;
increment the revision for same-base repairs. The tag must contain the workflow that publishes it. Treat a
green workflow as necessary but not sufficient: query the public release API, verify the exact tag target,
download every expected asset, and run `sha256sum -c SHA256SUMS`.

Update downstream pins only after those checks pass. Record the release URL, tag SHA, workflow URL,
artifact names/sizes/digests, checksum result, and downstream verification in the durable status record.
