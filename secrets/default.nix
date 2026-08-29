{ lib, ... }:

{
  age.secrets."backup/s3-access" = lib.mkDefault {
    file = ./backup/s3-access.age;
    mode = "440";
    group = "backup";
  };

  age.secrets."backup/restic" = lib.mkDefault {
    file = ./backup/restic.age;
    mode = "440";
    group = "backup";
  };
}
