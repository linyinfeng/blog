{ pkgs }:

let
  inherit (pkgs) lib newScope;
in

lib.makeScope newScope (
  self:
  let
    inherit (self) callPackage;
  in
  ({
    sources = callPackage ./_sources/generated.nix { };

    blog = callPackage ./blog.nix { };
    favicon-pdf = callPackage ./favicon-pdf.nix { };
    favicon-ico = callPackage ./favicon-ico.nix { };
    katex = callPackage ./katex.nix { };
    normalize-css = callPackage ./normalize-css.nix { };
  })
)
