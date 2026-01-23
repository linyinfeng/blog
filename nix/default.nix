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
    blog-local = callPackage ./blog.nix {
      extraOptions = [
        "--base-url=/"
        "--drafts"
      ];
    };
    blog-local-serve = callPackage ./blog-local-serve.nix { };
    favicon-normal = callPackage ./favicon.nix { faviconType = "normal"; };
    favicon-square = callPackage ./favicon.nix { faviconType = "square"; };
    favicon-transparent = callPackage ./favicon.nix { faviconType = "transparent"; };
    default-open-graph-image = callPackage ./default-open-graph-image.nix { };
    katex = callPackage ./katex.nix { };
    license-buttons = callPackage ./license-buttons.nix { };
    normalize-css = callPackage ./normalize-css.nix { };
  })
)
