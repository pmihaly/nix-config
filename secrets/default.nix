{ lib, ... }:

{
  # Copyparty private instance: password for the misi account.
  # Encrypted for both recipients (see secrets.nix); materialized for root
  # only and injected into the runtime conf by replace-secret at unit
  # start (modules/nixos/copyparty).
  age.secrets."server/copyparty-misi" = {
    file = ./server/copyparty-misi.age;
    owner = "root";
    mode = "400";
  };
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
