{ callPackage, lib }:

let
  drvBuilder =
    self:
    { extraOptions ? null, callPackage, stdenvNoCC, lib, zola, katex, license-buttons, normalize-css, favicon-ico }:

    stdenvNoCC.mkDerivation {
      name = "blog";

      src = lib.cleanSource ../.;

      nativeBuildInputs = [
        zola
      ];

      buildPhase = ''
        cp    "${favicon-ico}"     static/favicon.ico
        cp -r "${katex}"           static/katex
        cp -r "${license-buttons}" static/license-buttons
        cp    "${normalize-css}"   static/normalize.css
      '' +
      (if extraOptions == null then ''
        zola build
      '' else ''
        zola build ${extraOptions}
      '');

      installPhase = ''
        cp -r public $out
      '';

      dontFixup = true;

      passthru.local = callPackage self {
        extraOptions = "--base-url / --drafts";
      };
    };

  drv = lib.fix drvBuilder;

in

callPackage drv { }
