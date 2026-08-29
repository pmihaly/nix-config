let
  misi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcOiZr3RPpmCNq5Z5YN6pWKLl5Y0FGSo6ybJ+qQ+Xeu mihaly@mihaly.codes";
  skylake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSNGdQWXcMDIJ3LMHfHHPzgroX5QMwZI3cqAi1zExSS skylake";
  allKeys = [
    misi
    skylake
  ];
in
{
  "backup/s3-access.age".publicKeys = allKeys;
  "backup/restic.age".publicKeys = allKeys;
  "server/copyparty-misi.age".publicKeys = allKeys;
  "server/skylake-deploy-ssh.age".publicKeys = allKeys;
  # OpenRouter API key, used by hermes (skylake) and by pi/opencode
  # (aesop). Encrypted for both keys, like the rest.
  "openrouter-api-key.age".publicKeys = allKeys;
}
