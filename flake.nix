{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Zola 0.23 switched to Tera 2 and dropped macros and shortcodes; stay on 0.22.1 until the site migrates.
    nixpkgs-zola.url = "github:nixos/nixpkgs/9fbb54b33e91ee4ca368e35a78e0613c720600b3";

    nvfetcher.url = "github:berberman/nvfetcher";
    nvfetcher.inputs.nixpkgs.follows = "nixpkgs";
    nvfetcher.inputs.flake-utils.follows = "flake-utils";
    nvfetcher.inputs.flake-compat.follows = "flake-compat";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };
  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.treefmt-nix.flakeModule
      ];
      perSystem =
        {
          config,
          self',
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.nvfetcher.overlays.default
              (final: prev: { zola = inputs.nixpkgs-zola.legacyPackages.${system}.zola; })
            ];
          };
          legacyPackages = pkgs.callPackage ./nix { };
          packages = inputs.flake-utils.lib.flattenTree self'.legacyPackages;
          checks = self'.packages;
          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              prettier.enable = true;
            };
            settings.formatter.prettier.excludes = [ "*.html" ];
          };
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nvfetcher
              zola
            ];
          };
        };
    };
}
