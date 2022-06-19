{ writeShellScriptBin, blog-local, python3 }:

writeShellScriptBin "blog-local-serve" ''
  ${python3}/bin/python3 -m http.server --directory "${blog-local}" "$@"
''
