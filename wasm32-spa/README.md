# Browser uplc evaluator (SPA)

A static single-page app that runs `uplc.wasm` (the real CEK + cost model) **in the browser** via
[`@bjorn3/browser_wasi_shim`](https://github.com/bjorn3/browser_wasi_shim): paste a UPLC program,
evaluate it, see the result and (optionally) the `ExBudget`. The "real CEK in the browser" demo.

## Build

```sh
cd wasm32-spa
npm ci
npm run build          # nix build ..#wasm-uplc -> src/assets/uplc.wasm, then esbuild -> dist/
```

`npm run build` requires `nix` (it builds `..#wasm-uplc`) and produces `dist/` (the static site).
`uplc.wasm` and `dist/` are generated, not committed.

## Serve locally

```sh
npm run serve          # http://localhost:4173
```

## Test (playwright, headless)

```sh
# On NixOS the downloaded playwright chromium won't run (missing system libs);
# point it at a nix-provided chromium:
PLAYWRIGHT_CHROMIUM_EXECUTABLE=$(nix build --no-link --print-out-paths nixpkgs#chromium)/bin/chromium \
  npm test
```

Verified output for `(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])`:

```
(con integer 42)
CPU budget:    181308
Memory budget: 602
```

## Deploy

`.github/workflows/wasm32-spa-pages.yml` builds and deploys this to GitHub Pages on push to a
`wasm32-*` branch (requires Pages enabled with source "GitHub Actions").
