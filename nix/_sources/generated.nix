# This file was generated by nvfetcher, please do not modify it manually.
{
  fetchgit,
  fetchurl,
  fetchFromGitHub,
  dockerTools,
}:
{
  katex = {
    pname = "katex";
    version = "v0.16.22";
    src = fetchurl {
      url = "https://github.com/KaTeX/KaTeX/releases/download/v0.16.22/katex.tar.gz";
      sha256 = "sha256-BVzXljUlFBntkIwzRYKkHe40HYrwW0xViCd+FFEnp48=";
    };
  };
  license-buttons = {
    pname = "license-buttons";
    version = "2ae879e0d7a4cd9474c0fc5773abc26b0ba45189";
    src = fetchFromGitHub {
      owner = "creativecommons";
      repo = "licensebuttons";
      rev = "2ae879e0d7a4cd9474c0fc5773abc26b0ba45189";
      fetchSubmodules = false;
      sha256 = "sha256-EGiCvCoKcmkfPLfyHibnzrOMtgrHgK0pX2YLweULaz4=";
    };
    date = "2025-07-01";
  };
  normalize-css = {
    pname = "normalize-css";
    version = "8.0.1";
    src = fetchFromGitHub {
      owner = "necolas";
      repo = "normalize.css";
      rev = "8.0.1";
      fetchSubmodules = false;
      sha256 = "sha256-OviSJZM2ggeGoX/NGut4fVMLePNqBHgAjmK53BfvHEU=";
    };
  };
}
