{ callPackage, lib }:

let
  drvBuilder =
    self:
    { baseUrl ? null, callPackage, stdenvNoCC, lib, zola, katex, normalize-css, favicon-ico }:

    stdenvNoCC.mkDerivation {
      name = "blog";

      src = lib.cleanSource ../.;

      nativeBuildInputs = [
        zola
      ];

      buildPhase = ''
        cp    "${normalize-css}" static/normalize.css
        cp -r "${katex}"         static/katex
        cp    "${favicon-ico}"   static/favicon.ico
      '' +
      (if baseUrl == null then ''
        zola build
      '' else ''
        zola build --base-url "${baseUrl}"
      '');

      installPhase = ''
        cp -r public $out
      '';

      passthru.emptyBaseUrl = callPackage self { baseUrl = "/"; };
    };

  drv = lib.fix drvBuilder;

in

callPackage drv { }
