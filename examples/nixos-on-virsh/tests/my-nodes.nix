let
  pkgs = import <nixpkgs> {};
  web = pkgs.stdenv.mkDerivation {
    installPhase=''
      mkdir -p $out
      cat <<EOF > $out/index.html
      WORKS
      EOF
    '';
  };
in
{hostname, ...}: 

{
  services.nginx = {
    enable = true;
    appendConfig = ''
      server {
        listen :80;
        root $web;
      }
    '';
  };
}
