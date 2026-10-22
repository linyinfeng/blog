{
  extraOptions ? null,
  stdenvNoCC,
  lib,
  zola,
  cacert,
  katex,
  license-buttons,
  normalize-css,
  favicon-normal,
  default-open-graph-image,
}:

stdenvNoCC.mkDerivation {
  name = "blog";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ zola ];

  # zola 0.23 builds the reqwest client for load_data eagerly, and the sandbox has no system certs.
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  buildPhase = ''
    cp "${favicon-normal}/favicon-normal.ico" static/favicon.ico
    cp "${favicon-normal}/favicon-normal.svg" static/favicon.svg
    cp "${default-open-graph-image}"          static/default-open-graph-image.png
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
