{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";
    nvfetcher.url = "github:berberman/nvfetcher";
    nvfetcher.inputs.nixpkgs.follows = "nixpkgs";
    nvfetcher.inputs.flake-utils.follows = "flake-utils-plus/flake-utils";
  };
  outputs = { self, flake-utils-plus, ... }@inputs:
    let utils = flake-utils-plus.lib;
    in utils.mkFlake {
      inherit self inputs;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      channels.nixpkgs.overlaysBuilder = channels: [
        inputs.nvfetcher.overlays.default
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
            ];
          };
          checks = self.packages.${system};
        };
    };
}
