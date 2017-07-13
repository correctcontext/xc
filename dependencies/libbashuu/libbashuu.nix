{pkgs?import <nixpkgs>{}}: pkgs.stdenv.mkDerivation {
  name = "libbashuu";
  src = pkgs.fetchgit (builtins.fromJSON (builtins.readFile ./libbashuu.json));
  buildPhase="true";
  installPhase = ''
    mkdir -p $out/bin
    cp libbashuu $out/bin/
  '';
}
