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

  suites = [
    "plutus-core-test"
    "untyped-plutus-core-test"
    "plutus-ir-test"
    "index-envs-test"
    "satint-test"
    "flat-test"
  ];

  allTests = mkPlutusWasmTests {
    inherit src satintSrc suites;
    dependenciesHash = "sha256-K11poN6mD2nnOzkdEr55JJ8y2tvOh0TQQiluM3kH64M=";
  };

  mkSuitePackage = suite:
    pkgs.runCommand "wasm-${suite}" { } ''
      mkdir -p $out
      cp ${allTests}/${suite}.wasm $out/${suite}.wasm
    '';
in
lib.genAttrs (map (suite: "wasm-${suite}") suites)
  (name: mkSuitePackage (lib.removePrefix "wasm-" name))
