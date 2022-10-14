{ system
, compiler
, flags
, pkgs
, hsPkgs
, pkgconfPkgs
, ... }:
  {
    flags = {};
    package = {
      specVersion = "1.10";
      identifier = {
        name = "bcc-sl-crypto-test";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2016 TBCO";
      maintainer = "hi@serokell.io";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL - arbitrary instances for bcc-sl-crypto";
      description = "This package contains arbitrary instances for the cryptography primitives used in Bcc SL.";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.QuickCheck)
          (hsPkgs.base)
          (hsPkgs.bytestring)
          (hsPkgs.bcc-crypto)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-binary-test)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.bcc-sl-util-test)
          (hsPkgs.cryptonite)
          (hsPkgs.generic-arbitrary)
          (hsPkgs.hedgehog)
          (hsPkgs.memory)
          (hsPkgs.quickcheck-instances)
          (hsPkgs.universum)
        ];
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-sl";
      rev = "632769d4480d3b19299d801c9fb39e75d20dd7d9";
      sha256 = "1l9i62fdgcl2spgaag70bxnm2rz996bl6g5nhmhj5m5fwn4sy2b9";
    };
    postUnpack = "sourceRoot+=/crypto/test; echo source root reset to \$sourceRoot";
  }
