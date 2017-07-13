let 
  pkgs = import <nixpkgs> {
    overlays = [(import ./dependencies/default.nix)];
  };
in
pkgs.stdenv.mkDerivation {
  name = "xc";
  src = ./.;
  buildInputs = [pkgs.makeWrapper];
  propagatedBuildInputs = [ pkgs.libbashuu ];
  buildPhase = ''
    mkdir $out/{bin,share/xc} -p
  '';
  installPhase = ''
    # bash libs are in "bin" so they can be imported by "source"
    # (but there are not executable)
    cp bin/* $out/bin/
    ln -s ${pkgs.libbashuu}/bin/libbashuu $out/bin/

    cp -r examples $out/share/xc/
    cp LICENSE NOTICE readme.md $out/share/xc/
  '';
}
