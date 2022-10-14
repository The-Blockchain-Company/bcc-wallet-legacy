{ system
, compiler
, flags
, pkgs
, hsPkgs
, pkgconfPkgs
, ... }:
  {
    flags = {
      golden-tests = false;
      golden-tests-exe = false;
    };
    package = {
      specVersion = "1.10";
      identifier = {
        name = "bcc-crypto";
        version = "1.1.0";
      };
      license = "MIT";
      copyright = "2016-2017 TBCO";
      maintainer = "contact@typed.io";
      author = "Vincent Hanquez";
      homepage = "https://github.com/the-blockchain-company/bcc-crypto#readme";
      url = "";
      synopsis = "Cryptography primitives for bcc";
      description = "";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.base)
          (hsPkgs.memory)
          (hsPkgs.deepseq)
          (hsPkgs.bytestring)
          (hsPkgs.basement)
          (hsPkgs.foundation)
          (hsPkgs.cryptonite)
          (hsPkgs.cryptonite-openssl)
          (hsPkgs.hashable)
          (hsPkgs.integer-gmp)
        ];
      };
      exes = {
        "golden-tests" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.basement)
            (hsPkgs.foundation)
            (hsPkgs.memory)
            (hsPkgs.bytestring)
            (hsPkgs.cryptonite)
            (hsPkgs.bcc-crypto)
          ] ++ pkgs.lib.optional (flags.golden-tests-exe) (hsPkgs.inspector);
        };
      };
      tests = {
        "bcc-crypto-test" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bytestring)
            (hsPkgs.memory)
            (hsPkgs.cryptonite)
            (hsPkgs.bcc-crypto)
            (hsPkgs.basement)
            (hsPkgs.foundation)
          ];
        };
        "bcc-crypto-golden-tests" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.basement)
            (hsPkgs.foundation)
            (hsPkgs.memory)
            (hsPkgs.bytestring)
            (hsPkgs.cryptonite)
            (hsPkgs.bcc-crypto)
          ] ++ pkgs.lib.optional (flags.golden-tests) (hsPkgs.inspector);
        };
      };
      benchmarks = {
        "bcc-crypto-bench" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bytestring)
            (hsPkgs.memory)
            (hsPkgs.cryptonite)
            (hsPkgs.bcc-crypto)
            (hsPkgs.gauge)
          ];
        };
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-crypto";
      rev = "45e1a0eafac774c109704be44ca06fd8cae193ba";
      sha256 = "1jyzai4sn9hi3p6r97h54f9a7an7vk38lwrbl4mds9zmdsw5f5ad";
    };
  }
