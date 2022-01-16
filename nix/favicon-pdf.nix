{ stdenvNoCC, texlive }:

let
  tex = texlive.combine {
    inherit (texlive) scheme-small standalone;
  };
in
stdenvNoCC.mkDerivation {
  name = "favicon-pdf";

  src = ../favicon;

  nativeBuildInputs = [
    tex
  ];

  buildPhase = ''
    pdflatex favicon.tex
  '';

  installPhase = ''
    cp favicon.pdf $out
  '';
}
