{ system
, compiler
, flags
, pkgs
, hsPkgs
, pkgconfPkgs
, ... }:
  {
    flags = { asserts = true; };
    package = {
      specVersion = "1.10";
      identifier = {
        name = "bcc-sl-core";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2016 TBCO";
      maintainer = "hi@serokell.io";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL - core";
      description = "Bcc SL - core";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.aeson)
          (hsPkgs.aeson-options)
          (hsPkgs.ansi-terminal)
          (hsPkgs.base)
          (hsPkgs.base58-bytestring)
          (hsPkgs.bytestring)
          (hsPkgs.canonical-json)
          (hsPkgs.bcc-report-server)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.cborg)
          (hsPkgs.cereal)
          (hsPkgs.containers)
          (hsPkgs.cryptonite)
          (hsPkgs.data-default)
          (hsPkgs.deepseq)
          (hsPkgs.deriving-compat)
          (hsPkgs.ekg-core)
          (hsPkgs.ether)
          (hsPkgs.exceptions)
          (hsPkgs.formatting)
          (hsPkgs.hashable)
          (hsPkgs.http-api-data)
          (hsPkgs.lens)
          (hsPkgs.parsec)
          (hsPkgs.memory)
          (hsPkgs.mmorph)
          (hsPkgs.monad-control)
          (hsPkgs.mtl)
          (hsPkgs.random)
          (hsPkgs.reflection)
          (hsPkgs.resourcet)
          (hsPkgs.safecopy)
          (hsPkgs.safe-exceptions)
          (hsPkgs.safecopy)
          (hsPkgs.serokell-util)
          (hsPkgs.servant)
          (hsPkgs.stm)
          (hsPkgs.template-haskell)
          (hsPkgs.text)
          (hsPkgs.time)
          (hsPkgs.time-units)
          (hsPkgs.transformers)
          (hsPkgs.transformers-base)
          (hsPkgs.transformers-lift)
          (hsPkgs.universum)
          (hsPkgs.unliftio)
          (hsPkgs.unliftio-core)
          (hsPkgs.unordered-containers)
        ];
        build-tools = [
          (hsPkgs.buildPackages.cpphs)
        ];
      };
      tests = {
        "core-test" = {
          depends = [
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
            (hsPkgs.formatting)
            (hsPkgs.generic-arbitrary)
            (hsPkgs.hedgehog)
            (hsPkgs.hspec)
            (hsPkgs.QuickCheck)
            (hsPkgs.quickcheck-instances)
            (hsPkgs.random)
            (hsPkgs.serokell-util)
            (hsPkgs.text)
            (hsPkgs.time-units)
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
    postUnpack = "sourceRoot+=/core; echo source root reset to \$sourceRoot";
  }
