let
  misi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcOiZr3RPpmCNq5Z5YN6pWKLl5Y0FGSo6ybJ+qQ+Xeu mihaly@mihaly.codes";
  skylake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSNGdQWXcMDIJ3LMHfHHPzgroX5QMwZI3cqAi1zExSS skylake";
  allKeys = [
    misi
    skylake
  ];
in
{
  "email/password/mihaly_mihaly.codes.age".publicKeys = allKeys;
  "backup/s3-access.age".publicKeys = allKeys;
  "backup/restic.age".publicKeys = allKeys;
  # GitHub SSH key for hermes on skylake (git push over ssh): the
  # mihaly@mihaly.codes keypair, which is also skylake's ssh host key
  # and is registered on GitHub as pmihaly. Encrypted for both keys, like
  # the rest — on skylake it decrypts via the host key.
  "server/hermes-github-ssh.age".publicKeys = allKeys;
  # OpenRouter API key, used by hermes (skylake) and by pi/opencode
  # (aesop). Encrypted for both keys, like the rest.
  "openrouter-api-key.age".publicKeys = allKeys;
  # Matrix bot credentials (env-file: homeserver, user, access token,
  # home room). Created for the Hermes matrix channel task; used by
  # hermes on skylake.
  "matrix-bot.age".publicKeys = allKeys;
}
