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
        name = "bcc-report-server";
        version = "0.5.10";
      };
      license = "BSD-3-Clause";
      copyright = "2017-2018 TBCO";
      maintainer = "volhovm.cs@gmail.com";
      author = "Volkhov Mikhail";
      homepage = "https://github.com/the-blockchain-company/bcc-report-server";
      url = "";
      synopsis = "Reporting server for CSL";
      description = "Please see README.md";
      buildType = "Simple";
    };
    components = {
      "library" = {
        depends = [
          (hsPkgs.aeson)
          (hsPkgs.aeson-pretty)
          (hsPkgs.base)
          (hsPkgs.bytestring)
          (hsPkgs.case-insensitive)
          (hsPkgs.directory)
          (hsPkgs.exceptions)
          (hsPkgs.filelock)
          (hsPkgs.filepath)
          (hsPkgs.formatting)
          (hsPkgs.http-types)
          (hsPkgs.lens)
          (hsPkgs.lifted-base)
          (hsPkgs.log-warper)
          (hsPkgs.monad-control)
          (hsPkgs.mtl)
          (hsPkgs.network)
          (hsPkgs.optparse-applicative)
          (hsPkgs.parsec)
          (hsPkgs.random)
          (hsPkgs.text)
          (hsPkgs.time)
          (hsPkgs.transformers)
          (hsPkgs.universum)
          (hsPkgs.vector)
          (hsPkgs.wai)
          (hsPkgs.wai-extra)
          (hsPkgs.warp)
          (hsPkgs.wreq)
          (hsPkgs.lens-aeson)
        ];
      };
      exes = {
        "bcc-report-server" = {
          depends = [
            (hsPkgs.base)
            (hsPkgs.bcc-report-server)
            (hsPkgs.directory)
            (hsPkgs.filepath)
            (hsPkgs.http-types)
            (hsPkgs.log-warper)
            (hsPkgs.monad-control)
            (hsPkgs.mtl)
            (hsPkgs.optparse-applicative)
            (hsPkgs.parsec)
            (hsPkgs.random)
            (hsPkgs.universum)
            (hsPkgs.wai-extra)
            (hsPkgs.warp)
          ];
        };
      };
      tests = {
        "bcc-report-server-test" = {
          depends = [
            (hsPkgs.HUnit)
            (hsPkgs.QuickCheck)
            (hsPkgs.aeson)
            (hsPkgs.base)
            (hsPkgs.bcc-report-server)
            (hsPkgs.hspec)
            (hsPkgs.lens)
            (hsPkgs.quickcheck-text)
            (hsPkgs.text)
            (hsPkgs.time)
            (hsPkgs.transformers)
            (hsPkgs.universum)
          ];
          build-tools = [
            (hsPkgs.buildPackages.hspec-discover)
          ];
        };
      };
    };
  } // {
    src = pkgs.fetchgit {
      url = "https://github.com/the-blockchain-company/bcc-report-server.git";
      rev = "93f2246c54436e7f98cc363b4e0f8f1cb5e78717";
      sha256 = "04zsgrmnlyjymry6fsqnz692hdp89ykqb8jyxib8yklw101gdn3x";
    };
  }
