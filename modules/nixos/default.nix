{ ... }: {
  imports = [
    ./nginx
    ./jellyfin
    ./homer
    ./authelia
    ./deluge
    ./arr
    ./firefly-iii
    ./endlessh
    ./monitoring
  ];
}
