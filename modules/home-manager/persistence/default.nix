{ lib, ... }:

with lib;

{
  options.modules.persistence = {
    files = mkOption {
      default = [ ];
      type = types.listOf types.str;
    };
    directories = mkOption {
      default = [ ];
      type = types.listOf types.str;
    };
  };
}
