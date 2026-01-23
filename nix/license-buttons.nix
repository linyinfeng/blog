{
  sources,
  stdenvNoCC,
  python3,
  makeFontsConf,
  wrapGAppsHook3,
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
    wrapGAppsHook3
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
