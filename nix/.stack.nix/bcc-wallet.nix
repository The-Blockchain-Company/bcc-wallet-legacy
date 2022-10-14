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
        name = "bcc-wallet";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2018 TBCO";
      maintainer = "operations@iohk.io";
      author = "TBCO Engineering Team";
      homepage = "https://github.com/the-blockchain-company/bcc-wallet";
      url = "";
      synopsis = "The Wallet Backend for a Bcc node.";
      description = "Please see README.md";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.base)
          (hsPkgs.acid-state)
          (hsPkgs.aeson)
          (hsPkgs.aeson-options)
          (hsPkgs.aeson-pretty)
          (hsPkgs.async)
          (hsPkgs.base58-bytestring)
          (hsPkgs.beam-core)
          (hsPkgs.beam-migrate)
          (hsPkgs.beam-sqlite)
          (hsPkgs.bifunctors)
          (hsPkgs.binary)
          (hsPkgs.bytestring)
          (hsPkgs.bcc-crypto)
          (hsPkgs.bcc-sl)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-client)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-core-test)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-db)
          (hsPkgs.bcc-sl-infra)
          (hsPkgs.bcc-sl-mnemonic)
          (hsPkgs.bcc-sl-networking)
          (hsPkgs.bcc-sl-node)
          (hsPkgs.bcc-sl-node-ipc)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.bcc-sl-utxo)
          (hsPkgs.cereal)
          (hsPkgs.clock)
          (hsPkgs.conduit)
          (hsPkgs.containers)
          (hsPkgs.cryptonite)
          (hsPkgs.data-default)
          (hsPkgs.data-default-class)
          (hsPkgs.directory)
          (hsPkgs.exceptions)
          (hsPkgs.filepath)
          (hsPkgs.foldl)
          (hsPkgs.formatting)
          (hsPkgs.generics-sop)
          (hsPkgs.http-api-data)
          (hsPkgs.http-client)
          (hsPkgs.http-types)
          (hsPkgs.ixset-typed)
          (hsPkgs.lens)
          (hsPkgs.memory)
          (hsPkgs.mtl)
          (hsPkgs.mwc-random)
          (hsPkgs.neat-interpolation)
          (hsPkgs.optparse-applicative)
          (hsPkgs.QuickCheck)
          (hsPkgs.reflection)
          (hsPkgs.resourcet)
          (hsPkgs.retry)
          (hsPkgs.safecopy)
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
          (hsPkgs.sqlite-simple)
          (hsPkgs.sqlite-simple-errors)
          (hsPkgs.stm)
          (hsPkgs.stm-chans)
          (hsPkgs.strict)
          (hsPkgs.strict-concurrency)
          (hsPkgs.swagger2)
          (hsPkgs.tar)
          (hsPkgs.text)
          (hsPkgs.time)
          (hsPkgs.time-units)
          (hsPkgs.transformers)
          (hsPkgs.universum)
          (hsPkgs.unliftio-core)
          (hsPkgs.unordered-containers)
          (hsPkgs.uuid)
          (hsPkgs.vector)
          (hsPkgs.wai)
          (hsPkgs.wai-middleware-throttle)
          (hsPkgs.warp)
          (hsPkgs.zlib)
        ];
      };
      exes = {
        "bcc-wallet-server" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-wallet)
            (hsPkgs.universum)
          ];
        };
        "bcc-wallet-generate-swagger" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.aeson)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-wallet)
            (hsPkgs.optparse-applicative)
            (hsPkgs.swagger2)
            (hsPkgs.universum)
          ];
        };
      };
      tests = {
        "unit" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.acid-state)
            (hsPkgs.aeson)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-crypto)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-binary)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-chain-test)
            (hsPkgs.bcc-sl-client)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-core-test)
            (hsPkgs.bcc-sl-crypto)
            (hsPkgs.bcc-sl-db)
            (hsPkgs.bcc-sl-infra)
            (hsPkgs.bcc-sl-mnemonic)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-sl-util-test)
            (hsPkgs.bcc-sl-utxo)
            (hsPkgs.bcc-wallet)
            (hsPkgs.cereal)
            (hsPkgs.conduit)
            (hsPkgs.containers)
            (hsPkgs.cryptonite)
            (hsPkgs.data-default)
            (hsPkgs.directory)
            (hsPkgs.formatting)
            (hsPkgs.hedgehog)
            (hsPkgs.hspec)
            (hsPkgs.hspec-core)
            (hsPkgs.insert-ordered-containers)
            (hsPkgs.lens)
            (hsPkgs.mtl)
            (hsPkgs.normaldistribution)
            (hsPkgs.QuickCheck)
            (hsPkgs.quickcheck-instances)
            (hsPkgs.random)
            (hsPkgs.safe-exceptions)
            (hsPkgs.safecopy)
            (hsPkgs.serokell-util)
            (hsPkgs.servant)
            (hsPkgs.servant-server)
            (hsPkgs.servant-swagger)
            (hsPkgs.string-conv)
            (hsPkgs.swagger2)
            (hsPkgs.tabl)
            (hsPkgs.text)
            (hsPkgs.time)
            (hsPkgs.time-units)
            (hsPkgs.universum)
            (hsPkgs.unordered-containers)
            (hsPkgs.vector)
          ];
        };
        "nightly" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.async)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-wallet)
            (hsPkgs.formatting)
            (hsPkgs.hspec)
            (hsPkgs.hspec-core)
            (hsPkgs.QuickCheck)
            (hsPkgs.safe-exceptions)
            (hsPkgs.serokell-util)
            (hsPkgs.text)
            (hsPkgs.universum)
          ];
        };
        "integration" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.QuickCheck)
            (hsPkgs.servant-client)
            (hsPkgs.aeson)
            (hsPkgs.aeson-qq)
            (hsPkgs.async)
            (hsPkgs.bytestring)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-client)
            (hsPkgs.bcc-sl-cluster)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-crypto)
            (hsPkgs.bcc-sl-mnemonic)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-wallet)
            (hsPkgs.containers)
            (hsPkgs.cryptonite)
            (hsPkgs.directory)
            (hsPkgs.data-default)
            (hsPkgs.filepath)
            (hsPkgs.formatting)
            (hsPkgs.generic-lens)
            (hsPkgs.hspec)
            (hsPkgs.hspec-core)
            (hsPkgs.hspec-expectations-lifted)
            (hsPkgs.http-api-data)
            (hsPkgs.http-client)
            (hsPkgs.http-types)
            (hsPkgs.memory)
            (hsPkgs.optparse-applicative)
            (hsPkgs.servant-client-core)
            (hsPkgs.template-haskell)
            (hsPkgs.text)
            (hsPkgs.universum)
          ];
        };
      };
    };
  } // rec { src = .././../.; }
