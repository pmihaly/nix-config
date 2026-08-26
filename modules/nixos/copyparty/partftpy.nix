# Vendored from 9001/copyparty contrib/package/nix/partftpy/default.nix
# (pure-Python TFTP library; only needed because the vendored copyparty
# package definition keeps `partftpy` in its callPackage argument list).
{
  lib,
  buildPythonPackage,
  fetchurl,
  setuptools,
}:
let
  pinData = lib.importJSON ./partftpy-pin.json;
in

buildPythonPackage rec {
  pname = "partftpy";
  inherit (pinData) version;
  pyproject = true;

  src = fetchurl {
    inherit (pinData) url hash;
  };

  build-system = [ setuptools ];

  pythonImportsCheck = [ "partftpy.TftpServer" ];

  meta = {
    description = "Pure Python TFTP library  (copyparty edition)";
    homepage = "https://github.com/9001/partftpy";
    changelog = "https://github.com/9001/partftpy/releases/tag/${version}";
    license = lib.licenses.mit;
  };
}
