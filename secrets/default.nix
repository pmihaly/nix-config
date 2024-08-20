{ lib, ... }:

{
  age.secrets."backup/skylake" = lib.mkDefault {
    file = ./backup/skylake.age;
    mode = "440";
    group = "backup";
  };

  age.secrets."backup/skylake-restic" = lib.mkDefault {
    file = ./backup/skylake-restic.age;
    mode = "440";
    group = "backup";
  };
}
