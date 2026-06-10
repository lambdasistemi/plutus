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
  pname = "plutus-wasm-uplc";
  depsPname = "plutus-wasm-uplc-deps";
  prebuiltDepsPname = "plutus-wasm-uplc-prebuilt-deps";
  dependenciesHash = "sha256-+sp89szv8Nia3ZBYTu8gL5jQERUEZdK2TUfGE1oMwE0=";
  sourcePatch = ''
    sed -i 's/if (impl(ghc <9.6) || impl(ghc >=9.7))/if !((impl(ghc >=9.6) \&\& impl(ghc <9.7)) || (impl(ghc >=9.12) \&\& impl(ghc <9.13)))/' \
      "$out/plutus-executables/plutus-executables.cabal"
    sed -i '/^executable plutus$/a\
      if arch(wasm32)\
        buildable: False\
' "$out/plutus-executables/plutus-executables.cabal"
  '';
  cleanupPackageNames = [
    "plutus-core"
    "plutus-executables"
    "plutus-ledger-api"
    "plutus-metatheory"
    "plutus-tx"
  ];
  components = [
    {
      target = "plutus-executables:exe:uplc";
      wasmName = "uplc";
      outputName = "uplc";
    }
  ];
}
