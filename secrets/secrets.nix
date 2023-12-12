let
  misi =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro";
  skylake =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSNGdQWXcMDIJ3LMHfHHPzgroX5QMwZI3cqAi1zExSS skylake";
  post-office =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPf1Tpl5Rer3w7bVjoDYfodapQav2F6KMY+oD59ccL+H root@post-office";
  allKeys = [ misi skylake post-office ];
in {

  "authelia/jwt-secret.age".publicKeys = allKeys;
  "authelia/storageEncriptionKey.age".publicKeys = allKeys;
  "authelia/sessionSecret.age".publicKeys = allKeys;
  "authelia/users.age".publicKeys = allKeys;
  "duckdns/token.age".publicKeys = allKeys;
}
