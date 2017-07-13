with import <nixpkgs> {};
with pkgs.python35Packages;
stdenv.mkDerivation {
  name = "impurePythonEnv";
  buildInputs = [
    pillow
    (pytorch.overrideAttrs (old: {
      buildInputs=[pkgs.gcc5] ++ old.buildInputs ++ [pkgs.which pkgs.cudatoolkit];
      checkPhase="true";
      preConfigure="true";
      enableParallelBuilding=true;
    }))
    torchvision
    virtualenv
    pip
    zlib
    cudatoolkit
  ];
  src = null;
  shellHook = ''
    SOURCE_DATE_EPOCH=$(date +%s)
    virtualenv --no-setuptools venv
    export PATH=$PWD/venv/bin:$PATH
    pip install visdom dominate
    echo "OK"
  '';
}
