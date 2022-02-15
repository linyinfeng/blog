{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";
  };
  outputs =
    { self, nixpkgs, flake-utils-plus } @ inputs:
    let utils = flake-utils-plus.lib;
    in
    utils.mkFlake {
      inherit self inputs;

      outputsBuilder = channels:
        let
          pkgs = channels.nixpkgs;
          packages = pkgs.callPackage ./nix { };
        in
        {
          packages = utils.flattenTree packages;
        };
    };
}
