{
  extraOptions ? null,
  stdenvNoCC,
  lib,
  zola,
  katex,
  license-buttons,
  normalize-css,
  favicon-normal,
}:

stdenvNoCC.mkDerivation {
  name = "blog";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ zola ];

  buildPhase = ''
    cp "${favicon-normal}/favicon-normal.ico" static/favicon.ico
    cp "${favicon-normal}/favicon-normal.svg" static/favicon.svg
    cp -r "${katex}"      static/katex
    cp "${normalize-css}" static/normalize.css

    mkdir static/license-buttons
    cp -r "${license-buttons}"/{l,p} static/license-buttons
  ''
  + (
    if extraOptions == null then
      ''
        zola build
      ''
    else
      ''
        zola build ${lib.escapeShellArgs extraOptions}
      ''
  );

  installPhase = ''
    cp -r public $out
  '';

  dontFixup = true;
}
