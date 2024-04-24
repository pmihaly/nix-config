{ lib, ... }:
{

  age.secrets."authelia/jwt-secret" = lib.mkDefault {
    file = ./authelia/jwt-secret.age;
    owner = "authelia-skylake";
    group = "authelia-skylake";
    mode = "640";
  };
  age.secrets."authelia/storageEncriptionKey" = lib.mkDefault {
    file = ./authelia/storageEncriptionKey.age;
    owner = "authelia-skylake";
    group = "authelia-skylake";
    mode = "640";
  };
  age.secrets."authelia/sessionSecret" = lib.mkDefault {
    file = ./authelia/sessionSecret.age;
    owner = "authelia-skylake";
    group = "authelia-skylake";
    mode = "640";
  };
  age.secrets."authelia/users" = lib.mkDefault {
    file = ./authelia/users.age;
    owner = "authelia-skylake";
    group = "authelia-skylake";
    mode = "640";
  };

  age.secrets."duckdns/token" = lib.mkDefault { file = ./duckdns/token.age; };

  age.secrets."acme/porkbun-api-key" = lib.mkDefault { file = ./acme/porkbun-api-key.age; };

  age.secrets."acme/porkbun-secret-key" = lib.mkDefault { file = ./acme/porkbun-secret-key.age; };
}
