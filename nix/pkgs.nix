{ args ? { config = import ./config.nix; }
, pkgs ? import <nixpkgs> { inherit args; }
, src ? ../.
}:
let
  overrideWith = override: default:
   let
     try = builtins.tryEval (builtins.findFile builtins.nixPath override);
   in if try.success then
     builtins.trace "using search host <${override}>" try.value
   else
     default;

in
let
  # save the nixpkgs value in pkgs'
  # so we can work with `pkgs` provided by modules.
  pkgs' = pkgs;

  # all packages from hackage as nix expressions
  hackage = import (overrideWith "hackage"
                    (pkgs.fetchFromGitHub { owner  = "angerman";
                                                repo   = "hackage.nix";
                                                rev    = "72e5c66b9db4fdf49621c0bf6e2fce0781e98787";
                                                sha256 = "1wbml33yimdjx7ig8abqwgvzbyksvvb233p8z2q1dzja7xbgz033";
                                                name   = "hackage-exprs-source"; }))
                   ;
  # a different haskell infrastructure
  haskell = import (overrideWith "haskell"
                    (pkgs.fetchFromGitHub { owner  = "angerman";
                                                repo   = "haskell.nix";
                                                rev    = "03026b7bb95a6713f4d50b841abadabb343f83d2";
                                                sha256 = "05ma2qmmn4p2xcgyy8waissfj953b7wyq97yx80d936074gyyw4s";
                                                name   = "haskell-lib-source"; }))
                   hackage;

  # the set of all stackage snapshots
  stackage = import (overrideWith "stackage"
                     (pkgs.fetchFromGitHub { owner  = "angerman";
                                                 repo   = "stackage.nix";
                                                 rev    = "67675ea78ae5c321ed0b8327040addecc743a96c";
                                                 sha256 = "1ds2xfsnkm2byg8js6c9032nvfwmbx7lgcsndjgkhgq56bmw5wap";
                                                 name   = "stackage-snapshot-source"; }))
                   ;

  # our packages
  stack-pkgs = import ./.stack-pkgs.nix;

  # Build the packageset with module support.
  # We can essentially override anything in the modules
  # section.
  #
  #  packages.cbors.patches = [ ./one.patch ];
  #  packages.cbors.flags.optimize-gmp = false;
  #
  pkgSet = haskell.mkNewPkgSet {
    inherit pkgs;
    pkg-def = stackage.${stack-pkgs.resolver};
    pkg-def-overlays = [
      stack-pkgs.overlay
      (import ./ghc-custom/default.nix)
      (hackage: {
          hsc2hs = hackage.hsc2hs."0.68.4".revisions.default;
          # stackage 12.17 beautifully omits the Win32 pkg
          Win32 = hackage.Win32."2.6.2.0".revisions.default;
      })
    ];
    modules = [
      {
         # This needs true, otherwise we miss most of the interesting
         # modules.
         packages.ghci.flags.ghci = true;
         # this needs to be true to expose module
         #  Message.Remote
         # as needed by libiserv.
         packages.libiserv.flags.network = true;

         # enable golden tests on bcc-crypto
         packages.bcc-crypto.flags.golden-tests = true;
      }

      ({ config, ... }: {
          packages.hsc2hs.components.exes.hsc2hs.doExactConfig = true;
          packages.Win32.components.library.build-tools = [ config.hsPkgs.buildPackages.hsc2hs ];
          packages.remote-iserv.postInstall = ''
            cp ${pkgs.windows.mingw_w64_pthreads}/bin/libwinpthread-1.dll $out/bin/
          '';
      })

      {
        packages.conduit.patches            = [ ./patches/conduit-1.3.0.2.patch ];
        packages.cryptonite-openssl.patches = [ ./patches/cryptonite-openssl-0.7.patch ];
        packages.streaming-commons.patches  = [ ./patches/streaming-commons-0.2.0.0.patch ];
        packages.x509-system.patches        = [ ./patches/x509-system-1.6.6.patch ];
        packages.file-embed-lzma.patches    = [ ./patches/file-embed-lzma-0.patch ];
        packages.bcc-sl.patches         = [ ./patches/bcc-sl.patch ];
      }

      # cross compilation logic
      ({ pkgs, config, lib, ... }:
      let
        withTH = import ./mingw_w64.nix {
          inherit (pkgs') stdenv lib writeScriptBin;
          wine = pkgs.buildPackages.winePackages.minimal;
          inherit (pkgs.windows) mingw_w64_pthreads;
          inherit (pkgs) gmp;
          # iserv-proxy needs to come from the buildPackages, as it needs to run on the
          # build host.
          inherit (config.hsPkgs.buildPackages.iserv-proxy.components.exes) iserv-proxy;
          # remote-iserv however needs to come from the regular packages as it has to
          # run on the target host.
          inherit (packages.remote-iserv.components.exes) remote-iserv;
          # we need to use openssl.bin here, because the .dll's are in the .bin expression.
          extra-test-libs = [ pkgs.rocksdb pkgs.openssl.bin ];
        } // { doCrossCheck = true; };
       in lib.optionalAttrs pkgs'.stdenv.hostPlatform.isWindows  {
         packages.bcc-wallet           = withTH;
         packages.generics-sop             = withTH;
         packages.ether                    = withTH;
         packages.th-lift-instances        = withTH;
         packages.aeson                    = withTH;
         packages.hedgehog                 = withTH;
         packages.th-orphans               = withTH;
         packages.uri-bytestring           = withTH;
         packages.these                    = withTH;
         packages.katip                    = withTH;
         packages.swagger2                 = withTH;
         packages.wreq                     = withTH;
         packages.wai-app-static           = withTH;
         packages.log-warper               = withTH;
         packages.bcc-sl-util          = withTH;
         packages.bcc-sl-crypto        = withTH;
         packages.bcc-sl-crypto-test   = withTH;
         packages.bcc-sl-core          = withTH;
         packages.bcc-sl               = withTH;
         packages.bcc-sl-chain         = withTH;
         packages.bcc-sl-db            = withTH;
         packages.bcc-sl-networking    = withTH;
         packages.bcc-sl-infra         = withTH;
         packages.bcc-sl-infra-test    = withTH;
         packages.bcc-sl-client        = withTH;
         packages.bcc-sl-core-test     = withTH;
         packages.bcc-sl-chain-test    = withTH;
         packages.bcc-sl-utxo          = withTH;
         packages.bcc-sl-tools         = withTH;
         packages.bcc-sl-generator     = withTH;
         packages.bcc-sl-auxx          = withTH;
         packages.bcc-sl-faucet        = withTH;
         packages.bcc-sl-binary        = withTH;
         packages.bcc-sl-node          = withTH;
         packages.bcc-sl-explorer      = withTH;
         packages.bcc-sl-cluster       = withTH;
         packages.bcc-sl-x509          = withTH;
         packages.bcc-sl-mnemonic      = withTH;
         packages.bcc-crypto           = withTH;
         packages.math-functions           = withTH;
         packages.servant-swagger-ui       = withTH;
         packages.servant-swagger-ui-redoc = withTH;
         packages.trifecta                 = withTH;
         packages.Chart                    = withTH;
         packages.active                   = withTH;
         packages.diagrams                 = withTH;
         packages.diagrams-lib             = withTH;
         packages.diagrams-svg             = withTH;
         packages.diagrams-postscript      = withTH;
         packages.Chart-diagrams           = withTH;
      })

      # Packages we wish to ignore version bounds of.
      # This is similar to jailbreakCabal, however it
      # does not require any messing with cabal files.
      {
         packages.katip.components.library.doExactConfig         = true;
         packages.serokell-util.components.library.doExactConfig = true;
         # turtle wants Win32 < 2.6
         packages.turtle.components.library.doExactConfig        = true;
      }
      ({ pkgs, ... }: {
         packages.hfsevents.components.library.frameworks  = [ pkgs.CoreServices ];
      })

      {
        packages.bcc-wallet.src = pkgs.lib.mkForce src;
      }
    ];
  };

  packages = pkgSet.config.hsPkgs // { _config = pkgSet.config; };

in packages
