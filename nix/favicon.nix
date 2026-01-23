{
  faviconType ? "normal",
  stdenvNoCC,
  texlive,
  imagemagick,
}:

let
  name = "favicon-${faviconType}";
  tex = texlive.combine { inherit (texlive) scheme-small standalone dvisvgm; };
in
stdenvNoCC.mkDerivation {
  name = "favicon";

  src = ../favicon;

  nativeBuildInputs = [
    tex
    imagemagick
  ];

  buildPhase = ''
    xelatex --no-pdf "${name}.tex"
    dvisvgm --no-fonts "${name}.xdv"
    magick \
        -background none \
        "${name}.svg" \
        -define icon:auto-resize \
        "${name}".ico
    for s in 16 32 64 128 180 256 512 1024; do
      magick \
        -background none \
        "${name}.svg" \
        -resize "''${s}x''${s}" \
        "${name}-''${s}x''${s}.png"
    done
  '';

  installPhase = ''
    mkdir "$out"
    cp *.svg "$out/"
    cp *.png "$out/"
    cp *.ico "$out/"
  '';
}
