{ stdenvNoCC, imagemagick, favicon-pdf, ghostscript }:

stdenvNoCC.mkDerivation {
  name = "favicon-ico";

  dontUnpack = true;

  nativeBuildInputs = [ imagemagick ghostscript ];

  buildPhase = ''
    convert "${favicon-pdf}" \
        -background transparent \
        -define icon:auto-resize \
        favicon.ico
    identify favicon.ico
  '';

  installPhase = ''
    cp favicon.ico $out
  '';
}
