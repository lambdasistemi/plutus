# Two-phase wasm32-wasi test-suite builder.
#
# The fixed-output `deps` derivation downloads the cabal package cache once.
# The regular `prebuiltDeps` derivation compiles the wasm dependency closure
# once and can be pushed to Cachix. The final derivation recompiles only the
# local plutus-core sources and links the requested test-suite executables.
{ pkgs
, lib
, ghcWasmMeta
, wasiSdk
, chap
}:

{ src
, satintSrc
, suites ? [ ]
, components ? map
    (suite: {
      target = "plutus-core:test:${suite}";
      wasmName = suite;
      outputName = suite;
    })
    suites
, dependenciesHash
, pname ? "plutus-wasm-tests"
, depsPname ? "${pname}-deps"
, prebuiltDepsPname ? "${pname}-prebuilt-deps"
, cleanupPackageNames ? [ "plutus-core" ]
, sourcePatch ? ""
, projectFile ? "cabal-wasm.project"
}:

let
  haskell-nix = pkgs.haskell-nix;
  fragment = import ./cabal-project-fragment.nix { inherit lib; };
  hackageIndexState = fragment.indexState.hackage;

  buildTargets = map (component: component.target) components;
  buildTargetsArg = lib.concatStringsSep " \\\n      " buildTargets;

  truncatedHackageIndex = pkgs.fetchurl {
    name = "01-index.tar.gz-at-${hackageIndexState}";
    url = "https://hackage.haskell.org/01-index.tar.gz";
    downloadToTemp = true;
    postFetch = ''
      ${haskell-nix.nix-tools}/bin/truncate-index \
        -o $out -i $downloadedFile -s '${hackageIndexState}'
    '';
    outputHashAlgo = "sha256";
    outputHash = (import haskell-nix.indexStateHashesPath).${hackageIndexState};
  };

  bootstrappedHackage = pkgs.runCommand "plutus-wasm-cabal-hackage" {
    nativeBuildInputs = [ haskell-nix.nix-tools.exes.cabal ]
      ++ haskell-nix.cabal-issue-8352-workaround;
  } ''
    HOME=$(mktemp -d)
    mkdir -p $HOME/.cabal/packages/hackage.haskell.org
    cat > $HOME/.cabal/config <<EOF
    repository hackage.haskell.org
      url: file:${
        haskell-nix.mkLocalHackageRepo {
          name = "hackage.haskell.org";
          index = truncatedHackageIndex;
        }
      }
      secure: True
      root-keys: aaa
      key-threshold: 0
    EOF
    cabal v2-update hackage.haskell.org
    cp -r $HOME/.cabal/packages/hackage.haskell.org $out
  '';

  bootstrappedChap = pkgs.runCommand "plutus-wasm-cabal-chap" {
    nativeBuildInputs = [ haskell-nix.nix-tools.exes.cabal ]
      ++ haskell-nix.cabal-issue-8352-workaround;
  } ''
    HOME=$(mktemp -d)
    mkdir -p $HOME/.cabal/packages/cardano-haskell-packages
    cat > $HOME/.cabal/config <<EOF
    repository cardano-haskell-packages
      url: file:${chap}
      secure: True
      root-keys:
        3e0cce471cf09815f930210f7827266fd09045445d65923e6d0238a6cd15126f
        443abb7fb497a134c343faf52f0b659bd7999bc06b7f63fa76dc99d631f9bea1
        a86a1f6ce86c449c46666bda44268677abf29b5b2d2eb5ec7af903ec2f117a82
        bcec67e8e99cabfa7764d75ad9b158d72bfacf70ca1d0ec8bc6b4406d1bf8413
        c00aae8461a256275598500ea0e187588c35a5d5d7454fb57eac18d9edb86a56
        d4a35cd3121aa00d18544bb0ac01c3e1691d618f462c46129271bccf39f7e8ee
      key-threshold: 3
    EOF
    cabal v2-update cardano-haskell-packages
    cp -r $HOME/.cabal/packages/cardano-haskell-packages $out
  '';

  dotCabal = pkgs.runCommand "plutus-wasm-dot-cabal" {
    nativeBuildInputs = [ pkgs.xorg.lndir ];
  } ''
    mkdir -p $out/packages/hackage.haskell.org
    lndir ${bootstrappedHackage} $out/packages/hackage.haskell.org

    mkdir -p $out/packages/cardano-haskell-packages
    lndir ${bootstrappedChap} $out/packages/cardano-haskell-packages

    cat > $out/config <<EOF
    repository hackage.haskell.org
      url: http://hackage.haskell.org/
      secure: True

    repository cardano-haskell-packages
      url: https://chap.intersectmbo.org/
      secure: True
      root-keys:
        3e0cce471cf09815f930210f7827266fd09045445d65923e6d0238a6cd15126f
        443abb7fb497a134c343faf52f0b659bd7999bc06b7f63fa76dc99d631f9bea1
        a86a1f6ce86c449c46666bda44268677abf29b5b2d2eb5ec7af903ec2f117a82
        bcec67e8e99cabfa7764d75ad9b158d72bfacf70ca1d0ec8bc6b4406d1bf8413
        c00aae8461a256275598500ea0e187588c35a5d5d7454fb57eac18d9edb86a56
        d4a35cd3121aa00d18544bb0ac01c3e1691d618f462c46129271bccf39f7e8ee
      key-threshold: 3

    executable-stripping: False
    shared: True
    EOF
  '';

  sandboxName = "plutus-wasm-tests-src";
  sourceTreeNames = [ "app" "src" "test" "tests" "bench" "benchmarks" ];
  moduleInventoryFields =
    [ "exposed-modules" "other-modules" "autogen-modules" "signatures" ];

  lineIndent = line:
    let match = builtins.match "([ ]*).*" line;
    in
    builtins.stringLength (builtins.elemAt match 0);

  isBlankLine = line:
    builtins.match "[ \t]*" line != null;

  isSatIntExposure = line:
    builtins.match "[ ]*exposed-modules:[ ]*Data[.]SatInt[ ]*" line != null;

  stripModuleInventory = text:
    let
      fieldPattern =
        "([ ]*)(${lib.concatStringsSep "|" moduleInventoryFields}):.*";

      processLine = state: line:
        let fieldMatch = builtins.match fieldPattern line;
        in
        if isSatIntExposure line then
          {
            skipping = false;
            skipIndent = 0;
            lines = state.lines ++ [ line ];
          }
        else if fieldMatch != null then
          let
            indent = builtins.elemAt fieldMatch 0;
            field = builtins.elemAt fieldMatch 1;
          in
          {
            skipping = true;
            skipIndent = builtins.stringLength indent;
            lines = state.lines ++ [ "${indent}${field}:" ];
          }
        else
          {
            skipping = false;
            skipIndent = 0;
            lines = state.lines ++ [ line ];
          };

      step = state: line:
        if state.skipping then
          if isBlankLine line then
            state
          else if lineIndent line > state.skipIndent then
            state
          else
            processLine (state // { skipping = false; skipIndent = 0; }) line
        else
          processLine state line;

      result =
        builtins.foldl' step
          { skipping = false; skipIndent = 0; lines = [ ]; }
          (lib.splitString "\n" text);
    in
    lib.concatStringsSep "\n" result.lines;

  collectMetadataFiles = prefix: path:
    lib.concatLists (
      lib.mapAttrsToList
        (name: type:
          let
            relPath = if prefix == "" then name else "${prefix}/${name}";
            childPath = path + "/${name}";
          in
          if type == "directory" then
            if builtins.elem name sourceTreeNames
            then [ ]
            else collectMetadataFiles relPath childPath
          else if
            relPath == projectFile
            || relPath == "cabal.project"
            || lib.hasSuffix ".cabal" name
          then
            [{ inherit relPath; path = childPath; }]
          else
            [ ])
        (builtins.readDir path)
    );

  metadataFiles =
    map
      (file:
        {
          inherit (file) relPath;
          text =
            if lib.hasSuffix ".cabal" file.relPath
            then stripModuleInventory (builtins.readFile file.path)
            else builtins.readFile file.path;
        })
      (collectMetadataFiles "" src);

  srcMetadata = pkgs.runCommand sandboxName { } (
    lib.concatMapStringsSep "\n"
      (file:
        let
          dir = builtins.dirOf file.relPath;
          fileText =
            pkgs.writeText
              "wasm-dependency-metadata-${builtins.baseNameOf file.relPath}"
              file.text;
        in
        ''
          mkdir -p "$out/${dir}"
          cp ${fileText} "$out/${file.relPath}"
        '')
      metadataFiles
    + ''
      mkdir -p "$out/plutus-core/satint"
      cp -rL ${satintSrc} "$out/plutus-core/satint/src"
      ${sourcePatch}
    ''
  );

  renamedSrc = pkgs.runCommand sandboxName { } ''
    mkdir -p $out
    cp -rL ${src}/. $out/
    chmod -R u+w $out
    ${sourcePatch}
  '';

  fetchFork = name:
    let pin = fragment.pins.${name};
    in
    pkgs.fetchgit {
      url = pin.location;
      rev = pin.rev;
      hash = "sha256:${pin.sha256}";
    };

  prefetchedForks = lib.genAttrs (builtins.attrNames fragment.pins) fetchFork;

  forkPackageLines = lib.concatLists (
    map
      (name:
        let pin = fragment.pins.${name};
        in
        if pin.subdirs == [ ]
        then [ "  ${prefetchedForks.${name}}" ]
        else map (sub: "  ${prefetchedForks.${name}}/${sub}") pin.subdirs)
      (builtins.attrNames fragment.pins)
  );

  forkPackagesBlock =
    if forkPackageLines == [ ]
    then ""
    else "packages:\n" + lib.concatStringsSep "\n" forkPackageLines + "\n";

  cLibs = import ../wasm32-c-libs {
    inherit pkgs;
    wasi-sdk = wasiSdk;
  };

  cLibsInputs = cLibs.all ++ [ pkgs.pkg-config ];
  cLibsExtraLibDirs = [
    "${cLibs.libsodium}/lib"
    "${cLibs.secp256k1}/lib"
    "${cLibs.blst}/lib"
  ];
  cLibsExtraIncludeDirs = [
    "${cLibs.libsodium}/include"
    "${cLibs.secp256k1.dev}/include"
    "${cLibs.blst}/include"
  ];
  cabalExtraDirsArgs = lib.concatStringsSep " " (
    (map (dir: "--extra-lib-dirs=${dir}") cLibsExtraLibDirs)
    ++ (map (dir: "--extra-include-dirs=${dir}") cLibsExtraIncludeDirs)
  );

  nativeWasmBuildInputs = [
    ghcWasmMeta
    pkgs.git
    pkgs.haskellPackages.tasty-discover
  ] ++ cLibsInputs;

  cabalBuildCommon = ''
    export CABAL_DIR=$NIX_BUILD_TOP/cabal
    export PKG_CONFIG_PATH=${cLibs.pkgConfigPath}
  '';

  deps = pkgs.stdenv.mkDerivation {
    pname = depsPname;
    version = "1.65.0.0";
    src = srcMetadata;

    nativeBuildInputs = [
      ghcWasmMeta
      pkgs.cacert
      pkgs.git
      pkgs.curl
      pkgs.haskellPackages.tasty-discover
    ] ++ cLibsInputs;

    buildPhase = ''
      export HOME=$NIX_BUILD_TOP/home
      mkdir -p $HOME
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export CURL_CA_BUNDLE=$SSL_CERT_FILE

      export CABAL_DIR=$NIX_BUILD_TOP/cabal
      mkdir -p $CABAL_DIR
      cp -rL ${dotCabal}/* $CABAL_DIR/
      chmod -R u+w $CABAL_DIR
      export PKG_CONFIG_PATH=${cLibs.pkgConfigPath}

      wasm32-wasi-cabal --project-file=${projectFile} build \
        --only-download \
        --ignore-build-tools \
        ${cabalExtraDirsArgs} \
        ${buildTargetsArg}
    '';

    installPhase = ''
      mkdir -p $out
      cp -r $CABAL_DIR/* $out/
      find $out -name 'hackage-security-lock' -delete
      find $out -name '01-index.timestamp' -delete
    '';

    outputHashMode = "recursive";
    outputHash = dependenciesHash;
  };

  prebuiltDeps = pkgs.stdenv.mkDerivation {
    pname = prebuiltDepsPname;
    version = "1.65.0.0";
    src = srcMetadata;

    nativeBuildInputs = nativeWasmBuildInputs;

    configurePhase = ''
      export HOME=$NIX_BUILD_TOP/home
      mkdir -p $HOME

      export CABAL_DIR=$NIX_BUILD_TOP/cabal
      mkdir -p $CABAL_DIR
      cp -rL ${deps}/* $CABAL_DIR/
      chmod -R u+w $CABAL_DIR
      export PKG_CONFIG_PATH=${cLibs.pkgConfigPath}

      sed -i '/^source-repository-package/,/^$/d' ${projectFile}
      cat >> ${projectFile} <<'EOF'
      ${forkPackagesBlock}
      EOF
    '';

    buildPhase = ''
      ${cabalBuildCommon}
      wasm32-wasi-cabal --project-file=${projectFile} build \
        --only-dependencies \
        --ignore-build-tools \
        ${cabalExtraDirsArgs} \
        ${buildTargetsArg}
    '';

    installPhase = ''
      mkdir -p $out
      cp -rL $CABAL_DIR $out/cabal
      cp -rL dist-newstyle $out/dist-newstyle
      mkdir -p "$(dirname "$out/${projectFile}")"
      cp ${projectFile} $out/${projectFile}
      chmod -R u+w $out
    '';
  };

  wasm = pkgs.stdenv.mkDerivation {
    pname = pname;
    version = "1.65.0.0";
    src = renamedSrc;

    nativeBuildInputs = nativeWasmBuildInputs;

    configurePhase = ''
      export HOME=$NIX_BUILD_TOP/home
      mkdir -p $HOME

      export CABAL_DIR=$NIX_BUILD_TOP/cabal
      mkdir -p $CABAL_DIR
      cp -rL ${prebuiltDeps}/cabal/* $CABAL_DIR/
      chmod -R u+w $CABAL_DIR
      export PKG_CONFIG_PATH=${cLibs.pkgConfigPath}

      cp -rL ${prebuiltDeps}/dist-newstyle dist-newstyle
      chmod -R u+w dist-newstyle

      rm -f ${projectFile}
      cp ${prebuiltDeps}/${projectFile} ${projectFile}
      chmod u+w ${projectFile}

      ${lib.concatMapStringsSep "\n" (packageName: ''
        find dist-newstyle/build -mindepth 3 -maxdepth 3 -type d \
          -path '*/wasm32-wasi/*' -name '${packageName}-*' \
          -exec rm -rf {} +
        find dist-newstyle -name 'package.conf.d' -exec sh -c '
          package_name="$1"
          shift
          for dir; do
            for entry in "$dir"/"$package_name"-*-inplace*.conf; do
              [ -e "$entry" ] && rm -f "$entry"
            done
          done
        ' sh '${packageName}' {} +
      '') cleanupPackageNames}
    '';

    buildPhase = ''
      ${cabalBuildCommon}
      wasm32-wasi-cabal --project-file=${projectFile} build \
        --ignore-build-tools \
        ${cabalExtraDirsArgs} \
        ${buildTargetsArg}
    '';

    installPhase = ''
      mkdir -p $out
      ${lib.concatMapStringsSep "\n" (component: ''
        wasm=$(find dist-newstyle -name "${component.wasmName}.wasm" -type f | head -1)
        if [ -z "$wasm" ]; then
          echo "missing wasm output for ${component.wasmName}" >&2
          exit 1
        fi
        cp "$wasm" "$out/${component.outputName}.wasm"
      '') components}
    '';

    passthru = {
      inherit deps prebuiltDeps;
    };
  };
in
wasm
