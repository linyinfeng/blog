{
  stdenvNoCC,
  imagemagick,
  favicon-transparent,
}:

stdenvNoCC.mkDerivation {
  name = "default-open-graph-image.png";

  dontUnpack = true;

  nativeBuildInputs = [
    imagemagick
  ];

  buildPhase = ''
    magick \
      -background white \
      "${favicon-transparent}/favicon-transparent.svg" \
      -resize "1200x630" \
      -gravity center \
      -extent 1200x630 \
      -channel RGB \
      -negate \
      "default-open-graph-image.png"
  '';

  installPhase = ''
    cp default-open-graph-image.png "$out"
  '';
}
