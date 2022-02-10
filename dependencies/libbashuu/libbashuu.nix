{pkgs?import <nixpkgs>{}}: pkgs.stdenv.mkDerivation {
  name = "libbashuu";
  src = pkgs.fetchgit (
    let
      org = builtins.fromJSON (builtins.readFile ./libbashuu.json);
    in with org; {
      inherit url rev sha256;
    }
  );
  buildPhase="true";
  installPhase = ''
    mkdir -p $out/bin
    cp libbashuu $out/bin/
  '';
}
