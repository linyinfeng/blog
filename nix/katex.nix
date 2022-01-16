{ stdenvNoCC, sources }:

stdenvNoCC.mkDerivation {
  inherit (sources.katex) pname version src;

  installPhase = ''
    cp -r . $out
  '';
}
