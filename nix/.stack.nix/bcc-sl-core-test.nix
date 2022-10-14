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
        name = "bcc-sl-core-test";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2018 TBCO";
      maintainer = "TBCO <support@iohk.io>";
      author = "TBCO";
      homepage = "";
      url = "";
      synopsis = "Bcc SL - core functionality (tests)";
      description = "QuickCheck Arbitrary instances for the Bcc SL core\nfunctionality.";
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
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-crypto-test)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.bcc-sl-util-test)
          (hsPkgs.containers)
          (hsPkgs.cryptonite)
          (hsPkgs.generic-arbitrary)
          (hsPkgs.hedgehog)
          (hsPkgs.quickcheck-instances)
          (hsPkgs.random)
          (hsPkgs.serokell-util)
          (hsPkgs.text)
          (hsPkgs.time-units)
          (hsPkgs.universum)
          (hsPkgs.unordered-containers)
        ];
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-sl";
      rev = "632769d4480d3b19299d801c9fb39e75d20dd7d9";
      sha256 = "1l9i62fdgcl2spgaag70bxnm2rz996bl6g5nhmhj5m5fwn4sy2b9";
    };
    postUnpack = "sourceRoot+=/core/test; echo source root reset to \$sourceRoot";
  }
