{ lib }:

{
  indexState = {
    hackage = "2026-06-23T00:00:00Z";
    chap = "2026-06-18T17:45:00Z";
  };

  pins = {
    cborg = {
      location = "https://github.com/amesgen/cborg";
      rev = "2dff24d241d9940c5a7f5e817fcf4c1aa4a8d4bf";
      sha256 = "18zasdb78by914pi6lb7hvi42jqh6pr76r6j5ryl1l4hj9mgbv6a";
      subdirs = [ "cborg" ];
    };

    hs-memory = {
      location = "https://github.com/haskell-wasm/hs-memory.git";
      rev = "a198a76c584dc2cfdcde6b431968de92a5fed65e";
      sha256 = "1q4dxijzxc0z67g2yqxcigzwq9xwgdfyqll6kazmznvxw8pvf41d";
      subdirs = [ ];
    };

    foundation = {
      location = "https://github.com/Jimbo4350/foundation.git";
      rev = "b3cb78484fe6f6ce1dfcef59e72ceccc530e86ac";
      sha256 = "072c4bl29v1xs8vd1q9iizv218jmpdks005wxn1i2wz8ynbqg8j0";
      subdirs = [
        "basement"
        "foundation"
      ];
    };

    double-conversion = {
      location = "https://github.com/palas/double-conversion.git";
      rev = "b2030245727ee56de76507fe305e3741f6ce3260";
      sha256 = "1gad7zrb2cqxvxslvbx36m5hddlv50q4hrrv43kz6gf71hfhfg4k";
      subdirs = [ ];
    };

    criterion-measurement = {
      location = "https://github.com/palas/criterion.git";
      rev = "dd160d2b5f051e918e72fe1957d77905682b8d6c";
      sha256 = "19svb598gx6lmb5xly9fspd9wnszyygxplh9vl1bs56y8hwk0cf3";
      subdirs = [ "criterion-measurement" ];
    };

    network = {
      location = "https://github.com/haskell-wasm/network";
      rev = "ab92e48e9fdf3abe214f85fdbe5301c1280e14e9";
      sha256 = "0shdyfjfrzixz7sh45j9czsbylfhbb9wjirn6rlhd8fp0vz6gsak";
      subdirs = [ ];
    };
  };

  packageFlags = {
    plutus-core = "+do-not-build-plutus-exec";
    cardano-crypto-praos = "-external-libsodium-vrf";
    atomic-counter = "+no-cmm";
    digest = "-pkg-config";
  };

  packageGhcOptions = {
    crypton = "-optc-DARGON2_NO_THREADS";
  };

  constraints = [ "time installed" ];
  allowNewer = [
    "*:template-haskell"
    "*:base"
    "*:deepseq"
    "*:ghc-prim"
    "*:time"
    "*:text"
  ];
}
