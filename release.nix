############################################################################
# Hydra release jobset
#
# Example build for Linux:
#
#   nix-build release.nix -A exes.bcc-wallet-server.x86_64-linux
#
# Example build for Windows (cross-compiled from Linux):
#
#   nix-build release.nix -A cross.exes.bcc-wallet-server.x86_64-linux
#
############################################################################

let
  iohkLib = import ./nix/iohk-common.nix { application = "bcc-sl"; };
  fixedNixpkgs = iohkLib.pkgs;

in { supportedSystems ? [ "x86_64-linux" ]
  , scrubJobs ? true
  , bcc-wallet ? { outPath = ./.; rev = "abcdef"; }
  , nixpkgsArgs ? {
      config = (import ./nix/config.nix // { allowUnfree = false; inHydra = true; });
      gitrev = bcc-wallet.rev;
    }
  }:

with (import (fixedNixpkgs.path + "/pkgs/top-level/release-lib.nix") {
  inherit supportedSystems scrubJobs nixpkgsArgs;
  packageSet = import bcc-wallet.outPath;
});

let
  jobs = mapTestOn {
    exes.bcc-wallet-server = supportedSystems;
    tests.unit                 = supportedSystems;
  };

  crossJobs = mapTestOnCross lib.systems.examples.mingwW64 {
    exes.bcc-wallet-server = [ "x86_64-linux" ];
    tests.unit                 = [ "x86_64-linux" ];
  };

in
  jobs // { cross = crossJobs; }
