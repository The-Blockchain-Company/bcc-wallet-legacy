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
        name = "bcc-sl-db";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2016 TBCO";
      maintainer = "hi@serokell.io";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL - basic DB interfaces";
      description = "Bcc SL - basic DB interfaces";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.aeson)
          (hsPkgs.base)
          (hsPkgs.binary)
          (hsPkgs.bytestring)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.concurrent-extra)
          (hsPkgs.conduit)
          (hsPkgs.containers)
          (hsPkgs.cryptonite)
          (hsPkgs.data-default)
          (hsPkgs.directory)
          (hsPkgs.ekg-core)
          (hsPkgs.ether)
          (hsPkgs.exceptions)
          (hsPkgs.extra)
          (hsPkgs.filepath)
          (hsPkgs.formatting)
          (hsPkgs.lens)
          (hsPkgs.lrucache)
          (hsPkgs.memory)
          (hsPkgs.mmorph)
          (hsPkgs.mtl)
          (hsPkgs.resourcet)
          (hsPkgs.rocksdb-haskell-ng)
          (hsPkgs.safe-exceptions)
          (hsPkgs.serokell-util)
          (hsPkgs.stm)
          (hsPkgs.tagged)
          (hsPkgs.text)
          (hsPkgs.time-units)
          (hsPkgs.transformers)
          (hsPkgs.universum)
          (hsPkgs.unliftio)
          (hsPkgs.unordered-containers)
        ];
        build-tools = [
          (hsPkgs.buildPackages.cpphs)
        ];
      };
      tests = {
        "db-test" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-crypto)
            (hsPkgs.bcc-sl-crypto)
            (hsPkgs.bcc-sl-binary)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-chain-test)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-core-test)
            (hsPkgs.bcc-sl-db)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-sl-util-test)
            (hsPkgs.data-default)
            (hsPkgs.filepath)
            (hsPkgs.hedgehog)
            (hsPkgs.mtl)
            (hsPkgs.lens)
            (hsPkgs.temporary)
            (hsPkgs.universum)
            (hsPkgs.unordered-containers)
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
    postUnpack = "sourceRoot+=/db; echo source root reset to \$sourceRoot";
  }
