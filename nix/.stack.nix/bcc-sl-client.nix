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
        name = "bcc-sl-client";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2017 TBCO";
      maintainer = "hi@serokell.io";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL client modules";
      description = "Bcc SL client modules";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.base)
          (hsPkgs.bcc-sl)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-db)
          (hsPkgs.bcc-sl-infra)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.containers)
          (hsPkgs.data-default)
          (hsPkgs.formatting)
          (hsPkgs.lens)
          (hsPkgs.mtl)
          (hsPkgs.safe-exceptions)
          (hsPkgs.serokell-util)
          (hsPkgs.stm)
          (hsPkgs.formatting)
          (hsPkgs.transformers)
          (hsPkgs.universum)
          (hsPkgs.unordered-containers)
          (hsPkgs.vector)
          (hsPkgs.QuickCheck)
        ];
        build-tools = [
          (hsPkgs.buildPackages.cpphs)
        ];
      };
      tests = {
        "bcc-client-test" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-chain-test)
            (hsPkgs.bcc-sl-client)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-crypto)
            (hsPkgs.bcc-sl-crypto-test)
            (hsPkgs.bcc-sl-db)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-sl-util-test)
            (hsPkgs.containers)
            (hsPkgs.formatting)
            (hsPkgs.hspec)
            (hsPkgs.QuickCheck)
            (hsPkgs.universum)
            (hsPkgs.unordered-containers)
          ];
          build-tools = [
            (hsPkgs.buildPackages.hspec-discover)
            (hsPkgs.buildPackages.cpphs)
          ];
        };
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-sl";
      rev = "632769d4480d3b19299d801c9fb39e75d20dd7d9";
      sha256 = "1l9i62fdgcl2spgaag70bxnm2rz996bl6g5nhmhj5m5fwn4sy2b9";
    };
    postUnpack = "sourceRoot+=/client; echo source root reset to \$sourceRoot";
  }
