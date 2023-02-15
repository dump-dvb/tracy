{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    utils = {
      url = "github:numtide/flake-utils";
    };
  };

  outputs = { self, nixpkgs, naersk, utils, ... }:
    utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          package = pkgs.callPackage ./derivation.nix {
            naersk = naersk.lib.${system};
          };

        in
        rec {
          checks = packages;
          packages = {
            trekkie = package;
            default = package;
          };
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = (with packages.default; nativeBuildInputs ++ buildInputs);
          };
        }
      ) // {
      overlays.default = final: prev: {
        inherit (self.packages.${prev.system})
          trekkie;
      };

      nixosModules = rec {
        default = trekkie;
        trekkie = import ./nixos-module;
      };

      hydraJobs =
        let
          hydraSystems = [
            "x86_64-linux"
            "aarch64-linux"
          ];
        in
        builtins.foldl'
          (hydraJobs: system:
            builtins.foldl'
              (hydraJobs: pkgName:
                nixpkgs.lib.recursiveUpdate hydraJobs {
                  ${pkgName}.${system} = self.packages.${system}.${pkgName};
                }
              )
              hydraJobs
              (builtins.attrNames self.packages.${system})
          )
          { }
          hydraSystems;
    };
}
