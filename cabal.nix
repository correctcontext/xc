{ mkDerivation, aeson, ascii-progress, async, base, bytestring
, concurrent-extra, concurrent-output, containers, cryptonite
, data-default, either, etc, file-embed, hashable, http-types, lens
, mtl, optparse-applicative, parallel-io, random, scientific
, stdenv, string-conversions, string-qq, system-filepath, text
, time, unbounded-delays, uuid
}:
mkDerivation {
  pname = "xc";
  version = "0.0.0";
  src = ./src;
  isLibrary = false;
  isExecutable = true;
  configureFlags = ["-fcli" "-fyaml"];
  executableHaskellDepends = [
    aeson ascii-progress async base bytestring concurrent-extra
    concurrent-output containers cryptonite data-default either etc
    file-embed hashable http-types lens mtl optparse-applicative
    parallel-io random scientific string-conversions string-qq
    system-filepath text time unbounded-delays uuid
  ];
  license = stdenv.lib.licenses.unfree;
}
