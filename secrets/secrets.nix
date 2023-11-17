let
  misi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro";
  skylake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJSNGdQWXcMDIJ3LMHfHHPzgroX5QMwZI3cqAi1zExSS skylake";
  allKeys = [ misi skylake ];
in {
  "autheliaJwtSecret.age".publicKeys = allKeys;
}
