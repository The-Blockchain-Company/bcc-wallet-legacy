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
        name = "bcc-sl-cluster";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2018 TBCO";
      maintainer = "operations@iohk.io";
      author = "TBCO Engineering Team";
      homepage = "https://github.com/the-blockchain-company/bcc-sl/cluster/README.md";
      url = "";
      synopsis = "Utilities to generate and run cluster of nodes";
      description = "See README";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.base)
          (hsPkgs.bcc-sl)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-infra)
          (hsPkgs.bcc-sl-networking)
          (hsPkgs.bcc-sl-node)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.bcc-sl-x509)
          (hsPkgs.aeson)
          (hsPkgs.async)
          (hsPkgs.attoparsec)
          (hsPkgs.bytestring)
          (hsPkgs.containers)
          (hsPkgs.directory)
          (hsPkgs.filepath)
          (hsPkgs.formatting)
          (hsPkgs.iproute)
          (hsPkgs.lens)
          (hsPkgs.optparse-applicative)
          (hsPkgs.parsec)
          (hsPkgs.safe)
          (hsPkgs.servant-client)
          (hsPkgs.temporary)
          (hsPkgs.text)
          (hsPkgs.time)
          (hsPkgs.tls)
          (hsPkgs.universum)
        ];
      };
      exes = {
        "bcc-sl-cluster-demo" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-sl)
            (hsPkgs.bcc-sl-cluster)
            (hsPkgs.bcc-sl-node)
            (hsPkgs.ansi-terminal)
            (hsPkgs.async)
            (hsPkgs.containers)
            (hsPkgs.docopt)
            (hsPkgs.formatting)
            (hsPkgs.lens)
            (hsPkgs.universum)
          ];
        };
        "bcc-sl-cluster-prepare-environment" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-sl-cluster)
            (hsPkgs.containers)
            (hsPkgs.docopt)
            (hsPkgs.formatting)
            (hsPkgs.lens)
            (hsPkgs.universum)
          ];
        };
      };
      tests = {
        "bcc-sl-cluster-test" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-sl-cluster)
            (hsPkgs.bcc-sl-core)
            (hsPkgs.bcc-sl-infra)
            (hsPkgs.async)
            (hsPkgs.containers)
            (hsPkgs.lens)
            (hsPkgs.QuickCheck)
            (hsPkgs.time)
            (hsPkgs.universum)
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
    postUnpack = "sourceRoot+=/cluster; echo source root reset to \$sourceRoot";
  }
