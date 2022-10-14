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
        name = "bcc-sl-utxo";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2017-2018 TBCO";
      maintainer = "operations@iohk.io";
      author = "TBCO Engineering Team";
      homepage = "https://github.com/the-blockchain-company/bcc-sl/#readme";
      url = "";
      synopsis = "Abstract definitions of UTxO based accounting";
      description = "";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.base)
          (hsPkgs.QuickCheck)
          (hsPkgs.bcc-sl)
          (hsPkgs.bcc-sl-binary)
          (hsPkgs.bcc-sl-chain)
          (hsPkgs.bcc-sl-chain-test)
          (hsPkgs.bcc-sl-client)
          (hsPkgs.bcc-sl-core)
          (hsPkgs.bcc-sl-core-test)
          (hsPkgs.bcc-sl-crypto)
          (hsPkgs.bcc-sl-db)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.constraints)
          (hsPkgs.containers)
          (hsPkgs.cryptonite)
          (hsPkgs.data-default)
          (hsPkgs.formatting)
          (hsPkgs.lens)
          (hsPkgs.mtl)
          (hsPkgs.reflection)
          (hsPkgs.safecopy)
          (hsPkgs.serokell-util)
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
    postUnpack = "sourceRoot+=/utxo; echo source root reset to \$sourceRoot";
  }
