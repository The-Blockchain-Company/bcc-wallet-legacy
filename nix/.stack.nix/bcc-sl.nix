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
        name = "bcc-sl";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2016 TBCO";
      maintainer = "Serokell <hi@serokell.io>";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL main implementation";
      description = "Please see README.md";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = ([
          (hsPkgs.base)
          (hsPkgs.base64-bytestring)
          (hsPkgs.aeson)
          (hsPkgs.aeson-options)
          (hsPkgs.ansi-terminal)
          (hsPkgs.ansi-wl-pprint)
          (hsPkgs.async)
          (hsPkgs.bytestring)
          (hsPkgs.canonical-json)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-binary-test)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-chain-test)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-core-test)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-crypto-test)
          (hsPkgs.bcc-sl-db)
          (hsPkgs.bcc-sl-infra)
          (hsPkgs.bcc-sl-networking)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.conduit)
          (hsPkgs.constraints)
          (hsPkgs.containers)
          (hsPkgs.contravariant)
          (hsPkgs.cryptonite)
          (hsPkgs.data-default)
          (hsPkgs.directory)
          (hsPkgs.ekg-core)
          (hsPkgs.ekg)
          (hsPkgs.ether)
          (hsPkgs.exceptions)
          (hsPkgs.filelock)
          (hsPkgs.filepath)
          (hsPkgs.formatting)
          (hsPkgs.formatting)
          (hsPkgs.generics-sop)
          (hsPkgs.hspec)
          (hsPkgs.http-api-data)
          (hsPkgs.http-client)
          (hsPkgs.http-client-tls)
          (hsPkgs.http-conduit)
          (hsPkgs.http-types)
          (hsPkgs.lens)
          (hsPkgs.lifted-async)
          (hsPkgs.memory)
          (hsPkgs.monad-control)
          (hsPkgs.mtl)
          (hsPkgs.neat-interpolation)
          (hsPkgs.network)
          (hsPkgs.network-transport)
          (hsPkgs.optparse-applicative)
          (hsPkgs.parsec)
          (hsPkgs.pvss)
          (hsPkgs.QuickCheck)
          (hsPkgs.quickcheck-instances)
          (hsPkgs.random)
          (hsPkgs.reflection)
          (hsPkgs.safe-exceptions)
          (hsPkgs.serokell-util)
          (hsPkgs.servant)
          (hsPkgs.servant-client)
          (hsPkgs.servant-client-core)
          (hsPkgs.servant-server)
          (hsPkgs.servant-swagger)
          (hsPkgs.servant-swagger-ui)
          (hsPkgs.servant-swagger-ui-core)
          (hsPkgs.servant-swagger-ui-redoc)
          (hsPkgs.stm)
          (hsPkgs.streaming-commons)
          (hsPkgs.swagger2)
          (hsPkgs.tagged)
          (hsPkgs.template-haskell)
          (hsPkgs.text)
          (hsPkgs.time)
          (hsPkgs.time-units)
          (hsPkgs.tls)
          (hsPkgs.transformers)
          (hsPkgs.universum)
          (hsPkgs.unliftio)
          (hsPkgs.unordered-containers)
          (hsPkgs.wai)
          (hsPkgs.warp)
          (hsPkgs.warp-tls)
          (hsPkgs.x509)
          (hsPkgs.x509-store)
          (hsPkgs.x509-validation)
          (hsPkgs.yaml)
          (hsPkgs.cborg)
        ] ++ pkgs.lib.optional (!system.isWindows) (hsPkgs.unix)) ++ pkgs.lib.optional (!system.isWindows && !system.isFreebsd) (hsPkgs.systemd);
        build-tools = [
          (hsPkgs.buildPackages.cpphs)
        ];
      };
      tests = {
        "bcc-test" = {
          depends = [
            (hsPkgs.QuickCheck)
            (hsPkgs.base)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-crypto)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-binary)
            (hsPkgs.bcc-sl-binary-test)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-chain-test)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-core-test)
            (hsPkgs.bcc-sl-crypto)
            (hsPkgs.bcc-sl-crypto-test)
            (hsPkgs.bcc-sl-db)
            (hsPkgs.bcc-sl-db-test)
            (hsPkgs.bcc-sl-infra)
            (hsPkgs.bcc-sl-infra-test)
            (hsPkgs.bcc-sl-networking)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-sl-util-test)
            (hsPkgs.conduit)
            (hsPkgs.containers)
            (hsPkgs.cryptonite)
            (hsPkgs.data-default)
            (hsPkgs.deepseq)
            (hsPkgs.extra)
            (hsPkgs.filelock)
            (hsPkgs.formatting)
            (hsPkgs.generic-arbitrary)
            (hsPkgs.hedgehog)
            (hsPkgs.hspec)
            (hsPkgs.lens)
            (hsPkgs.network-transport)
            (hsPkgs.network-transport-inmemory)
            (hsPkgs.pvss)
            (hsPkgs.random)
            (hsPkgs.reflection)
            (hsPkgs.serokell-util)
            (hsPkgs.tagged)
            (hsPkgs.text)
            (hsPkgs.time)
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
      benchmarks = {
        "bcc-bench-criterion" = {
          depends = [
            (hsPkgs.QuickCheck)
            (hsPkgs.base)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-chain-test)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-core-test)
            (hsPkgs.bcc-sl-crypto)
            (hsPkgs.bcc-sl-crypto-test)
            (hsPkgs.bcc-sl-db)
            (hsPkgs.bcc-sl-infra)
            (hsPkgs.bcc-sl-networking)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-sl-util-test)
            (hsPkgs.conduit)
            (hsPkgs.criterion)
            (hsPkgs.deepseq)
            (hsPkgs.formatting)
            (hsPkgs.network-transport)
            (hsPkgs.network-transport-inmemory)
            (hsPkgs.optparse-applicative)
            (hsPkgs.universum)
          ];
          build-tools = [
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
    postUnpack = "sourceRoot+=/lib; echo source root reset to \$sourceRoot";
  }
