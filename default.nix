let pkgs = import <nixpkgs> {};
#_etc = pkgs.haskell.lib.appendConfigureFlag pkgs.haskellPackages.etc ["-fcli" "-fyaml" "-fextra"];
etc = pkgs.haskell.lib.overrideCabal pkgs.haskellPackages.etc_0_2_0_0 (drv: {
  configureFlags = (drv.configureFlags or []) ++ ["-fcli" "-fyaml" "-fextra"];
  buildDepends = (drv.buildDepends or []) ++ (with pkgs.haskellPackages; [edit-distance yaml]);
});
in pkgs.haskellPackages.callPackage ./cabal.nix {inherit etc;}
