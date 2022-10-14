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
        name = "bcc-sl-node";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2016 TBCO";
      maintainer = "Serokell <hi@serokell.io>";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL simple node executable";
      description = "Provides a 'bcc-node-simple' executable which can\nconnect to the Bcc network and act as a full node\nbut does not have any wallet capabilities.";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.base)
          (hsPkgs.aeson)
          (hsPkgs.async)
          (hsPkgs.bytestring)
          (hsPkgs.bcc-sl)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-db)
          (hsPkgs.bcc-sl-infra)
          (hsPkgs.bcc-sl-networking)
          (hsPkgs.bcc-sl-node-ipc)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.bcc-sl-x509)
          (hsPkgs.connection)
          (hsPkgs.data-default)
          (hsPkgs.http-client)
          (hsPkgs.http-client-tls)
          (hsPkgs.http-media)
          (hsPkgs.http-types)
          (hsPkgs.lens)
          (hsPkgs.serokell-util)
          (hsPkgs.servant-client)
          (hsPkgs.servant-server)
          (hsPkgs.servant-swagger)
          (hsPkgs.servant-swagger-ui)
          (hsPkgs.stm)
          (hsPkgs.swagger2)
          (hsPkgs.text)
          (hsPkgs.time-units)
          (hsPkgs.tls)
          (hsPkgs.universum)
          (hsPkgs.wai)
          (hsPkgs.warp)
          (hsPkgs.x509)
          (hsPkgs.x509-store)
        ];
      };
      exes = {
        "bcc-node-simple" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-sl-chain)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-util)
            (hsPkgs.bcc-sl-node)
            (hsPkgs.bcc-sl)
            (hsPkgs.universum)
          ];
          build-tools = [
            (hsPkgs.buildPackages.cpphs)
          ];
        };
      };
      tests = {
        "property-tests" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.HUnit)
            (hsPkgs.QuickCheck)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-utxo)
            (hsPkgs.containers)
            (hsPkgs.data-default)
            (hsPkgs.hashable)
            (hsPkgs.hspec)
            (hsPkgs.lens)
            (hsPkgs.mtl)
            (hsPkgs.text)
            (hsPkgs.universum)
            (hsPkgs.validation)
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
    postUnpack = "sourceRoot+=/node; echo source root reset to \$sourceRoot";
  }
