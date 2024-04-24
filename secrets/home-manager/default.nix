{ lib, ... }:
{

  age.secrets."email/password/mihaly_mihaly.codes" = lib.mkDefault {
    file = ../email/password/mihaly_mihaly.codes.age;
  };
}
