{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";
  };
  outputs = { self, flake-utils-plus, ... }@inputs:
    let utils = flake-utils-plus.lib;
    in utils.mkFlake {
      inherit self inputs;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      outputsBuilder = channels:
        let
          pkgs = channels.nixpkgs;
          inherit (pkgs.stdenv.hostPlatform) system;
          packages = pkgs.callPackage ./nix { };
        in
        {
          packages = utils.flattenTree packages;
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nvfetcher
              nix-prefetch
            ];
          };
          checks = self.packages.${system};
        };
    };
}
