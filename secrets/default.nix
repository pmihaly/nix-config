{ lib, ... }:
{
  age.secrets.autheliaJwtSecret = lib.mkDefault {
    file = ./autheliaJwtSecret.age;
  };
}
