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
        name = "bcc-sl-util-test";
        version = "2.0.0";
      };
      license = "MIT";
      copyright = "2016 TBCO";
      maintainer = "hi@serokell.io";
      author = "Serokell";
      homepage = "";
      url = "";
      synopsis = "Bcc SL - general utilities (tests)";
      description = "QuickCheck Arbitrary instances for the Bcc SL general\nutilities package.";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.QuickCheck)
          (hsPkgs.aeson)
          (hsPkgs.aeson-pretty)
          (hsPkgs.attoparsec)
          (hsPkgs.base)
          (hsPkgs.base16-bytestring)
          (hsPkgs.bytestring)
          (hsPkgs.canonical-json)
          (hsPkgs.bcc-sl-util)
          (hsPkgs.cereal)
          (hsPkgs.cryptonite)
          (hsPkgs.directory)
          (hsPkgs.file-embed)
          (hsPkgs.filepath)
          (hsPkgs.formatting)
          (hsPkgs.hedgehog)
          (hsPkgs.hspec)
          (hsPkgs.mtl)
          (hsPkgs.pretty-show)
          (hsPkgs.quickcheck-instances)
          (hsPkgs.safecopy)
          (hsPkgs.template-haskell)
          (hsPkgs.text)
          (hsPkgs.time-units)
          (hsPkgs.universum)
          (hsPkgs.unordered-containers)
          (hsPkgs.yaml)
        ];
        build-tools = [
          (hsPkgs.buildPackages.cpphs)
        ];
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-sl";
      rev = "632769d4480d3b19299d801c9fb39e75d20dd7d9";
      sha256 = "1l9i62fdgcl2spgaag70bxnm2rz996bl6g5nhmhj5m5fwn4sy2b9";
    };
    postUnpack = "sourceRoot+=/util/test; echo source root reset to \$sourceRoot";
  }
