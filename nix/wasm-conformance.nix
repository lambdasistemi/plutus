{ pkgs
, lib
, ghcWasmMeta
, wasiSdk
, chap
, src
, satintSrc
}:

let
  mkPlutusWasmTests = import ./wasm/mkPlutusWasmTests.nix {
    inherit pkgs lib ghcWasmMeta wasiSdk chap;
  };
in
mkPlutusWasmTests {
  inherit src satintSrc;
  projectFile = "cabal-wasm-conformance.project";
  pname = "plutus-wasm-conformance";
  depsPname = "plutus-wasm-conformance-deps";
  prebuiltDepsPname = "plutus-wasm-conformance-prebuilt-deps";
  dependenciesHash = "sha256-JgeTyKhRIeibUeqEpOkImIDO25PVLccDcLiW0AbOBVQ=";
  cleanupPackageNames = [ "plutus-core" "plutus-conformance" ];
  components = [
    {
      target = "plutus-conformance:test:haskell-conformance";
      wasmName = "haskell-conformance";
      outputName = "haskell-conformance";
    }
  ];
}
