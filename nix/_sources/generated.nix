# This file was generated by nvfetcher, please do not modify it manually.
{ fetchgit, fetchurl, fetchFromGitHub }: {
  katex = {
    pname = "katex";
    version = "v0.16.0";
    src = fetchurl {
      url =
        "https://github.com/KaTeX/KaTeX/releases/download/v0.16.0/katex.tar.gz";
      sha256 = "sha256-1tFWtAtgGegbwwJCF1IvPDA7kSjN0BPSAWf1MZc/ftw=";
    };
  };
  license-buttons = {
    pname = "license-buttons";
    version = "9bd3608c3a0a2fee342772a9d6d2c20ea616ba82";
    src = fetchFromGitHub ({
      owner = "creativecommons";
      repo = "licensebuttons";
      rev = "9bd3608c3a0a2fee342772a9d6d2c20ea616ba82";
      fetchSubmodules = false;
      sha256 = "sha256-kjU/zW5CnkRk0hwHLy/HHzffHdDKAoIATHsdBq5vqkI=";
    });
  };
  normalize-css = {
    pname = "normalize-css";
    version = "8.0.1";
    src = fetchFromGitHub ({
      owner = "necolas";
      repo = "normalize.css";
      rev = "8.0.1";
      fetchSubmodules = false;
      sha256 = "sha256-OviSJZM2ggeGoX/NGut4fVMLePNqBHgAjmK53BfvHEU=";
    });
  };
}