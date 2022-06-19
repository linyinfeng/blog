{ extraOptions ? null, callPackage, stdenvNoCC, writeShellScriptBin, python3
, lib, zola, katex, license-buttons, normalize-css, favicon-ico }:

stdenvNoCC.mkDerivation {
  name = "blog";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ zola ];

  buildPhase = ''
    cp    "${favicon-ico}"   static/favicon.ico
    cp -r "${katex}"         static/katex
    cp    "${normalize-css}" static/normalize.css

    mkdir static/license-buttons
    cp -r "${license-buttons}"/{l,p} static/license-buttons
  '' + (if extraOptions == null then ''
    zola build
  '' else ''
    zola build ${extraOptions}
  '');

  installPhase = ''
    cp -r public $out
  '';

  dontFixup = true;
}
