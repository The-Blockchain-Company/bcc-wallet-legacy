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
        name = "bcc-sl-chain-test";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2018 TBCO";
      maintainer = "rupert.horlick@iohk.io";
      author = "Rupert Horlick";
      homepage = "";
      url = "";
      synopsis = "Bcc SL - arbitrary instances for bcc-sl-chain";
      description = "Bcc SL - arbitrary instances for bcc-sl-chain";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.aeson)
          (hsPkgs.base)
          (hsPkgs.base16-bytestring)
          (hsPkgs.bytestring)
          (hsPkgs.bcc-crypto)
          (hsPkgs.bcc-sl-binary-test)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-core-test)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-crypto-test)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.bcc-sl-util-test)
          (hsPkgs.containers)
          (hsPkgs.cryptonite)
          (hsPkgs.data-default)
          (hsPkgs.formatting)
          (hsPkgs.generic-arbitrary)
          (hsPkgs.hedgehog)
          (hsPkgs.pvss)
          (hsPkgs.QuickCheck)
          (hsPkgs.random)
          (hsPkgs.reflection)
          (hsPkgs.serokell-util)
          (hsPkgs.time-units)
          (hsPkgs.universum)
          (hsPkgs.unordered-containers)
          (hsPkgs.vector)
        ];
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-sl";
      rev = "632769d4480d3b19299d801c9fb39e75d20dd7d9";
      sha256 = "1l9i62fdgcl2spgaag70bxnm2rz996bl6g5nhmhj5m5fwn4sy2b9";
    };
    postUnpack = "sourceRoot+=/chain/test; echo source root reset to \$sourceRoot";
  }
