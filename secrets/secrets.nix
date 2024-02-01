let
  misi =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcOiZr3RPpmCNq5Z5YN6pWKLl5Y0FGSo6ybJ+qQ+Xeu mihaly@mihaly.codes";
  skylake =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSNGdQWXcMDIJ3LMHfHHPzgroX5QMwZI3cqAi1zExSS skylake";
  allKeys = [ misi skylake ];
in {

  "authelia/jwt-secret.age".publicKeys = allKeys;
  "authelia/storageEncriptionKey.age".publicKeys = allKeys;
  "authelia/sessionSecret.age".publicKeys = allKeys;
  "authelia/users.age".publicKeys = allKeys;
  "duckdns/token.age".publicKeys = allKeys;
  "email/password/mihaly_mihaly.codes.age".publicKeys = allKeys;
  "acme/porkbun-api-key.age".publicKeys = allKeys;
  "acme/porkbun-secret-key.age".publicKeys = allKeys;
}
