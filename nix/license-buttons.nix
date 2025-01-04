{
  sources,
  stdenvNoCC,
  python3,
  makeFontsConf,
  wrapGAppsHook,
  gobject-introspection,
  gtk3,
}:

let
  python = python3.withPackages (
    p: with p; [
      pycairo
      pygobject3
    ]
  );
in
stdenvNoCC.mkDerivation rec {
  inherit (sources.license-buttons) pname version src;

  FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ "${src}/www" ]; };

  nativeBuildInputs = [
    python
    wrapGAppsHook
  ];

  buildInputs = [
    gobject-introspection
    gtk3
  ];

  buildPhase = ''
    python3 scripts/genicons.py
  '';

  installPhase = ''
    cp -r www $out
  '';
}
