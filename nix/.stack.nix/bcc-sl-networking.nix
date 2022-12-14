{ system
, compiler
, flags
, pkgs
, hsPkgs
, pkgconfPkgs
, ... }:
  {
    flags = { benchmarks = false; };
    package = {
      specVersion = "1.20";
      identifier = {
        name = "bcc-sl-networking";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "";
      maintainer = "";
      author = "";
      homepage = "";
      url = "";
      synopsis = "";
      description = "";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.aeson)
          (hsPkgs.aeson-options)
          (hsPkgs.async)
          (hsPkgs.attoparsec)
          (hsPkgs.base)
          (hsPkgs.binary)
          (hsPkgs.bytestring)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.containers)
          (hsPkgs.ekg-core)
          (hsPkgs.formatting)
          (hsPkgs.formatting)
          (hsPkgs.hashable)
          (hsPkgs.lens)
          (hsPkgs.mtl)
          (hsPkgs.mtl)
          (hsPkgs.network)
          (hsPkgs.network-transport)
          (hsPkgs.network-transport-tcp)
          (hsPkgs.random)
          (hsPkgs.safe-exceptions)
          (hsPkgs.scientific)
          (hsPkgs.stm)
          (hsPkgs.text)
          (hsPkgs.these)
          (hsPkgs.time)
          (hsPkgs.time-units)
          (hsPkgs.universum)
          (hsPkgs.unordered-containers)
        ];
      };
      exes = {
        "ping-pong" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.async)
            (hsPkgs.binary)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-sl-networking)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.contravariant)
            (hsPkgs.network-transport)
            (hsPkgs.network-transport-tcp)
            (hsPkgs.random)
          ];
        };
        "bench-sender" = {
          depends = [
            (hsPkgs.async)
            (hsPkgs.base)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.contravariant)
            (hsPkgs.lens)
            (hsPkgs.MonadRandom)
            (hsPkgs.mtl)
            (hsPkgs.network-transport)
            (hsPkgs.network-transport-tcp)
            (hsPkgs.optparse-simple)
            (hsPkgs.random)
            (hsPkgs.safe-exceptions)
            (hsPkgs.serokell-util)
            (hsPkgs.time)
            (hsPkgs.time-units)
          ];
        };
        "bench-receiver" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.contravariant)
            (hsPkgs.network-transport-tcp)
            (hsPkgs.optparse-simple)
            (hsPkgs.random)
            (hsPkgs.safe-exceptions)
            (hsPkgs.serokell-util)
            (hsPkgs.text)
          ];
        };
        "bench-log-reader" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.attoparsec)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.conduit)
            (hsPkgs.conduit-extra)
            (hsPkgs.containers)
            (hsPkgs.lens)
            (hsPkgs.mtl)
            (hsPkgs.optparse-simple)
            (hsPkgs.resourcet)
            (hsPkgs.safe-exceptions)
            (hsPkgs.text)
            (hsPkgs.formatting)
            (hsPkgs.unliftio-core)
          ];
        };
      };
      tests = {
        "bcc-sl-networking-test" = {
          depends = [
            (hsPkgs.async)
            (hsPkgs.base)
            (hsPkgs.binary)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-sl-networking)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.containers)
            (hsPkgs.hspec)
            (hsPkgs.hspec-core)
            (hsPkgs.lens)
            (hsPkgs.mtl)
            (hsPkgs.network-transport)
            (hsPkgs.network-transport-tcp)
            (hsPkgs.network-transport-inmemory)
            (hsPkgs.QuickCheck)
            (hsPkgs.random)
            (hsPkgs.serokell-util)
            (hsPkgs.stm)
            (hsPkgs.time-units)
          ];
          build-tools = [
            (hsPkgs.buildPackages.hspec-discover)
          ];
        };
      };
      benchmarks = {
        "qdisc-simulation" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.async)
            (hsPkgs.network-transport-tcp)
            (hsPkgs.network-transport)
            (hsPkgs.time-units)
            (hsPkgs.stm)
            (hsPkgs.mwc-random)
            (hsPkgs.statistics)
            (hsPkgs.vector)
            (hsPkgs.time)
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
    postUnpack = "sourceRoot+=/networking; echo source root reset to \$sourceRoot";
  }
