{ stdenvNoCC, sources }:

stdenvNoCC.mkDerivation {
  inherit (sources.normalize-css) pname version src;

  installPhase = ''
    cp ./normalize.css $out
  '';
}
