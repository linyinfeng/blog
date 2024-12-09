# This file was generated by nvfetcher, please do not modify it manually.
{ fetchgit, fetchurl, fetchFromGitHub, dockerTools }:
{
  katex = {
    pname = "katex";
    version = "v0.16.14";
    src = fetchurl {
      url = "https://github.com/KaTeX/KaTeX/releases/download/v0.16.14/katex.tar.gz";
      sha256 = "sha256-zP/nqpp6XuQQ/h8lPTYIx/eUxCO2nl9Em78YaO9/cAg=";
    };
  };
  license-buttons = {
    pname = "license-buttons";
    version = "2b08014a252142a1b312d4f68b1b4fbcac8b20b7";
    src = fetchFromGitHub {
      owner = "creativecommons";
      repo = "licensebuttons";
      rev = "2b08014a252142a1b312d4f68b1b4fbcac8b20b7";
      fetchSubmodules = false;
      sha256 = "sha256-d80k9CuGBe1OIkReBhuPV1a5VJGXicfxxVGnj+8AbTk=";
    };
    date = "2023-03-08";
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
