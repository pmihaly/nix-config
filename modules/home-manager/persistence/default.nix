{ lib, ... }:

with lib;

{
  options.modules.persistence = {
    files = mkOption {
      default = [ ];
      type = types.listOf (types.either types.attrs types.str);
    };
    directories = mkOption {
      default = [ ];
      type = types.listOf (types.either types.attrs types.str);
    };
  };
}
